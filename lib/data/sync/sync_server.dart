import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'sync_models.dart';
import 'sync_service.dart';

/// Embedded desktop HTTP server for LAN synchronization.
class SyncServer {
  SyncServer._internal();
  static final SyncServer instance = SyncServer._internal();

  HttpServer? _server;
  String _pairingCode = '123456';
  bool _running = false;
  int _port = 8080;

  bool get isRunning => _running;
  int get port => _port;
  String get pairingCode => _pairingCode;

  void setPairingCode(String code) {
    _pairingCode = code;
  }

  Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting IP address: $e');
    }
    return null;
  }

  Future<bool> start({int port = 8080}) async {
    if (_running) return true;
    try {
      _port = port;
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _running = true;
      _server!.listen(_handleRequest);
      debugPrint('SyncServer started on port $_port');
      return true;
    } catch (e) {
      debugPrint('Failed to start SyncServer: $e');
      _running = false;
      return false;
    }
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _running = false;
    debugPrint('SyncServer stopped.');
  }

  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    // CORS headers for convenience
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Headers', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');

    if (method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    // Verify pairing code (except /ping without header for initial check)
    final incomingCode = request.headers.value('X-Pairing-Code');
    if (incomingCode != _pairingCode && path != '/ping') {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.write(jsonEncode({'error': 'Invalid pairing code'}));
      await request.response.close();
      return;
    }

    try {
      if (path == '/ping') {
        final matches = incomingCode == _pairingCode;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'status': 'ok',
          'deviceName': 'Adey Desktop Server',
          'paired': matches,
        }));
      } else if (path == '/changes' && method == 'GET') {
        final sinceStr = request.uri.queryParameters['since'];
        final since = sinceStr != null ? DateTime.tryParse(sinceStr) : null;
        final payload = await SyncService.instance.exportChanges(since: since);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(payload.toJson()));
      } else if (path == '/changes' && method == 'POST') {
        final bodyText = await utf8.decoder.bind(request).join();
        final json = jsonDecode(bodyText) as Map<String, dynamic>;
        final incomingPayload = SyncPayload.fromJson(json);
        final conflictsCount = await SyncService.instance.importChanges(incomingPayload);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'status': 'ok',
          'conflicts': conflictsCount,
        }));
      } else if (path == '/file' && method == 'GET') {
        final filePath = request.uri.queryParameters['path'];
        if (filePath != null && File(filePath).existsSync()) {
          final file = File(filePath);
          request.response.headers.contentType = ContentType.binary;
          await file.openRead().pipe(request.response);
          return;
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
    } catch (e) {
      debugPrint('SyncServer handler error: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': e.toString()}));
    }

    await request.response.close();
  }
}

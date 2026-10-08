import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../document_storage.dart';
import '../settings_store.dart';
import 'sync_models.dart';
import 'sync_service.dart';

/// Embedded desktop HTTP server for LAN synchronization.
class SyncServer extends ChangeNotifier {
  SyncServer._internal();
  static final SyncServer instance = SyncServer._internal();

  HttpServer? _server;
  bool _running = false;
  int _port = 8080;
  String? _lastError;
  final Set<String> _connectedIpsToday = {};
  String _connectionDay = '';

  bool get isRunning => _running;
  int get port => _port;
  String? get lastError => _lastError;
  String get pairingCode => SettingsStore.instance.desktopPairingCode;
  int get devicesConnectedToday => _connectedIpsToday.length;

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
      _lastError = null;
      _server!.listen(_handleRequest);
      debugPrint('SyncServer started on port $_port');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to start SyncServer: $e');
      _running = false;
      _lastError = e.toString();
      notifyListeners();
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
    notifyListeners();
  }

  void _recordConnection(HttpRequest request) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_connectionDay != today) {
      _connectionDay = today;
      _connectedIpsToday.clear();
    }
    final added = _connectedIpsToday.add(
      request.connectionInfo?.remoteAddress.address ?? 'unknown',
    );
    if (added) {
      notifyListeners();
    }
  }

  bool _isAuthorized(HttpRequest request, String path) {
    final incomingCode = request.headers.value('X-Pairing-Code');
    if (path == '/ping') {
      return incomingCode == pairingCode;
    }
    return incomingCode == pairingCode;
  }

  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Headers', '*');
    request.response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );

    if (method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    if (!_isAuthorized(request, path)) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.write(jsonEncode({'error': 'Invalid pairing code'}));
      await request.response.close();
      return;
    }

    _recordConnection(request);

    try {
      if (path == '/ping') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'status': 'ok',
            'deviceName': 'Adey Desktop Server',
            'paired': true,
          }),
        );
      } else if (path == '/changes' && method == 'GET') {
        final sinceStr = request.uri.queryParameters['since'];
        final since = sinceStr != null ? DateTime.tryParse(sinceStr) : null;
        final payload = await SyncService.instance.exportChanges(
          since: since,
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(payload.toJson()));
      } else if (path == '/changes' && method == 'POST') {
        final bodyText = await utf8.decoder.bind(request).join();
        final json = jsonDecode(bodyText) as Map<String, dynamic>;
        final incomingPayload = SyncPayload.fromJson(json);
        final result = await SyncService.instance.importChanges(
          incomingPayload,
        );
        await _storeIncomingFiles(result.missingHashes, incomingPayload);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'status': 'ok',
            'conflicts': result.conflictCount,
            'missing_hashes': await _missingHashesForPayload(incomingPayload),
          }),
        );
      } else if (path == '/file' && method == 'GET') {
        final hash = request.uri.queryParameters['hash'];
        if (hash == null) {
          request.response.statusCode = HttpStatus.badRequest;
        } else {
          final path = await DocumentStorage.localPathForHash(hash);
          if (path != null) {
            final file = File(path);
            request.response.headers.contentType = ContentType.binary;
            await file.openRead().pipe(request.response);
            return;
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
        }
      } else if (path == '/file' && method == 'POST') {
        final hash = request.uri.queryParameters['hash'];
        if (hash == null) {
          request.response.statusCode = HttpStatus.badRequest;
        } else if (await DocumentStorage.hasBytesForHash(hash)) {
          request.response.statusCode = HttpStatus.ok;
        } else {
          final chunks = <int>[];
          await for (final chunk in request) {
            chunks.addAll(chunk);
          }
          final bytes = Uint8List.fromList(chunks);
          final (savedPath, _) = await DocumentStorage.saveByHash(
            bytes: bytes,
            hash: hash,
          );
          await SyncService.instance.attachDownloadedFile(hash, savedPath);
          request.response.statusCode = HttpStatus.ok;
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

  Future<List<String>> _missingHashesForPayload(SyncPayload payload) async {
    final docs = payload.tables['documents'] ?? [];
    final missing = <String>[];
    for (final row in docs) {
      final hash = row['sha256'] as String?;
      if (hash == null || hash.isEmpty) continue;
      if (!await DocumentStorage.hasBytesForHash(hash)) {
        missing.add(hash);
      }
    }
    return missing;
  }

  Future<void> _storeIncomingFiles(
    List<String> missingHashes,
    SyncPayload payload,
  ) async {
    if (missingHashes.isEmpty) return;
    debugPrint(
      'SyncServer waiting for ${missingHashes.length} file upload(s).',
    );
  }
}
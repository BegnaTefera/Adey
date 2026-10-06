import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'sync_models.dart';
import 'sync_service.dart';

/// HTTP Client used by Mobile to push/pull database changes to/from Desktop Server.
class SyncClient {
  SyncClient._internal();
  static final SyncClient instance = SyncClient._internal();

  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  Future<Map<String, dynamic>?> pingServer({
    required String serverIp,
    int port = 8080,
    required String pairingCode,
  }) async {
    try {
      final uri = Uri.parse('http://$serverIp:$port/ping');
      final req = await _httpClient.getUrl(uri);
      req.headers.set('X-Pairing-Code', pairingCode);
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('SyncClient ping error: $e');
    }
    return null;
  }

  /// Full 2-way sync with desktop server:
  /// 1. Push local changes to server
  /// 2. Pull server changes to local database
  Future<bool> performSync({
    required String serverIp,
    int port = 8080,
    required String pairingCode,
    DateTime? lastSyncTime,
  }) async {
    try {
      // 1. Push local changes to server
      final outgoingPayload = await SyncService.instance.exportChanges(since: lastSyncTime);
      final pushUri = Uri.parse('http://$serverIp:$port/changes');
      final pushReq = await _httpClient.postUrl(pushUri);
      pushReq.headers.set('X-Pairing-Code', pairingCode);
      pushReq.headers.contentType = ContentType.json;
      pushReq.write(jsonEncode(outgoingPayload.toJson()));
      final pushRes = await pushReq.close();
      if (pushRes.statusCode != 200) {
        debugPrint('Sync Push failed status: ${pushRes.statusCode}');
        return false;
      }

      // 2. Pull changes from server
      final pullUri = Uri.parse('http://$serverIp:$port/changes${lastSyncTime != null ? '?since=${lastSyncTime.toIso8601String()}' : ''}');
      final pullReq = await _httpClient.getUrl(pullUri);
      pullReq.headers.set('X-Pairing-Code', pairingCode);
      final pullRes = await pullReq.close();
      if (pullRes.statusCode == 200) {
        final body = await pullRes.transform(utf8.decoder).join();
        final incomingPayload = SyncPayload.fromJson(jsonDecode(body) as Map<String, dynamic>);
        await SyncService.instance.importChanges(incomingPayload);
        return true;
      }
    } catch (e) {
      debugPrint('SyncClient performSync error: $e');
    }
    return false;
  }
}

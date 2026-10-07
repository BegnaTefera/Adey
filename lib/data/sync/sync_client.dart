import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../document_storage.dart';
import '../settings_store.dart';
import 'sync_models.dart';
import 'sync_service.dart';

/// HTTP client used by mobile to sync with the desktop LAN server.
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

  /// Full sync pass: ping → pull → push → file transfers.
  Future<bool> performSync({
    required String serverIp,
    int port = 8080,
    required String pairingCode,
    DateTime? lastSyncTime,
  }) async {
    await SyncService.instance.setRunStatus(SyncRunStatus.syncing);
    try {
      final ping = await pingServer(
        serverIp: serverIp,
        port: port,
        pairingCode: pairingCode,
      );
      if (ping == null || ping['paired'] != true) {
        await SyncService.instance.setRunStatus(
          SyncRunStatus.failed,
          error: 'Could not verify pairing with desktop.',
        );
        return false;
      }

      final since = lastSyncTime ?? SettingsStore.instance.lastSyncTime;

      // Pull desktop changes first.
      final pullUri = Uri.parse(
        'http://$serverIp:$port/changes${since != null ? '?since=${Uri.encodeComponent(since.toIso8601String())}' : ''}',
      );
      final pullReq = await _httpClient.getUrl(pullUri);
      pullReq.headers.set('X-Pairing-Code', pairingCode);
      final pullRes = await pullReq.close();
      if (pullRes.statusCode != 200) {
        await SyncService.instance.setRunStatus(SyncRunStatus.failed, error: 'Pull failed.');
        return false;
      }
      final pullBody = await pullRes.transform(utf8.decoder).join();
      final incomingPayload =
          SyncPayload.fromJson(jsonDecode(pullBody) as Map<String, dynamic>);
      final pullResult = await SyncService.instance.importChanges(incomingPayload);
      await _downloadMissingFiles(
        serverIp: serverIp,
        port: port,
        pairingCode: pairingCode,
        hashes: pullResult.missingHashes,
      );
      await _downloadMissingFiles(
        serverIp: serverIp,
        port: port,
        pairingCode: pairingCode,
        hashes: await SyncService.instance.hashesNeedingDownload(),
      );

      // Push local changes.
      final outgoingPayload = await SyncService.instance.exportChanges(since: since);
      final pushUri = Uri.parse('http://$serverIp:$port/changes');
      final pushReq = await _httpClient.postUrl(pushUri);
      pushReq.headers.set('X-Pairing-Code', pairingCode);
      pushReq.headers.contentType = ContentType.json;
      pushReq.write(jsonEncode(outgoingPayload.toJson()));
      final pushRes = await pushReq.close();
      if (pushRes.statusCode != 200) {
        await SyncService.instance.setRunStatus(SyncRunStatus.failed, error: 'Push failed.');
        return false;
      }
      final pushBody = await pushRes.transform(utf8.decoder).join();
      final pushJson = jsonDecode(pushBody) as Map<String, dynamic>;
      final missingOnServer =
          (pushJson['missing_hashes'] as List<dynamic>? ?? []).cast<String>();
      await _uploadFiles(
        serverIp: serverIp,
        port: port,
        pairingCode: pairingCode,
        hashes: missingOnServer,
      );

      final pushedChildIds = outgoingPayload.tables['children']
              ?.map((row) => row['id'] as String?)
              .whereType<String>()
              .toList() ??
          [];
      await SyncService.instance.markChildrenSynced(pushedChildIds);
      await SyncService.instance.recordSuccessfulSync();
      return true;
    } catch (e) {
      debugPrint('SyncClient performSync error: $e');
      await SyncService.instance.setRunStatus(
        SyncRunStatus.failed,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> _downloadMissingFiles({
    required String serverIp,
    required int port,
    required String pairingCode,
    required List<String> hashes,
  }) async {
    for (final hash in hashes) {
      if (await DocumentStorage.hasBytesForHash(hash)) continue;
      final bytes = await _downloadFile(
        serverIp: serverIp,
        port: port,
        pairingCode: pairingCode,
        hash: hash,
      );
      if (bytes == null) continue;
      final (path, _) = await DocumentStorage.saveByHash(bytes: bytes, hash: hash);
      await SyncService.instance.attachDownloadedFile(hash, path);
    }
  }

  Future<Uint8List?> _downloadFile({
    required String serverIp,
    required int port,
    required String pairingCode,
    required String hash,
  }) async {
    try {
      final uri = Uri.parse('http://$serverIp:$port/file?hash=${Uri.encodeComponent(hash)}');
      final req = await _httpClient.getUrl(uri);
      req.headers.set('X-Pairing-Code', pairingCode);
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final chunks = <int>[];
      await for (final chunk in res) {
        chunks.addAll(chunk);
      }
      return Uint8List.fromList(chunks);
    } catch (e) {
      debugPrint('SyncClient download error: $e');
      return null;
    }
  }

  Future<void> _uploadFiles({
    required String serverIp,
    required int port,
    required String pairingCode,
    required List<String> hashes,
  }) async {
    for (final hash in hashes) {
      final path = await DocumentStorage.localPathForHash(hash);
      if (path == null) continue;
      final bytes = await DocumentStorage.readBytes(path);
      if (bytes == null) continue;
      await _uploadFile(
        serverIp: serverIp,
        port: port,
        pairingCode: pairingCode,
        hash: hash,
        bytes: bytes,
      );
    }
  }

  Future<void> _uploadFile({
    required String serverIp,
    required int port,
    required String pairingCode,
    required String hash,
    required Uint8List bytes,
  }) async {
    try {
      final uri = Uri.parse('http://$serverIp:$port/file?hash=${Uri.encodeComponent(hash)}');
      final req = await _httpClient.postUrl(uri);
      req.headers.set('X-Pairing-Code', pairingCode);
      req.headers.contentType = ContentType.binary;
      req.add(bytes);
      final res = await req.close();
      if (res.statusCode != 200) {
        debugPrint('SyncClient upload failed for $hash: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('SyncClient upload error: $e');
    }
  }
}

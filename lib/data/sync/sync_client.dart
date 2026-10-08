import 'dart:convert';
import 'dart:io';
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

  /// Pings the desktop. Never throws: failures come back as a human-readable
  /// [error] so the UI can say what actually went wrong.
  Future<({Map<String, dynamic>? response, String? error})> pingServer({
    required String serverIp,
    int port = 8080,
    required String pairingCode,
  }) async {
    try {
      final uri = Uri.parse('http://$serverIp:$port/ping');
      final req = await _httpClient.getUrl(uri);
      req.headers.set('X-Pairing-Code', pairingCode);
      final res = await req.close();
      if (res.statusCode == HttpStatus.unauthorized) {
        return (
          response: null,
          error:
              'The desktop rejected the pairing code. Re-scan the QR code or enter its current code.',
        );
      }
      if (res.statusCode != 200) {
        return (
          response: null,
          error: 'The desktop replied with HTTP ${res.statusCode}.',
        );
      }
      final body = await res.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return (response: null, error: 'The desktop sent an unexpected reply.');
      }
      return (response: decoded, error: null);
    } catch (e) {
      debugPrint('SyncClient ping error: $e');
      return (response: null, error: _describeConnectionFailure(e, serverIp, port));
    }
  }

  /// Turns a raw network exception into a message a person can act on.
  String _describeConnectionFailure(Object e, String serverIp, int port) {
    final text = e.toString().toLowerCase();

    if (text.contains('cleartext')) {
      return 'This phone blocked the plain-HTTP sync connection. '
          'Rebuild and reinstall the app from the updated project.';
    }
    if (text.contains('failed host lookup') || text.contains('name resolution')) {
      return 'Could not find the desktop at $serverIp. Check the address.';
    }
    if (text.contains('refused')) {
      return 'The desktop at $serverIp answered but refused the connection. '
          'Turn on the sync server and allow port $port in its firewall.';
    }
    if (text.contains('timed out') || text.contains('timeout')) {
      return 'Timed out reaching the desktop at $serverIp:$port. '
          'Make sure both devices are on the same Wi-Fi and port $port '
          'is allowed through the desktop firewall.';
    }
    if (text.contains('network is unreachable') ||
        text.contains('connection reset') ||
        text.contains('connection aborted')) {
      return 'Lost the connection to the desktop at $serverIp:$port. '
          'Check that both devices are on the same Wi-Fi.';
    }
    return 'Could not reach the desktop at $serverIp:$port. '
        'Check that both devices are on the same Wi-Fi.';
  }

  /// Full sync pass: ping → pull → push → file transfers.
  Future<bool> performSync({
    required String serverIp,
    int port = 8080,
    required String pairingCode,
    DateTime? lastSyncTime,
  }) async {
    SyncService.instance.setRunStatus(SyncRunStatus.syncing);
    try {
      final ping = await pingServer(
        serverIp: serverIp,
        port: port,
        pairingCode: pairingCode,
      );
      if (ping.response == null || ping.response!['paired'] != true) {
        SyncService.instance.setRunStatus(
          SyncRunStatus.failed,
          error: ping.error ?? 'The desktop did not confirm pairing.',
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
        SyncService.instance.setRunStatus(SyncRunStatus.failed, error: 'Pull failed.');
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
        SyncService.instance.setRunStatus(SyncRunStatus.failed, error: 'Push failed.');
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
      await SyncService.instance.recordSuccessfulSync(DateTime.now());
      return true;
    } catch (e) {
      debugPrint('SyncClient performSync error: $e');
      SyncService.instance.setRunStatus(
        SyncRunStatus.failed,
        error: e.toString(),
      );
      return false;
    }
  }

  /// The run in flight, if any. Auto-sync and a manual "Sync now" must not
  /// interleave: the second caller awaits the first instead of starting a
  /// duplicate pull/push against the same desktop.
  Future<SyncResult>? _activeRun;

  Future<SyncResult> syncNow() {
    final running = _activeRun;
    if (running != null) return running;

    late final Future<SyncResult> run;
    run = _syncNow().whenComplete(() {
      if (identical(_activeRun, run)) _activeRun = null;
    });
    _activeRun = run;
    return run;
  }

  Future<SyncResult> _syncNow() async {
  final settings = SettingsStore.instance;

  final serverIp = settings.syncServerIp.trim();
  final pairingCode = settings.syncPairingCode.trim();

  if (serverIp.isEmpty) {
    return const SyncResult(
      ok: false,
      message: 'Desktop server address is not configured.',
    );
  }

  if (pairingCode.isEmpty) {
    return const SyncResult(
      ok: false,
      message: 'Pairing code is not configured.',
    );
  }

  final success = await performSync(
    serverIp: serverIp,
    port: settings.syncServerPort,
    pairingCode: pairingCode,
  );

  return SyncResult(
    ok: success,
    message: success
        ? 'Sync completed successfully.'
        : SyncService.instance.lastError ?? 'Sync failed.',
  );
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

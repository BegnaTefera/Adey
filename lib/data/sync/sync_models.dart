import 'dart:convert';

/// A flagged sync conflict awaiting a human decision.
///
/// [localData] is this device's row, [remoteData] is the row the other
/// device sent. Which of those is "mobile" and which is "desktop" depends
/// on the device that recorded it — the compare screen sorts that out.
class SyncConflict {
  final String id;
  final String tableName;
  final String entityId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime createdAt;

  const SyncConflict({
    required this.id,
    required this.tableName,
    required this.entityId,
    required this.localData,
    required this.remoteData,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'table_name': tableName,
        'entity_id': entityId,
        'local_json': jsonEncode(localData),
        'remote_json': jsonEncode(remoteData),
        'created_at': createdAt.toIso8601String(),
      };

  factory SyncConflict.fromMap(Map<String, dynamic> map) => SyncConflict(
        id: map['id'] as String,
        tableName: map['table_name'] as String,
        entityId: map['entity_id'] as String,
        localData: Map<String, dynamic>.from(
            jsonDecode(map['local_json'] as String) as Map),
        remoteData: Map<String, dynamic>.from(
            jsonDecode(map['remote_json'] as String) as Map),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// Rows exchanged over HTTP, grouped by table.
class SyncPayload {
  final String deviceId;
  final DateTime timestamp;

  /// The sender's last successful sync time (the baseline its changes are
  /// measured against). Receivers use it to tell "only the sender changed
  /// this" from "both sides changed this" for payments.
  final DateTime? since;
  final Map<String, List<Map<String, dynamic>>> tables;

  /// sha256 of every document the sender holds bytes for. The receiver
  /// answers with the ones it lacks, so an upload that was interrupted
  /// last time is retried even though its row hasn't changed since.
  final List<String> fileHashes;

  const SyncPayload({
    required this.deviceId,
    required this.timestamp,
    required this.tables,
    this.since,
    this.fileHashes = const [],
  });

  int get rowCount => tables.values.fold(0, (sum, rows) => sum + rows.length);

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'timestamp': timestamp.toIso8601String(),
        'since': since?.toIso8601String(),
        'tables': tables,
        'fileHashes': fileHashes,
      };

  factory SyncPayload.fromJson(Map<String, dynamic> json) => SyncPayload(
        deviceId: json['deviceId'] as String? ?? 'unknown',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        since: DateTime.tryParse(json['since'] as String? ?? ''),
        fileHashes:
            (json['fileHashes'] as List<dynamic>? ?? []).cast<String>().toList(),
        tables: (json['tables'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(
            k,
            (v as List<dynamic>)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
          ),
        ),
      );
}

/// What a finished mobile sync pass reports back to the UI.
class SyncResult {
  final bool ok;
  final String message;
  final int pulled;
  final int pushed;
  final int conflicts;

  const SyncResult({
    required this.ok,
    required this.message,
    this.pulled = 0,
    this.pushed = 0,
    this.conflicts = 0,
  });

  const SyncResult.failure(String message)
      : this(ok: false, message: message);
}

import 'dart:convert';

/// Represents a flagged sync conflict for user review (e.g. payment changed on both sides).
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
        localData: jsonDecode(map['local_json'] as String) as Map<String, dynamic>,
        remoteData: jsonDecode(map['remote_json'] as String) as Map<String, dynamic>,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// Payload sent over HTTP containing table records and timestamps.
class SyncPayload {
  final String deviceId;
  final DateTime timestamp;
  final Map<String, List<Map<String, dynamic>>> tables;

  const SyncPayload({
    required this.deviceId,
    required this.timestamp,
    required this.tables,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'timestamp': timestamp.toIso8601String(),
        'tables': tables,
      };

  factory SyncPayload.fromJson(Map<String, dynamic> json) => SyncPayload(
        deviceId: json['deviceId'] as String? ?? 'unknown',
        timestamp: DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
        tables: (json['tables'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(
            k,
            (v as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          ),
        ),
      );
}

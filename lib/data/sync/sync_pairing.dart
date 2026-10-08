/// Connection details a phone needs to pair with the desktop, encoded as a
/// QR payload: `adey://sync?ip=192.168.1.50&port=8080&code=123456`.
class SyncPairingInfo {
  const SyncPairingInfo({
    required this.ip,
    required this.port,
    required this.code,
  });

  static const scheme = 'adey';
  static const host = 'sync';
  static const defaultPort = 8080;

  final String ip;
  final int port;
  final String code;

  String toQrPayload() =>
      '$scheme://$host?ip=${Uri.encodeComponent(ip)}'
      '&port=$port&code=${Uri.encodeComponent(code)}';

  /// Parses a scanned payload. Returns null when the value isn't a pairing
  /// code for this app or is missing required fields.
  static SyncPairingInfo? tryParse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != scheme ||
        uri.host != host ||
        !uri.hasQuery) {
      return null;
    }

    final params = uri.queryParameters;
    final ip = (params['ip'] ?? '').trim();
    final code = (params['code'] ?? '').trim();
    final port = int.tryParse(params['port'] ?? '') ?? 0;

    if (ip.isEmpty || !_looksLikeIpv4(ip)) return null;
    if (code.isEmpty) return null;
    if (port < 1 || port > 65535) return null;

    return SyncPairingInfo(ip: ip, port: port, code: code);
  }

  static bool _looksLikeIpv4(String value) {
    final parts = value.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }
}

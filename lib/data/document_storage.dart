import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Persists document bytes (captured photos, generated PDFs) to the
/// app's local documents directory and computes a SHA-256 hash of the
/// content at write time.
class DocumentStorage {
  DocumentStorage._();

  static Future<Directory> _documentsDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/child_documents');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<(String path, String sha256Hex)> save({
    required Uint8List bytes,
    required String filename,
  }) async {
    final dir = await _documentsDir();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    final hash = sha256.convert(bytes).toString();
    return (file.path, hash);
  }

  /// Saves synced bytes under a hash-based filename so any device can
  /// resolve the same content without sharing absolute paths.
  static Future<(String path, String sha256Hex)> saveByHash({
    required Uint8List bytes,
    required String hash,
  }) async {
    final dir = await _documentsDir();
    final ext = _extFor(bytes);
    final file = File('${dir.path}/$hash$ext');
    await file.writeAsBytes(bytes, flush: true);
    return (file.path, hash);
  }

  static Future<bool> verify({
    required String path,
    required String expectedSha256,
  }) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    return hash == expectedSha256;
  }

  static Future<bool> hasBytesForHash(String hash) async {
    final path = await localPathForHash(hash);
    return path != null;
  }

  static Future<String?> localPathForHash(String hash) async {
    final dir = await _documentsDir();
    for (final ext in ['.pdf', '.jpg', '.bin', '']) {
      final file = File('${dir.path}/$hash$ext');
      if (await file.exists()) return file.path;
    }
    return null;
  }

  static Future<Uint8List?> readBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static String _extFor(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return '.pdf';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return '.jpg';
    }
    return '.bin';
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Persists document bytes (captured photos, generated PDFs) to the
/// app's local documents directory and computes a SHA-256 hash of the
/// content at write time.
///
/// The hash is what makes a stored document "tamper-evident" per the
/// registration design: once written, a document is never rewritten —
/// if the bytes on disk ever don't match the stored hash, that's a
/// sign the file was altered outside the app.
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

  /// Writes [bytes] to a new file named [filename] under the app's
  /// document storage directory. Returns the absolute path and the
  /// SHA-256 hex digest of the content.
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

  /// Re-reads a stored file and checks its current hash against the one
  /// recorded when it was saved. Returns false if the file is missing or
  /// its content no longer matches — i.e. it was tampered with or
  /// corrupted after being written.
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
}

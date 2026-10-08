import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/child.dart';
import 'document_storage.dart';
import 'sync/sync_service.dart';

/// The document's bytes aren't on this device (yet) — typically a signed
/// form that was registered on the phone and hasn't finished transferring.
class DocumentUnavailableException implements Exception {
  final String message;
  const DocumentUnavailableException(this.message);
  @override
  String toString() => message;
}

bool _looksLikePdf(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x25 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x44 &&
    bytes[3] == 0x46;

/// Opens the OS print dialog for a stored document using its saved bytes.
/// Images (ID copies, photos) are wrapped in a one-page PDF first.
///
/// Returns true if the person actually printed, false if they cancelled.
/// Throws [DocumentUnavailableException] if the bytes aren't on this
/// device.
Future<bool> printStoredDocument(ChildDocument doc, {String? name}) async {
  var path = doc.filePath;
  if (path == null || path.isEmpty) {
    final hash = doc.sha256;
    if (hash != null && hash.isNotEmpty) {
      path = await SyncService.instance.pathForHash(hash);
    }
  }
  final bytes = path == null ? null : await DocumentStorage.readBytes(path);
  if (bytes == null) {
    throw const DocumentUnavailableException(
      "This document hasn't finished transferring from the phone yet. "
      'Sync the phone, then try again.',
    );
  }

  var pdfBytes = bytes;
  if (!_looksLikePdf(bytes)) {
    final pdf = pw.Document();
    final image = pw.MemoryImage(bytes);
    pdf.addPage(
      pw.Page(
        build: (_) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
    pdfBytes = Uint8List.fromList(await pdf.save());
  }

  return Printing.layoutPdf(
    onLayout: (_) async => pdfBytes,
    name: name ?? doc.label,
  );
}

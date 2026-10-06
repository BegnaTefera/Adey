import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/authorized_pickup.dart';
import '../models/child.dart';

const _amharicMonths = [
  'መስከረም',
  'ጥቅምት',
  'ኅዳር',
  'ታኅሳስ',
  'ጥር',
  'የካቲት',
  'መጋቢት',
  'ሚያዝያ',
  'ግንቦት',
  'ሰኔ',
  'ሐምሌ',
  'ነሐሴ',
  'ጳጉሜ',
];

/// Amharic translation for each relationship option offered at
/// registration, used to label each guardian's section on the printed
/// form the way the paper form's "እናት" / "አባት" headings do.
const _relationshipAmharic = {
  'Mother': 'እናት',
  'Father': 'አባት',
  'Grandparent': 'አያት',
  'Legal guardian': 'ህጋዊ አሳዳጊ',
  'Aunt': 'አክስት',
  'Uncle': 'አጎት',
  'Sibling': 'ወንድም/እህት',
  'Other': 'ወላጅ',
};

String _amharicRelationship(String relationship) =>
    _relationshipAmharic[relationship] ?? relationship;

String _ethiopianDateString(DateTime date) {
  final et = date.convertToEthiopian();
  return '${et.day} ${_amharicMonths[et.month - 1]} ${et.year}';
}

/// Everything needed to render the registration form + signature as a
/// PDF that mirrors the daycare's paper form field-for-field.
class RegistrationPdfData {
  final String childFirstName;
  final String childLastName;
  final Gender gender;
  final DateTime childDob;
  final List<Guardian> guardians;
  final String healthCondition;
  final String dietaryNotes;
  final String specialCharacteristics;
  final List<AuthorizedPickup> pickupPeople;
  final String agreementText;
  final List<List<ui.Offset>> signatureStrokes;
  final ui.Size signatureAreaSize;
  final DateTime signedAt;

  const RegistrationPdfData({
    required this.childFirstName,
    required this.childLastName,
    required this.gender,
    required this.childDob,
    required this.guardians,
    required this.healthCondition,
    required this.dietaryNotes,
    required this.specialCharacteristics,
    required this.pickupPeople,
    required this.agreementText,
    required this.signatureStrokes,
    required this.signatureAreaSize,
    required this.signedAt,
  });
}

/// Renders a [RegistrationPdfData] into PDF bytes, laid out to mirror
/// the daycare's actual Amharic paper registration form (አደይ አበባ የህፃናት
/// ማቆያ) field-for-field, with the signature drawn as a real vector
/// path replaying the same strokes captured on the signature pad.
Future<Uint8List> buildRegistrationPdf(RegistrationPdfData data) async {
  final fontBytes = await rootBundle.load(
    'assets/fonts/NotoSansEthiopic-Regular.ttf',
  );
  final ethiopicFont = pw.Font.ttf(fontBytes);

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: ethiopicFont,
      bold: ethiopicFont,
    ),
  );

  const pageMargin = 32.0;
  const signatureBoxWidth = 260.0;
  const signatureBoxHeight = 90.0;

  final scaleX = data.signatureAreaSize.width > 0
      ? signatureBoxWidth / data.signatureAreaSize.width
      : 1.0;
  final scaleY = data.signatureAreaSize.height > 0
      ? signatureBoxHeight / data.signatureAreaSize.height
      : 1.0;

  final primaryGuardian =
      data.guardians.isNotEmpty ? data.guardians.first : null;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(pageMargin),
      build: (context) => [
        pw.Center(
          child: pw.Text(
            'አደይ አበባ የህፃናት ማቆያ',
            style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            'የመመዝገቢያ ፎርም',
            style: const pw.TextStyle(
              fontSize: 13,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
        pw.SizedBox(height: 18),

        _field('1. የህፃኑ/ኗ ሙሉ ስም',
            '${data.childFirstName} ${data.childLastName}'),
        _field('ፆታ (Gender)', data.gender.amharicLabel),
        pw.SizedBox(height: 8),

        _field('2. የትውልድ ቀን (ዓ.ም)', _ethiopianDateString(data.childDob)),
        pw.SizedBox(height: 12),

        // One numbered section per guardian, mirroring the form's
        // separate mother/father blocks — generalized to whatever
        // relationship was actually recorded (mother, father,
        // grandparent, etc.) rather than assuming exactly those two.
        for (var i = 0; i < data.guardians.length; i++) ...[
          _guardianSection(i + 3, data.guardians[i]),
          pw.SizedBox(height: 10),
        ],

        pw.SizedBox(height: 6),
        pw.Text(
          '5. ህጻኑን/ኗን የሚረከብ እና የሚያስረክብ ሰው ስም እና ስልክ ቁጥር',
          style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        pw.SizedBox(height: 6),
        if (primaryGuardian != null)
          _pickupLine('5.0', primaryGuardian.name, primaryGuardian.phone),
        for (var i = 0; i < data.pickupPeople.length; i++)
          _pickupLine(
            '5.${i + 1}',
            data.pickupPeople[i].name,
            data.pickupPeople[i].phone,
          ),
        pw.SizedBox(height: 12),

        _field('6. የህጻኑ/ኗ የጤና ሁኔታ',
            data.healthCondition.isEmpty ? '—' : data.healthCondition),
        _field('7. የህጻኑ/ኗ የአመጋገብ ሁኔታ',
            data.dietaryNotes.isEmpty ? '—' : data.dietaryNotes),
        _field('8. የህጻኑ/ኗ ልዩ ባህሪ',
            data.specialCharacteristics.isEmpty
                ? '—'
                : data.specialCharacteristics),
        pw.SizedBox(height: 20),

        pw.Text(
          'እኔ${primaryGuardian != null ? ' ${primaryGuardian.name}' : ''} '
          'በአደይ አበባ የህፃናት ማቆያ ስላስገባሁት/ኋት ህፃን በሚመለከት በማቆያው ደንብ መሰረት '
          'በማንኛውም ጉዳይ ሁሉ አስፈላጊውን ትብብር ለማድረግ የውዴታ ግዴታ የገባሁ መሆኔን '
          'በፊርማዬ አረጋግጣለሁ።',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.SizedBox(height: 24),

        pw.Text(
          'ወላጅ',
          style: const pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            decoration: pw.TextDecoration.underline,
          ),
        ),
        pw.SizedBox(height: 10),
        _field('ስም', primaryGuardian?.name ?? ''),
        pw.SizedBox(height: 10),

        pw.Text('ፊርማ', style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 6),
        pw.Container(
          width: signatureBoxWidth,
          height: signatureBoxHeight,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.CustomPaint(
            size: const PdfPoint(signatureBoxWidth, signatureBoxHeight),
            painter: (PdfGraphics canvas, PdfPoint size) {
              canvas.setColor(PdfColors.black);
              canvas.setLineWidth(1.2);

              // Flip Y (Flutter's canvas origin is top-left, PDF's is
              // bottom-left) and scale from the on-screen pad size into
              // the PDF's signature box.
              PdfPoint transform(ui.Offset p) => PdfPoint(
                    p.dx * scaleX,
                    size.y - (p.dy * scaleY),
                  );

              for (final stroke in data.signatureStrokes) {
                if (stroke.isEmpty) continue;
                if (stroke.length < 3) {
                  final first = transform(stroke.first);
                  canvas.moveTo(first.x, first.y);
                  for (final point in stroke.skip(1)) {
                    final p = transform(point);
                    canvas.lineTo(p.x, p.y);
                  }
                  continue;
                }
                // Same smoothing as the live signature pad: each raw
                // point becomes the control point of a curve ending at
                // the midpoint to the next point, converted to the
                // equivalent cubic Bezier since PdfGraphics only
                // exposes curveTo (cubic).
                var previous = transform(stroke[0]);
                canvas.moveTo(previous.x, previous.y);
                for (var i = 1; i < stroke.length - 1; i++) {
                  final control = transform(stroke[i]);
                  final next = transform(stroke[i + 1]);
                  final end = PdfPoint(
                    (control.x + next.x) / 2,
                    (control.y + next.y) / 2,
                  );
                  final c1 = PdfPoint(
                    previous.x + (control.x - previous.x) * 2 / 3,
                    previous.y + (control.y - previous.y) * 2 / 3,
                  );
                  final c2 = PdfPoint(
                    end.x + (control.x - end.x) * 2 / 3,
                    end.y + (control.y - end.y) * 2 / 3,
                  );
                  canvas.curveTo(c1.x, c1.y, c2.x, c2.y, end.x, end.y);
                  previous = end;
                }
                final last = transform(stroke.last);
                canvas.lineTo(last.x, last.y);
              }
              canvas.strokePath();
            },
          ),
        ),
        pw.SizedBox(height: 10),
        _field('ቀን', _ethiopianDateString(data.signedAt)),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _field(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.TextSpan(
            text: value,
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _guardianSection(int fieldNumber, Guardian guardian) {
  final addressParts = [
    if (guardian.subCity.isNotEmpty) guardian.subCity,
    if (guardian.woreda.isNotEmpty) guardian.woreda,
    if (guardian.houseNumber.isNotEmpty) guardian.houseNumber,
  ];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        '$fieldNumber. የወላጅ ${_amharicRelationship(guardian.relationship)} ስም',
        style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
      ),
      pw.SizedBox(height: 3),
      _field('ስም', guardian.name),
      _field(
        'ክ/ከተማ፡ ወረዳ፡ ቤት ቁጥር',
        addressParts.isEmpty ? '—' : addressParts.join(' / '),
      ),
      _field('ስልክ ቁጥር', guardian.phone),
    ],
  );
}

pw.Widget _pickupLine(String number, String name, String phone) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(
      '$number  ሙሉ ስም: $name    ስልክ ቁጥር: $phone',
      style: const pw.TextStyle(fontSize: 11),
    ),
  );
}

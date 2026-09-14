import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// يجمّع صفحات صور المستند (بعد كشف الحواف وتصحيح المنظور والتحسين)
/// في ملف PDF واحد متعدد الصفحات، بمقاس A4 وهوامش صفرية.
class PdfService {
  static Future<File> buildPdfFromImages({
    required List<String> imagePaths,
    required String outputPath,
  }) async {
    final document = pw.Document();

    for (final path in imagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    final file = File(outputPath);
    await file.create(recursive: true);
    await file.writeAsBytes(await document.save());
    return file;
  }
}

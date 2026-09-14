import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';

/// غلاف حول الماسح الأصلي: يفوّض كشف الحواف وتصحيح المنظور إلى
/// ML Kit Document Scanner API على أندرويد و VisionKit على iOS،
/// بدل إعادة تنفيذها يدوياً بـ OpenCV.
class ScannerService {
  /// يفتح واجهة المسح الأصلية ويعيد مسارات صفحات الصورة المقصوصة،
  /// أو null إذا ألغى المستخدم العملية.
  ///
  /// نستخدم getScannedDocumentAsImages() تحديداً لأنها -خلافاً لبعض
  /// الدوال الأخرى في هذه الحزمة- موثّقة كمدعومة على أندرويد و iOS معاً
  /// وبنفس بنية الإرجاع (images/count)، مما يبسّط خط أنابيب التحسين وPDF
  /// الخاص بنا اللاحق.
  static Future<List<String>?> scanDocumentPages({int maxPages = 20}) async {
    try {
      final result = await FlutterDocScanner().getScannedDocumentAsImages();
      if (result == null) return null;

      final map = result as Map;
      final images = (map['images'] ?? map['Uri']) as List?;
      if (images == null || images.isEmpty) return null;

      return images
          .map((uri) => Uri.parse(uri.toString()))
          .map((uri) => uri.scheme == 'file' ? uri.toFilePath() : uri.toString())
          .toList();
    } on PlatformException {
      return null;
    }
  }
}

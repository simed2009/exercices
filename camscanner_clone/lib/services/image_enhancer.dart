import 'dart:io';

import 'package:image/image.dart' as img;

/// فلاتر تحسين الصورة، تُطبَّق بعد كشف الحواف وتصحيح المنظور اللذين
/// يقوم بهما الماسح الأصلي (ML Kit / VisionKit).
enum ScanFilter { original, grayscale, blackAndWhite, enhanced }

extension ScanFilterLabel on ScanFilter {
  String get label {
    switch (this) {
      case ScanFilter.original:
        return 'أصلي';
      case ScanFilter.grayscale:
        return 'تدرج رمادي';
      case ScanFilter.blackAndWhite:
        return 'أبيض وأسود';
      case ScanFilter.enhanced:
        return 'تحسين تلقائي';
    }
  }
}

class ImageEnhancer {
  /// يطبّق [filter] على الصورة في [sourcePath] ويكتب الناتج إلى [outputPath].
  static Future<File> applyFilter({
    required String sourcePath,
    required String outputPath,
    required ScanFilter filter,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('تعذّر قراءة الصورة: $sourcePath');
    }

    late final img.Image processed;
    switch (filter) {
      case ScanFilter.original:
        processed = decoded;
        break;
      case ScanFilter.grayscale:
        processed = img.grayscale(decoded);
        break;
      case ScanFilter.blackAndWhite:
        processed = _blackAndWhite(decoded);
        break;
      case ScanFilter.enhanced:
        processed = _autoEnhance(decoded);
        break;
    }

    final outFile = File(outputPath);
    await outFile.create(recursive: true);
    await outFile.writeAsBytes(img.encodeJpg(processed, quality: 90));
    return outFile;
  }

  /// تحويل ثنائي (Binarization) شبيه بمظهر المستند الممسوح ضوئياً تقليدياً.
  static img.Image _blackAndWhite(img.Image src) {
    final gray = img.grayscale(src);
    return img.adjustColor(gray, contrast: 1.6, brightness: 1.05);
  }

  /// ضبط تباين/سطوع تلقائي بسيط لتوضيح النص وتنظيف الخلفية.
  static img.Image _autoEnhance(img.Image src) {
    return img.adjustColor(
      src,
      contrast: 1.25,
      saturation: 1.05,
      brightness: 1.03,
    );
  }
}

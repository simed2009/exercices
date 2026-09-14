import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// تعرّف ضوئي على الحروف (OCR) على الجهاز عبر ML Kit.
///
/// ⚠️ محدودية مهمة: محرك ML Kit للتعرف على النصوص يدعم فقط السكربتات
/// اللاتينية والصينية واليابانية والكورية والديفاناغارية، ولا يدعم
/// النص العربي حالياً. لدعم العربية لاحقاً يلزم بديل مثل Tesseract OCR
/// (ببيانات تدريب عربية) أو خدمة سحابية مثل Google Cloud Vision.
class OcrService {
  static final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// يستخرج النص الكامل من صورة الصفحة في [imagePath].
  static Future<String> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);
    return recognizedText.text;
  }

  /// يجب استدعاؤها عند إغلاق التطبيق لتحرير موارد المحرك الأصلي.
  static Future<void> dispose() {
    return _recognizer.close();
  }
}

# CamScanner Clone (MVP)

نموذج أولي (MVP) لتطبيق مسح مستندات شبيه بـ CamScanner، مبني بـ Flutter.

## المبادئ المطبَّقة في هذا الـ MVP

| المبدأ | التنفيذ |
|---|---|
| كشف الحواف + تصحيح المنظور | عبر الماسح الأصلي: **ML Kit Document Scanner API** على أندرويد و **VisionKit** على iOS، من خلال حزمة `flutter_doc_scanner` (`lib/services/scanner_service.dart`) |
| تحسين الصورة (رمادي / أبيض وأسود / تحسين تلقائي) | معالجة صور خالصة بـ Dart عبر حزمة `image`، بدون تبعيات أصلية إضافية (`lib/services/image_enhancer.dart`) |
| توليد PDF متعدد الصفحات | حزمة `pdf` (`lib/services/pdf_service.dart`) |
| مكتبة مستندات محلية | فهرس JSON + مجلد لكل مستند داخل مساحة تخزين التطبيق (`lib/services/document_store.dart`) |
| المشاركة/التصدير | حزمة `share_plus` لمشاركة ملف الـ PDF الناتج |
| التعرف الضوئي على الحروف (OCR) | `google_mlkit_text_recognition` على الجهاز، بزر "استخراج النص" في شاشة عرض المستند، مع بحث بالعنوان أو بالنص المستخرج من شاشة المكتبة (`lib/services/ocr_service.dart`) |

### ⚠️ محدودية OCR الحالية: لا دعم للعربية

محرك `google_mlkit_text_recognition` على الجهاز يدعم فقط السكربتات **اللاتينية، الصينية، اليابانية، الكورية، والديفاناغارية** — **ولا يدعم النص العربي**. بما أن واجهة التطبيق عربية، هذا قيد حقيقي يجب معرفته قبل الاعتماد على الميزة لمسح مستندات عربية. البدائل لدعم العربية لاحقاً:

- **Tesseract OCR** (عبر `tesseract.js`/bindings أصلية) ببيانات تدريب `ara.traineddata` — يعمل offline لكن دقته عادة أقل من ML Kit للاتينية.
- **خدمة سحابية** مثل Google Cloud Vision API أو Azure Computer Vision، وكلاهما يدعم العربية بدقة جيدة لكن يتطلب اتصال إنترنت ومفتاح API ومصاريف استخدام.

**خارج نطاق هذا الـ MVP عمداً** (خطوات تالية مقترحة): دعم OCR عربي، التخزين السحابي والمزامنة، والذكاء الاصطناعي لتحسين الكشف — كما ورد في خارطة الطريق الأصلية.

## ⚠️ ملاحظة مهمة حول هذه البيئة

تمت كتابة هذا الكود في بيئة **لا يتوفر فيها Flutter SDK**، لذا لم يُشغَّل `flutter pub get` ولا `flutter analyze`/`flutter build` هنا، ولم يُختبر التطبيق فعلياً على جهاز أو محاكي. راجع الكود وشغّله محلياً قبل الاعتماد عليه.

كذلك، مجلدات المنصات (`android/`, `ios/`) **غير موجودة** في هذا المستودع لأنها تُنشأ عادة تلقائياً بواسطة أداة `flutter create` (وهي غير متوفرة هنا). اتبع خطوات الإعداد أدناه لإنشائها.

## الإعداد المحلي (على جهازك)

```bash
cd camscanner_clone

# ينشئ مجلدات android/ و ios/ دون المساس بـ lib/ أو pubspec.yaml الموجودَين
flutter create --org com.example --project-name camscanner_clone .

flutter pub get
```

### أذونات لازمة

**Android** — أضف داخل `android/app/src/main/AndroidManifest.xml` (داخل وسم `<manifest>`، قبل `<application>`):

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

وفي `android/app/build.gradle` اضبط داخل `defaultConfig`: `minSdkVersion 21`، و`compileSdkVersion`/`targetSdkVersion` إلى `35` (يتطلبها `google_mlkit_text_recognition`؛ ML Kit Document Scanner يكتفي بـ 21).

**iOS** — الحد الأدنى الفعلي هو **iOS 15.5** (يفرضه `google_mlkit_text_recognition`؛ `flutter_doc_scanner` يكتفي بـ 13.0). اضبط `platform :ios, '15.5'` في `ios/Podfile`. أضف داخل `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>يحتاج التطبيق إلى الكاميرا لمسح المستندات</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>يحتاج التطبيق لحفظ/مشاركة ملفات PDF الناتجة</string>
```

وفي `ios/Podfile`، داخل `post_install`، فعّل إذن الكاميرا للحزمة (راجع تعليمات `flutter_doc_scanner` لصيغة `GCC_PREPROCESSOR_DEFINITIONS` الحالية إن تغيّرت)، ثم:

```bash
cd ios && pod install && cd ..
```

### التشغيل

```bash
flutter run
```

## بنية المشروع

```
lib/
  models/scanned_document.dart     # نموذج المستند (id, عنوان, تاريخ, مسارات الصفحات, نص OCR لكل صفحة)
  services/
    scanner_service.dart           # غلاف حول الماسح الأصلي (كشف حواف + تصحيح منظور)
    image_enhancer.dart            # فلاتر: أصلي / رمادي / أبيض وأسود / تحسين تلقائي
    ocr_service.dart               # التعرف الضوئي على الحروف عبر ML Kit (لاتيني فقط حالياً)
    pdf_service.dart               # تجميع الصفحات في PDF واحد
    document_store.dart            # مكتبة المستندات المحلية (فهرس JSON + ملفات)
  screens/
    home_screen.dart               # شبكة المستندات + بحث بالعنوان/بنص OCR + زر "مسح مستند"
    document_viewer_screen.dart    # عرض الصفحات، الفلاتر، OCR، الحذف، التصدير/المشاركة
  widgets/document_grid_tile.dart
  main.dart
```

## الخطوات التالية المقترحة

1. **دعم OCR للعربية**: عبر Tesseract (بيانات `ara.traineddata`) أو خدمة سحابية — راجع قسم "محدودية OCR" أعلاه.
2. **التخزين السحابي**: مزامنة `DocumentStore` مع Firebase (Firestore + Storage) أو backend خاص.
3. **ترتيب الصفحات بالسحب**: `ReorderableListView` لشريط مصغرات الصفحات في `document_viewer_screen.dart`.
4. **تصنيف/وسوم تلقائية**: بالاستفادة من نص OCR المستخرج، يمكن تصنيف المستندات (فاتورة، إيصال، عقد...) بنموذج تعلّم آلي بسيط أو حتى بقواعد بمطابقة كلمات مفتاحية.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/scanned_document.dart';
import 'pdf_service.dart';

/// يدير مكتبة المستندات المحلية: تخزين صفحات كل مستند في مجلده الخاص،
/// وحفظ فهرس JSON (documents.json) بميتاداتا كل مستند لاستعادتها بين الجلسات.
class DocumentStore extends ChangeNotifier {
  static const _uuid = Uuid();

  final List<ScannedDocument> _documents = [];
  Directory? _rootDir;
  bool _loading = true;

  List<ScannedDocument> get documents => List.unmodifiable(_documents);
  bool get isLoading => _loading;

  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _rootDir = Directory(p.join(appDir.path, 'scans'))
      ..createSync(recursive: true);

    final indexFile = _indexFile;
    if (indexFile.existsSync()) {
      try {
        final raw = jsonDecode(await indexFile.readAsString()) as List;
        _documents
          ..clear()
          ..addAll(raw.map((e) => ScannedDocument.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // فهرس تالف: نبدأ بمكتبة فارغة بدلاً من تعطيل التطبيق.
      }
    }

    _loading = false;
    notifyListeners();
  }

  File get _indexFile => File(p.join(_rootDir!.path, 'documents.json'));

  Future<void> _persistIndex() async {
    final data = _documents.map((d) => d.toJson()).toList();
    await _indexFile.writeAsString(jsonEncode(data));
  }

  /// ينشئ مستنداً جديداً بنسخ صفحاته (نواتج الماسح الأصلي) إلى مجلد خاص به.
  Future<ScannedDocument> createDocument({
    required String title,
    required List<String> sourcePagePaths,
  }) async {
    final id = _uuid.v4();
    final docDir = Directory(p.join(_rootDir!.path, id))
      ..createSync(recursive: true);

    final storedPaths = <String>[];
    for (var i = 0; i < sourcePagePaths.length; i++) {
      final ext = p.extension(sourcePagePaths[i]).isEmpty
          ? '.jpg'
          : p.extension(sourcePagePaths[i]);
      final destPath = p.join(docDir.path, 'page_${i.toString().padLeft(3, '0')}$ext');
      await File(sourcePagePaths[i]).copy(destPath);
      storedPaths.add(destPath);
    }

    final document = ScannedDocument(
      id: id,
      title: title,
      createdAt: DateTime.now(),
      pagePaths: storedPaths,
    );

    _documents.insert(0, document);
    await _persistIndex();
    notifyListeners();
    return document;
  }

  Future<void> renameDocument(String id, String newTitle) async {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(title: newTitle);
    await _persistIndex();
    notifyListeners();
  }

  Future<void> updatePages(String id, List<String> newPagePaths) async {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(pagePaths: newPagePaths);
    await _persistIndex();
    notifyListeners();
  }

  /// يحفظ نص OCR مستخرَجاً لصفحة بعينها (مفتاح النص هو مسار ملف تلك الصفحة).
  Future<void> setPageText(String id, String pagePath, String text) async {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    final newPageText = Map<String, String>.from(_documents[index].pageText)
      ..[pagePath] = text;
    _documents[index] = _documents[index].copyWith(pageText: newPageText);
    await _persistIndex();
    notifyListeners();
  }

  Future<void> deleteDocument(String id) async {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    final docDir = Directory(p.join(_rootDir!.path, id));
    if (docDir.existsSync()) {
      await docDir.delete(recursive: true);
    }
    _documents.removeAt(index);
    await _persistIndex();
    notifyListeners();
  }

  /// يصدّر مستنداً كملف PDF داخل مجلده الخاص ويعيد مسار الملف.
  Future<File> exportAsPdf(ScannedDocument document) async {
    // يُشتق اسم الملف من عنوان المستند، لذا نزيل فواصل المسارات وما شابهها
    // كي لا يكتب الملف خارج مجلد المستند المقصود.
    final safeTitle = document.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final fileName = safeTitle.isEmpty ? document.id : safeTitle;
    final outputPath = p.join(_rootDir!.path, document.id, '$fileName.pdf');
    return PdfService.buildPdfFromImages(
      imagePaths: document.pagePaths,
      outputPath: outputPath,
    );
  }
}

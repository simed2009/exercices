import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/scanned_document.dart';
import '../services/document_store.dart';
import '../services/image_enhancer.dart';
import '../services/ocr_service.dart';

class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key, required this.documentId});

  final String documentId;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ScannedDocument? _findDocument(DocumentStore store) {
    for (final doc in store.documents) {
      if (doc.id == widget.documentId) return doc;
    }
    return null;
  }

  Future<void> _applyFilter(ScannedDocument document, ScanFilter filter) async {
    setState(() => _busy = true);
    final store = context.read<DocumentStore>();
    try {
      final sourcePath = document.pagePaths[_currentPage];
      final outputPath = filter == ScanFilter.original
          ? sourcePath
          : p.join(
              p.dirname(sourcePath),
              '${p.basenameWithoutExtension(sourcePath)}_${filter.name}${p.extension(sourcePath)}',
            );

      if (filter != ScanFilter.original) {
        await ImageEnhancer.applyFilter(
          sourcePath: sourcePath,
          outputPath: outputPath,
          filter: filter,
        );
      }

      final newPages = [...document.pagePaths];
      newPages[_currentPage] = outputPath;
      await store.updatePages(document.id, newPages);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCurrentPage(ScannedDocument document) async {
    if (document.pagePaths.length <= 1) {
      final confirmed = await _confirm('حذف آخر صفحة سيحذف المستند بالكامل. متابعة؟');
      if (confirmed != true) return;
      await context.read<DocumentStore>().deleteDocument(document.id);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final newPages = [...document.pagePaths]..removeAt(_currentPage);
    await context.read<DocumentStore>().updatePages(document.id, newPages);
    setState(() {
      _currentPage = _currentPage.clamp(0, newPages.length - 1);
    });
  }

  Future<bool?> _confirm(String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );
  }

  Future<void> _rename(ScannedDocument document) async {
    final controller = TextEditingController(text: document.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تسمية المستند'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      await context.read<DocumentStore>().renameDocument(document.id, newTitle);
    }
  }

  Future<void> _runOcr(ScannedDocument document) async {
    final currentPath = document.pagePaths[_currentPage];
    final cached = document.pageText[currentPath];
    if (cached != null) {
      _showOcrResult(cached);
      return;
    }

    setState(() => _busy = true);
    try {
      final text = await OcrService.recognizeText(currentPath);
      if (!mounted) return;
      await context.read<DocumentStore>().setPageText(document.id, currentPath, text);
      _showOcrResult(text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر استخراج النص من هذه الصفحة.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showOcrResult(String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'النص المستخرج',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_outlined),
                        tooltip: 'نسخ',
                        onPressed: text.isEmpty
                            ? null
                            : () {
                                Clipboard.setData(ClipboardData(text: text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم نسخ النص')),
                                );
                              },
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text(
                    'يدعم هذا الإصدار النصوص اللاتينية فقط (لا يدعم العربية بعد).',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: SelectableText(
                        text.isEmpty ? 'لم يُعثر على نص في هذه الصفحة.' : text,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportAndShare(ScannedDocument document) async {
    setState(() => _busy = true);
    try {
      final pdfFile = await context.read<DocumentStore>().exportAsPdf(document);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(pdfFile.path)], text: document.title),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DocumentStore>();
    final document = _findDocument(store);

    if (document == null) {
      return const Scaffold(body: Center(child: Text('تم حذف هذا المستند')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_snippet_outlined),
            tooltip: 'استخراج النص (OCR)',
            onPressed: _busy ? null : () => _runOcr(document),
          ),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _rename(document)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await _confirm('حذف المستند "${document.title}" نهائياً؟');
              if (confirmed == true) {
                await context.read<DocumentStore>().deleteDocument(document.id);
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: document.pagePaths.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, i) => InteractiveViewer(
                    child: Center(child: Image.file(File(document.pagePaths[i]))),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${_currentPage + 1} / ${document.pagePaths.length}'),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: ScanFilter.values
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ActionChip(
                            label: Text(f.label),
                            onPressed: _busy ? null : () => _applyFilter(document, f),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : () => _deleteCurrentPage(document),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('حذف الصفحة'),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _exportAndShare(document),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('تصدير ومشاركة PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
          if (_busy) const ColoredBox(color: Colors.black26, child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

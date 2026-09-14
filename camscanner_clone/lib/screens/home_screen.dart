import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/scanned_document.dart';
import '../services/document_store.dart';
import '../services/scanner_service.dart';
import '../widgets/document_grid_tile.dart';
import 'document_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _scanning = false;

  Future<void> _startScan() async {
    setState(() => _scanning = true);
    try {
      final pages = await ScannerService.scanDocumentPages();
      if (pages == null || pages.isEmpty) return;
      if (!mounted) return;

      final title = await _promptTitle();
      if (title == null) return;

      final store = context.read<DocumentStore>();
      final document = await store.createDocument(
        title: title,
        sourcePagePaths: pages,
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentViewerScreen(documentId: document.id),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<String?> _promptTitle() async {
    final controller = TextEditingController(
      text: 'مستند ${DateTime.now().toString().substring(0, 16)}',
    );
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اسم المستند'),
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
  }

  Future<void> _showDocumentActions(ScannedDocument document) async {
    final store = context.read<DocumentStore>();
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('حذف المستند'),
              onTap: () async {
                Navigator.pop(context);
                await store.deleteDocument(document.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DocumentStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('مستنداتي')),
      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : store.documents.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا توجد مستندات بعد.\nاضغط على زر المسح لبدء أول مستند.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: store.documents.length,
                  itemBuilder: (context, i) {
                    final document = store.documents[i];
                    return DocumentGridTile(
                      document: document,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DocumentViewerScreen(documentId: document.id),
                        ),
                      ),
                      onLongPress: () => _showDocumentActions(document),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? null : _startScan,
        icon: _scanning
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.document_scanner_outlined),
        label: const Text('مسح مستند'),
      ),
    );
  }
}

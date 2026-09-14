import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../models/scanned_document.dart';

class DocumentGridTile extends StatelessWidget {
  const DocumentGridTile({
    super.key,
    required this.document,
    required this.onTap,
    required this.onLongPress,
  });

  final ScannedDocument document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final thumb = document.thumbnailPath;
    final dateLabel = intl.DateFormat('yyyy/MM/dd').format(document.createdAt);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.grey.shade200,
                child: thumb == null
                    ? const Icon(Icons.description_outlined, size: 48, color: Colors.grey)
                    : Image.file(File(thumb), fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            document.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '${document.pagePaths.length} صفحة  •  $dateLabel',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

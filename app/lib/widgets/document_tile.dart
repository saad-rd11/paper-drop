import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document.dart';
import '../providers/document_provider.dart';

class DocumentTile extends ConsumerWidget {
  final Document document;
  final String workspaceId;

  const DocumentTile({
    super.key,
    required this.document,
    required this.workspaceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: document.isPastPaper
                ? const Color(0xFFFFF3E0)
                : const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            document.isPastPaper ? Icons.history_edu : Icons.picture_as_pdf,
            color: document.isPastPaper
                ? const Color(0xFFE65100)
                : const Color(0xFF1565C0),
            size: 20,
          ),
        ),
        title: Text(
          document.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            if (document.isPastPaper)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Past Paper',
                  style: TextStyle(fontSize: 10, color: Color(0xFFE65100)),
                ),
              ),
            Icon(
              document.processed ? Icons.check_circle : Icons.pending,
              size: 14,
              color: document.processed ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              document.processed ? 'Processed' : 'Processing...',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'toggle') {
              ref
                  .read(documentsProvider(workspaceId).notifier)
                  .togglePastPaper(document.id, !document.isPastPaper);
            } else if (value == 'delete') {
              ref
                  .read(documentsProvider(workspaceId).notifier)
                  .delete(document);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(
                document.isPastPaper
                    ? 'Mark as study material'
                    : 'Mark as past paper',
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

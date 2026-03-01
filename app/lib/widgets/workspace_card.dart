import 'package:flutter/material.dart';
import '../models/workspace.dart';
import '../screens/workspace_screen.dart';

class WorkspaceCard extends StatelessWidget {
  final Workspace workspace;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;

  const WorkspaceCard({
    super.key,
    required this.workspace,
    this.onDelete,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkspaceScreen(workspace: workspace),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workspace.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (workspace.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        workspace.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(workspace.createdAt),
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(
                          0.6,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildPopupMenu(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Theme.of(context).textTheme.bodySmall?.color,
      ),
      onSelected: (value) {
        switch (value) {
          case 'open':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkspaceScreen(workspace: workspace),
              ),
            );
            break;
          case 'rename':
            onRename?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 18),
              SizedBox(width: 8),
              Text('Open'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: 18),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}

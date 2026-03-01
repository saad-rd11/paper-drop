import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/workspace.dart';
import '../providers/document_provider.dart';
import '../widgets/document_tile.dart';
import '../widgets/logo.dart';
import 'chat_screen.dart';
import 'agent_screen.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  final Workspace workspace;
  const WorkspaceScreen({super.key, required this.workspace});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const PaperDropIcon(size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.workspace.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodySmall?.color,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.description_outlined), text: 'Documents'),
            Tab(icon: Icon(Icons.chat_outlined), text: 'Chat'),
            Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'Agent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _DocumentsTab(workspace: widget.workspace),
          ChatScreen(workspaceId: widget.workspace.id),
          AgentScreen(workspaceId: widget.workspace.id),
        ],
      ),
    );
  }
}

class _DocumentsTab extends ConsumerWidget {
  final Workspace workspace;
  const _DocumentsTab({required this.workspace});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider(workspace.id));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: docs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading documents',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('$e', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upload_file,
                    size: 64,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No documents yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload a PDF to get started',
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(documentsProvider(workspace.id).notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) =>
                  DocumentTile(document: list[i], workspaceId: workspace.id),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _uploadPdf(context, ref),
        icon: const Icon(Icons.upload),
        label: const Text('Upload PDF'),
      ),
    );
  }

  Future<void> _uploadPdf(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // required for web — loads bytes into memory
    );
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.single;
    final fileBytes = pickedFile.bytes;
    if (fileBytes == null) return; // safety check

    final fileName = pickedFile.name;

    if (!context.mounted) return;

    // Ask if it's a past paper
    final isPastPaper = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Document Type'),
        content: const Text('Is this a past examination paper?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, study material'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, past paper'),
          ),
        ],
      ),
    );
    if (isPastPaper == null) return;

    ref
        .read(documentsProvider(workspace.id).notifier)
        .upload(
          fileBytes: fileBytes,
          fileName: fileName,
          isPastPaper: isPastPaper,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Uploading and processing PDF...'),
          backgroundColor: theme.colorScheme.primary,
        ),
      );
    }
  }
}

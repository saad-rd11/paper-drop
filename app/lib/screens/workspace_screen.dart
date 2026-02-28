import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/workspace.dart';
import '../providers/document_provider.dart';
import '../widgets/document_tile.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.workspace.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6C63FF),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: docs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upload_file,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No documents yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload a PDF to get started',
                    style: TextStyle(color: Colors.grey.shade500),
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
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.upload, color: Colors.white),
        label: const Text('Upload PDF', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _uploadPdf(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final fileName = result.files.single.name;

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
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
            ),
            child: const Text('Yes, past paper'),
          ),
        ],
      ),
    );
    if (isPastPaper == null) return;

    ref
        .read(documentsProvider(workspace.id).notifier)
        .upload(file: file, fileName: fileName, isPastPaper: isPastPaper);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading and processing PDF...')),
      );
    }
  }
}

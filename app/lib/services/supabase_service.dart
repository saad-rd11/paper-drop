import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workspace.dart';
import '../models/document.dart';
import '../models/chat_message.dart';
import '../models/generated_paper.dart';
import '../config/constants.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Current authenticated user's ID (throws if not logged in).
  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.id;
  }

  // ── Workspaces ──────────────────────────────────────────────

  Future<List<Workspace>> getWorkspaces() async {
    final data = await _client
        .from('workspaces')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return data.map((json) => Workspace.fromJson(json)).toList();
  }

  Future<Workspace> createWorkspace(String name, String description) async {
    final data = await _client
        .from('workspaces')
        .insert({'name': name, 'description': description, 'user_id': _userId})
        .select()
        .single();
    return Workspace.fromJson(data);
  }

  Future<void> deleteWorkspace(String id) async {
    // Storage files are cleaned up via cascade or manually
    final docs = await getDocuments(id);
    for (final doc in docs) {
      await _client.storage.from(AppConstants.pdfBucket).remove([
        doc.storagePath,
      ]);
    }
    await _client.from('workspaces').delete().eq('id', id);
  }

  Future<void> updateChatSummary(String workspaceId, String summary) async {
    await _client
        .from('workspaces')
        .update({'chat_summary': summary})
        .eq('id', workspaceId);
  }

  Future<Workspace> getWorkspace(String id) async {
    final data = await _client
        .from('workspaces')
        .select()
        .eq('id', id)
        .single();
    return Workspace.fromJson(data);
  }

  Future<void> renameWorkspace(
    String id,
    String name,
    String description,
  ) async {
    await _client
        .from('workspaces')
        .update({'name': name, 'description': description})
        .eq('id', id);
  }

  // ── Documents ───────────────────────────────────────────────

  Future<List<Document>> getDocuments(String workspaceId) async {
    final data = await _client
        .from('documents')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return data.map((json) => Document.fromJson(json)).toList();
  }

  Future<Document> uploadDocument({
    required String workspaceId,
    required Uint8List fileBytes,
    required String fileName,
    required bool isPastPaper,
  }) async {
    // 1. Insert document record to get an ID
    final docData = await _client
        .from('documents')
        .insert({
          'workspace_id': workspaceId,
          'file_name': fileName,
          'storage_path': '', // updated after upload
          'is_past_paper': isPastPaper,
        })
        .select()
        .single();
    final docId = docData['id'] as String;

    // 2. Upload bytes to storage (works on web + mobile)
    final storagePath = '$workspaceId/$docId.pdf';
    await _client.storage
        .from(AppConstants.pdfBucket)
        .uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: const FileOptions(contentType: 'application/pdf'),
        );

    // 3. Update storage path
    await _client
        .from('documents')
        .update({'storage_path': storagePath})
        .eq('id', docId);

    return Document.fromJson({...docData, 'storage_path': storagePath});
  }

  Future<void> deleteDocument(Document doc) async {
    await _client.storage.from(AppConstants.pdfBucket).remove([
      doc.storagePath,
    ]);
    await _client.from('documents').delete().eq('id', doc.id);
  }

  Future<void> togglePastPaper(String docId, bool isPastPaper) async {
    await _client
        .from('documents')
        .update({'is_past_paper': isPastPaper})
        .eq('id', docId);
  }

  // ── Chat Messages ──────────────────────────────────────────

  Future<List<ChatMessage>> getChatMessages(String workspaceId) async {
    final data = await _client
        .from('chat_messages')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: true);
    return data.map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<void> saveChatMessage(ChatMessage message) async {
    await _client.from('chat_messages').insert(message.toInsertJson());
  }

  Future<void> clearChat(String workspaceId) async {
    await _client
        .from('chat_messages')
        .delete()
        .eq('workspace_id', workspaceId);
    await _client
        .from('workspaces')
        .update({'chat_summary': null})
        .eq('id', workspaceId);
  }

  // ── Generated Papers ───────────────────────────────────────

  Future<List<GeneratedPaper>> getGeneratedPapers(String workspaceId) async {
    final data = await _client
        .from('generated_papers')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return data.map((json) => GeneratedPaper.fromJson(json)).toList();
  }
}

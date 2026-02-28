import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../services/supabase_service.dart';
import '../services/api_service.dart';
import 'workspace_provider.dart';
import 'document_provider.dart';

final chatProvider =
    AsyncNotifierProvider.family<ChatNotifier, List<ChatMessage>, String>(
      ChatNotifier.new,
    );

class ChatNotifier extends FamilyAsyncNotifier<List<ChatMessage>, String> {
  SupabaseService get _db => ref.read(supabaseServiceProvider);
  ApiService get _api => ref.read(apiServiceProvider);

  bool _sending = false;
  bool get isSending => _sending;

  @override
  Future<List<ChatMessage>> build(String workspaceId) =>
      _db.getChatMessages(workspaceId);

  /// Send a message, get AI response, save both to DB.
  Future<void> send(String message) async {
    if (_sending) return;
    _sending = true;

    final current = state.valueOrNull ?? [];

    // Optimistically add user message
    final userMsg = ChatMessage(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      workspaceId: arg,
      role: 'user',
      content: message,
      createdAt: DateTime.now(),
    );
    state = AsyncData([...current, userMsg]);

    try {
      // Call backend RAG chat
      await _api.chat(workspaceId: arg, message: message);

      // Refresh from DB (backend saves both messages)
      state = AsyncData(await _db.getChatMessages(arg));
    } catch (e) {
      // On error, add an error message locally
      final errMsg = ChatMessage(
        id: 'err-${DateTime.now().millisecondsSinceEpoch}',
        workspaceId: arg,
        role: 'assistant',
        content: 'Failed to get response. Check your connection and try again.',
        createdAt: DateTime.now(),
      );
      state = AsyncData([...current, userMsg, errMsg]);
    } finally {
      _sending = false;
    }
  }

  Future<void> clearChat() async {
    await _db.clearChat(arg);
    state = const AsyncData([]);
  }

  Future<void> refresh() async {
    state = AsyncData(await _db.getChatMessages(arg));
  }
}

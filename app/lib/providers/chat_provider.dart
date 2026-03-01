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

/// Provider to track the currently streaming response text
final streamingResponseProvider = StateProvider.family<String, String>(
  (ref, workspaceId) => '',
);

class ChatNotifier extends FamilyAsyncNotifier<List<ChatMessage>, String> {
  SupabaseService get _db => ref.read(supabaseServiceProvider);
  ApiService get _api => ref.read(apiServiceProvider);

  bool _sending = false;
  bool get isSending => _sending;

  @override
  Future<List<ChatMessage>> build(String workspaceId) =>
      _db.getChatMessages(workspaceId);

  /// Send a message and stream the AI response.
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

    // Create a placeholder for the streaming response
    final streamingMsgId = 'stream-${DateTime.now().millisecondsSinceEpoch}';
    final streamingMsg = ChatMessage(
      id: streamingMsgId,
      workspaceId: arg,
      role: 'assistant',
      content: '',
      createdAt: DateTime.now(),
    );
    state = AsyncData([...current, userMsg, streamingMsg]);

    try {
      // Stream the response
      final buffer = StringBuffer();
      await for (final chunk in _api.chatStream(
        workspaceId: arg,
        message: message,
      )) {
        buffer.write(chunk);

        // Update the streaming response in real-time
        final updatedMsg = ChatMessage(
          id: streamingMsgId,
          workspaceId: arg,
          role: 'assistant',
          content: buffer.toString(),
          createdAt: streamingMsg.createdAt,
        );
        state = AsyncData([...current, userMsg, updatedMsg]);
      }

      // Refresh from DB to get the final saved message with sources
      state = AsyncData(await _db.getChatMessages(arg));
    } catch (e) {
      // On error, update the streaming message with error text
      final errMsg = ChatMessage(
        id: streamingMsgId,
        workspaceId: arg,
        role: 'assistant',
        content: 'Failed to get response. Check your connection and try again.',
        createdAt: streamingMsg.createdAt,
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

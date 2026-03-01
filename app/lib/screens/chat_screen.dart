import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String workspaceId;
  const ChatScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(chatProvider(widget.workspaceId).notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider(widget.workspaceId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Messages
        Expanded(
          child: messages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading messages',
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
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ask a question about your documents',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload PDFs in the Documents tab first',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              _scrollToBottom();
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => ChatBubble(message: list[i]),
              );
            },
          ),
        ),

        // Input bar
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask about your documents...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor:
                          theme.colorScheme.surfaceContainerHighest
                              ?.withOpacity(0.5) ??
                          colorScheme.onSurface.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.send, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

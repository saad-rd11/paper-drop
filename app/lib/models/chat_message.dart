class ChatMessage {
  final String id;
  final String workspaceId;
  final String role; // 'user' or 'assistant'
  final String content;
  final List<SourceRef> sources;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.workspaceId,
    required this.role,
    required this.content,
    this.sources = const [],
    required this.createdAt,
  });

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    List<SourceRef> sources = [];
    if (rawSources is List) {
      sources = rawSources
          .map((s) => SourceRef.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    return ChatMessage(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      sources: sources,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'workspace_id': workspaceId,
      'role': role,
      'content': content,
      'sources': sources.map((s) => s.toJson()).toList(),
    };
  }
}

class SourceRef {
  final String doc;
  final int page;

  SourceRef({required this.doc, required this.page});

  factory SourceRef.fromJson(Map<String, dynamic> json) {
    return SourceRef(
      doc: json['doc'] as String,
      page: (json['page'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {'doc': doc, 'page': page};
}

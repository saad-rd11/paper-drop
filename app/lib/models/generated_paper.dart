class GeneratedPaper {
  final String id;
  final String workspaceId;
  final String title;
  final String content; // markdown
  final Map<String, dynamic> analysis;
  final DateTime createdAt;

  GeneratedPaper({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.content,
    this.analysis = const {},
    required this.createdAt,
  });

  factory GeneratedPaper.fromJson(Map<String, dynamic> json) {
    return GeneratedPaper(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      analysis: (json['analysis'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

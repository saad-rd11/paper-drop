class Workspace {
  final String id;
  final String name;
  final String description;
  final String? chatSummary;
  final DateTime createdAt;

  Workspace({
    required this.id,
    required this.name,
    this.description = '',
    this.chatSummary,
    required this.createdAt,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      chatSummary: json['chat_summary'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {'name': name, 'description': description};
  }

  Workspace copyWith({String? name, String? description, String? chatSummary}) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      chatSummary: chatSummary ?? this.chatSummary,
      createdAt: createdAt,
    );
  }
}

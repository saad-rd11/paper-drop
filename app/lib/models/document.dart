class Document {
  final String id;
  final String workspaceId;
  final String fileName;
  final String storagePath;
  final int pageCount;
  final bool isPastPaper;
  final bool processed;
  final DateTime createdAt;

  Document({
    required this.id,
    required this.workspaceId,
    required this.fileName,
    required this.storagePath,
    this.pageCount = 0,
    this.isPastPaper = false,
    this.processed = false,
    required this.createdAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      fileName: json['file_name'] as String,
      storagePath: json['storage_path'] as String,
      pageCount: (json['page_count'] as int?) ?? 0,
      isPastPaper: (json['is_past_paper'] as bool?) ?? false,
      processed: (json['processed'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'workspace_id': workspaceId,
      'file_name': fileName,
      'storage_path': storagePath,
      'is_past_paper': isPastPaper,
    };
  }

  Document copyWith({bool? isPastPaper, bool? processed, int? pageCount}) {
    return Document(
      id: id,
      workspaceId: workspaceId,
      fileName: fileName,
      storagePath: storagePath,
      pageCount: pageCount ?? this.pageCount,
      isPastPaper: isPastPaper ?? this.isPastPaper,
      processed: processed ?? this.processed,
      createdAt: createdAt,
    );
  }
}

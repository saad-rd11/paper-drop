import 'package:dio/dio.dart';
import '../config/constants.dart';

/// HTTP client for the Python backend.
/// Handles PDF processing, RAG chat, and agent operations.
class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.backendUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 120), // LLM calls can be slow
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  // ── PDF Processing ─────────────────────────────────────────

  /// Trigger server-side PDF processing (extract, chunk, embed).
  Future<Map<String, dynamic>> processPdf({
    required String documentId,
    required String workspaceId,
  }) async {
    final response = await _dio.post(
      '/process-pdf',
      data: {'document_id': documentId, 'workspace_id': workspaceId},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Chat (RAG) ─────────────────────────────────────────────

  /// Send a message and get a RAG-powered response.
  /// Returns { "reply": "...", "sources": [...] }
  Future<Map<String, dynamic>> chat({
    required String workspaceId,
    required String message,
  }) async {
    final response = await _dio.post(
      '/chat',
      data: {'workspace_id': workspaceId, 'message': message},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Stream a chat response using Server-Sent Events (SSE).
  /// Returns a stream of text chunks.
  Stream<String> chatStream({
    required String workspaceId,
    required String message,
  }) async* {
    final response = await _dio.get(
      '/chat/stream',
      queryParameters: {'workspace_id': workspaceId, 'message': message},
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data as ResponseBody;
    final buffer = StringBuffer();

    await for (final chunk in stream.stream) {
      final text = String.fromCharCodes(chunk);
      buffer.write(text);

      // Process complete SSE lines
      final lines = buffer.toString().split('\n');
      buffer.clear();

      // Keep the last incomplete line in buffer
      if (!text.endsWith('\n')) {
        buffer.write(lines.last);
        lines.removeLast();
      }

      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') return;
          if (data.startsWith('ERROR:')) throw Exception(data);
          yield data;
        }
      }
    }
  }

  // ── Agent ──────────────────────────────────────────────────

  /// Analyze past papers in a workspace.
  /// Returns { "analysis": { ... } }
  Future<Map<String, dynamic>> analyzePastPapers({
    required String workspaceId,
  }) async {
    final response = await _dio.post(
      '/agent/analyze',
      data: {'workspace_id': workspaceId},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Generate a practice paper based on analysis.
  /// Returns { "paper_id": "...", "title": "...", "content": "..." }
  Future<Map<String, dynamic>> generatePaper({
    required String workspaceId,
    required Map<String, dynamic> analysis,
  }) async {
    final response = await _dio.post(
      '/agent/generate',
      data: {'workspace_id': workspaceId, 'analysis': analysis},
    );
    return response.data as Map<String, dynamic>;
  }
}

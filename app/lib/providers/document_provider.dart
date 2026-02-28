import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document.dart';
import '../services/supabase_service.dart';
import '../services/api_service.dart';
import 'workspace_provider.dart';

final apiServiceProvider = Provider((_) => ApiService());

final documentsProvider =
    AsyncNotifierProvider.family<DocumentsNotifier, List<Document>, String>(
      DocumentsNotifier.new,
    );

class DocumentsNotifier extends FamilyAsyncNotifier<List<Document>, String> {
  SupabaseService get _db => ref.read(supabaseServiceProvider);
  ApiService get _api => ref.read(apiServiceProvider);

  @override
  Future<List<Document>> build(String workspaceId) =>
      _db.getDocuments(workspaceId);

  Future<void> upload({
    required File file,
    required String fileName,
    required bool isPastPaper,
  }) async {
    try {
      // 1. Upload to Supabase
      final doc = await _db.uploadDocument(
        workspaceId: arg,
        file: file,
        fileName: fileName,
        isPastPaper: isPastPaper,
      );

      // 2. Trigger backend processing
      try {
        await _api.processPdf(documentId: doc.id, workspaceId: arg);
      } catch (_) {
        // Processing can be retried later; doc is already uploaded
      }

      // 3. Refresh list
      state = AsyncData(await _db.getDocuments(arg));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> delete(Document doc) async {
    try {
      await _db.deleteDocument(doc);
      state = AsyncData(await _db.getDocuments(arg));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> togglePastPaper(String docId, bool value) async {
    try {
      await _db.togglePastPaper(docId, value);
      state = AsyncData(await _db.getDocuments(arg));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    try {
      state = AsyncData(await _db.getDocuments(arg));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

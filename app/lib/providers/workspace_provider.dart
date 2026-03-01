import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workspace.dart';
import '../services/supabase_service.dart';

final supabaseServiceProvider = Provider((_) => SupabaseService());

final workspacesProvider =
    AsyncNotifierProvider<WorkspacesNotifier, List<Workspace>>(
      WorkspacesNotifier.new,
    );

class WorkspacesNotifier extends AsyncNotifier<List<Workspace>> {
  SupabaseService get _db => ref.read(supabaseServiceProvider);

  @override
  Future<List<Workspace>> build() => _db.getWorkspaces();

  Future<void> create(String name, String description) async {
    state = const AsyncLoading();
    try {
      await _db.createWorkspace(name, description);
      state = AsyncData(await _db.getWorkspaces());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> delete(String id) async {
    state = const AsyncLoading();
    try {
      await _db.deleteWorkspace(id);
      state = AsyncData(await _db.getWorkspaces());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    try {
      state = AsyncData(await _db.getWorkspaces());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> rename(String id, String name, String description) async {
    try {
      await _db.renameWorkspace(id, name, description);
      state = AsyncData(await _db.getWorkspaces());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

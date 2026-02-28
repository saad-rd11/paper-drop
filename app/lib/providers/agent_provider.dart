import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/generated_paper.dart';
import '../services/supabase_service.dart';
import '../services/api_service.dart';
import 'workspace_provider.dart';
import 'document_provider.dart';

class AgentState {
  final Map<String, dynamic>? analysis;
  final List<GeneratedPaper> papers;
  final bool isAnalyzing;
  final bool isGenerating;
  final String? error;

  const AgentState({
    this.analysis,
    this.papers = const [],
    this.isAnalyzing = false,
    this.isGenerating = false,
    this.error,
  });

  AgentState copyWith({
    Map<String, dynamic>? analysis,
    List<GeneratedPaper>? papers,
    bool? isAnalyzing,
    bool? isGenerating,
    String? error,
  }) {
    return AgentState(
      analysis: analysis ?? this.analysis,
      papers: papers ?? this.papers,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
    );
  }
}

final agentProvider =
    AsyncNotifierProvider.family<AgentNotifier, AgentState, String>(
      AgentNotifier.new,
    );

class AgentNotifier extends FamilyAsyncNotifier<AgentState, String> {
  SupabaseService get _db => ref.read(supabaseServiceProvider);
  ApiService get _api => ref.read(apiServiceProvider);

  @override
  Future<AgentState> build(String workspaceId) async {
    final papers = await _db.getGeneratedPapers(workspaceId);
    return AgentState(papers: papers);
  }

  Future<void> analyze() async {
    final current = state.valueOrNull ?? const AgentState();
    state = AsyncData(current.copyWith(isAnalyzing: true, error: null));

    try {
      final result = await _api.analyzePastPapers(workspaceId: arg);
      final analysis = result['analysis'] as Map<String, dynamic>;
      state = AsyncData(
        current.copyWith(analysis: analysis, isAnalyzing: false),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(isAnalyzing: false, error: e.toString()),
      );
    }
  }

  Future<void> generate() async {
    final current = state.valueOrNull ?? const AgentState();
    if (current.analysis == null) return;

    state = AsyncData(current.copyWith(isGenerating: true, error: null));

    try {
      await _api.generatePaper(workspaceId: arg, analysis: current.analysis!);
      final papers = await _db.getGeneratedPapers(arg);
      state = AsyncData(current.copyWith(papers: papers, isGenerating: false));
    } catch (e) {
      state = AsyncData(
        current.copyWith(isGenerating: false, error: e.toString()),
      );
    }
  }
}

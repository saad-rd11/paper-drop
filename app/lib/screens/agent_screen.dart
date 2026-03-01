import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/agent_provider.dart';

class AgentScreen extends ConsumerWidget {
  final String workspaceId;
  const AgentScreen({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentState = ref.watch(agentProvider(workspaceId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return agentState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Error loading agent', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('$e', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      data: (state) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Analysis Section ─────────────────────────
            _SectionCard(
              title: 'Analyze Past Papers',
              subtitle: 'Identify patterns, topics, and question styles',
              icon: Icons.analytics_outlined,
              child: Column(
                children: [
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        state.error!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: state.isAnalyzing
                          ? null
                          : () => ref
                                .read(agentProvider(workspaceId).notifier)
                                .analyze(),
                      icon: state.isAnalyzing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(
                        state.isAnalyzing
                            ? 'Analyzing...'
                            : 'Analyze Past Papers',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Analysis Results ─────────────────────────
            if (state.analysis != null) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Analysis Results',
                icon: Icons.insights,
                child: _AnalysisView(analysis: state.analysis!),
              ),

              // ── Generate Section ─────────────────────────
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Generate Practice Paper',
                subtitle: 'Create a new paper based on past patterns',
                icon: Icons.auto_awesome,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.isGenerating
                        ? null
                        : () => ref
                              .read(agentProvider(workspaceId).notifier)
                              .generate(),
                    icon: state.isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.description),
                    label: Text(
                      state.isGenerating ? 'Generating...' : 'Generate Paper',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ],

            // ── Generated Papers ─────────────────────────
            if (state.papers.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Generated Papers',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...state.papers.map(
                (paper) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(
                      paper.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      _formatDate(paper.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: MarkdownBody(data: paper.content),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── Empty State ──────────────────────────────
            if (state.analysis == null && state.papers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 48,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(
                          0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Upload past papers and tap Analyze\nto discover patterns',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Reusable section card ──────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Analysis results display ───────────────────────────────

class _AnalysisView extends StatelessWidget {
  final Map<String, dynamic> analysis;
  const _AnalysisView({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis['total_marks'] != null)
          _row('Total Marks', '${analysis['total_marks']}'),
        if (analysis['duration'] != null)
          _row('Duration', '${analysis['duration']}'),
        if (analysis['topic_frequency'] is Map) ...[
          const SizedBox(height: 12),
          const Text(
            'Topic Frequency',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: (analysis['topic_frequency'] as Map).entries
                .map(
                  (e) => Chip(
                    label: Text(
                      '${e.key}: ${e.value}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                  ),
                )
                .toList(),
          ),
        ],
        if (analysis['recurring_patterns'] is List) ...[
          const SizedBox(height: 12),
          const Text(
            'Recurring Patterns',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          ...(analysis['recurring_patterns'] as List).map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('  - ', style: TextStyle(color: colorScheme.primary)),
                  Expanded(
                    child: Text('$p', style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String value) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(color: theme.textTheme.bodySmall?.color),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}

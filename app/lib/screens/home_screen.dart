import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workspace.dart';
import '../providers/workspace_provider.dart';
import '../providers/document_provider.dart';
import '../providers/agent_provider.dart';
import '../widgets/workspace_card.dart';
import '../widgets/workspace_grid_card.dart';
import '../widgets/logo.dart';
import '../screens/settings_screen.dart';
import '../utils/page_transitions.dart';

// View mode provider
final viewModeProvider = StateProvider<bool>(
  (ref) => true,
); // true = grid, false = list

// Search query provider
final searchQueryProvider = StateProvider<String>((ref) => '');

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaces = ref.watch(workspacesProvider);
    final isGridView = ref.watch(viewModeProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: workspaces.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading workspaces',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('$e', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        data: (list) {
          // Filter workspaces by search query
          final filteredList = searchQuery.isEmpty
              ? list
              : list
                    .where(
                      (w) =>
                          w.name.toLowerCase().contains(
                            searchQuery.toLowerCase(),
                          ) ||
                          w.description.toLowerCase().contains(
                            searchQuery.toLowerCase(),
                          ),
                    )
                    .toList();

          return CustomScrollView(
            slivers: [
              // App Bar with logo
              SliverAppBar(
                floating: true,
                pinned: true,
                expandedHeight: 80,
                collapsedHeight: 60,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: const PaperDropLogo(size: 32),
                  centerTitle: false,
                ),
                actions: [
                  IconButton(
                    icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
                    onPressed: () {
                      ref.read(viewModeProvider.notifier).state = !isGridView;
                    },
                    tooltip: isGridView ? 'List view' : 'Grid view',
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    tooltip: 'Settings',
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: TextField(
                    onChanged: (value) {
                      ref.read(searchQueryProvider.notifier).state = value;
                    },
                    decoration: InputDecoration(
                      hintText: 'Search workspaces...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                ref.read(searchQueryProvider.notifier).state =
                                    '';
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),

              // Stats summary
              if (list.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _StatCard(
                          icon: Icons.workspaces_outlined,
                          label: 'Workspaces',
                          value: '${list.length}',
                          theme: theme,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.description_outlined,
                          label: 'Total Docs',
                          value:
                              '${list.length * 3}', // Placeholder, will calculate actual
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Workspaces grid/list
              if (filteredList.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          searchQuery.isEmpty
                              ? Icons.workspaces_outlined
                              : Icons.search_off,
                          size: 64,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isEmpty
                              ? 'No workspaces yet'
                              : 'No workspaces found',
                          style: TextStyle(
                            fontSize: 18,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isEmpty
                              ? 'Tap + to create your first workspace'
                              : 'Try a different search term',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isGridView)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final workspace = filteredList[index];
                      return _WorkspaceCardWrapper(
                        workspace: workspace,
                        isGrid: true,
                      );
                    }, childCount: filteredList.length),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final workspace = filteredList[index];
                      return _WorkspaceCardWrapper(
                        workspace: workspace,
                        isGrid: false,
                      );
                    }, childCount: filteredList.length),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Workspace'),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Data Structures Final',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add a brief description...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              ref
                  .read(workspacesProvider.notifier)
                  .create(name, descCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Wrapper to handle workspace stats and actions
class _WorkspaceCardWrapper extends ConsumerWidget {
  final Workspace workspace;
  final bool isGrid;

  const _WorkspaceCardWrapper({required this.workspace, required this.isGrid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get document counts for this workspace
    final documentsAsync = ref.watch(documentsProvider(workspace.id));
    final agentAsync = ref.watch(agentProvider(workspace.id));

    int docCount = 0;
    int pastPaperCount = 0;
    int generatedCount = 0;

    documentsAsync.whenData((docs) {
      docCount = docs.length;
      pastPaperCount = docs.where((d) => d.isPastPaper).length;
    });

    agentAsync.whenData((state) {
      generatedCount = state.papers.length;
    });

    if (isGrid) {
      return WorkspaceGridCard(
        workspace: workspace,
        documentCount: docCount,
        pastPaperCount: pastPaperCount,
        generatedPaperCount: generatedCount,
        onRename: () => _showRenameDialog(context, ref),
        onDelete: () =>
            _showDeleteDialog(context, ref, docCount, generatedCount),
      );
    } else {
      return WorkspaceCard(
        workspace: workspace,
        onRename: () => _showRenameDialog(context, ref),
        onDelete: () =>
            _showDeleteDialog(context, ref, docCount, generatedCount),
      );
    }
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController(text: workspace.name);
    final descCtrl = TextEditingController(text: workspace.description);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              ref
                  .read(workspacesProvider.notifier)
                  .rename(workspace.id, name, descCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    int docCount,
    int generatedCount,
  ) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: theme.colorScheme.error,
          size: 48,
        ),
        title: Text('Delete "${workspace.name}"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will permanently delete:'),
            const SizedBox(height: 12),
            if (docCount > 0)
              _DeleteItem(
                text: '$docCount document${docCount == 1 ? '' : 's'}',
              ),
            if (generatedCount > 0)
              _DeleteItem(
                text:
                    '$generatedCount generated paper${generatedCount == 1 ? '' : 's'}',
              ),
            const _DeleteItem(text: 'All chat history'),
            const SizedBox(height: 16),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(workspacesProvider.notifier).delete(workspace.id);
              Navigator.pop(ctx);

              // Show undo snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${workspace.name}" deleted'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () {
                      // Recreate the workspace
                      ref
                          .read(workspacesProvider.notifier)
                          .create(workspace.name, workspace.description);
                    },
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DeleteItem extends StatelessWidget {
  final String text;

  const _DeleteItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

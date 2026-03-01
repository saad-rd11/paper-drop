import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workspace.dart';
import '../screens/workspace_screen.dart';

class WorkspaceGridCard extends ConsumerStatefulWidget {
  final Workspace workspace;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final int documentCount;
  final int pastPaperCount;
  final int generatedPaperCount;

  const WorkspaceGridCard({
    super.key,
    required this.workspace,
    this.onDelete,
    this.onRename,
    this.documentCount = 0,
    this.pastPaperCount = 0,
    this.generatedPaperCount = 0,
  });

  @override
  ConsumerState<WorkspaceGridCard> createState() => _WorkspaceGridCardState();
}

class _WorkspaceGridCardState extends ConsumerState<WorkspaceGridCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkspaceScreen(workspace: widget.workspace),
            ),
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surface.withOpacity(0.8),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Animated background glow
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    top: _isHovered ? -50 : -100,
                    right: _isHovered ? -30 : -50,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _isHovered ? 150 : 100,
                      height: _isHovered ? 150 : 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            colorScheme.primary.withOpacity(
                              _isHovered ? 0.3 : 0.1,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with icon and menu
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.folder_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const Spacer(),
                            _buildPopupMenu(),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Title
                        Text(
                          widget.workspace.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        if (widget.workspace.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.workspace.description,
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        const Spacer(),

                        // Stats chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _StatChip(
                              icon: Icons.description_outlined,
                              label: '${widget.documentCount}',
                              theme: theme,
                            ),
                            if (widget.pastPaperCount > 0)
                              _StatChip(
                                icon: Icons.history_edu,
                                label: '${widget.pastPaperCount}',
                                theme: theme,
                                isHighlighted: true,
                              ),
                            if (widget.generatedPaperCount > 0)
                              _StatChip(
                                icon: Icons.auto_awesome,
                                label: '${widget.generatedPaperCount}',
                                theme: theme,
                                isHighlighted: true,
                              ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Date
                        Text(
                          _formatDate(widget.workspace.createdAt),
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu() {
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
        onSelected: (value) {
          switch (value) {
            case 'open':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkspaceScreen(workspace: widget.workspace),
                ),
              );
              break;
            case 'rename':
              widget.onRename?.call();
              break;
            case 'delete':
              widget.onDelete?.call();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'open',
            child: Row(
              children: [
                Icon(Icons.open_in_new, size: 18),
                SizedBox(width: 8),
                Text('Open'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'rename',
            child: Row(
              children: [
                Icon(Icons.edit, size: 18),
                SizedBox(width: 8),
                Text('Rename'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;
  final bool isHighlighted;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.theme,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlighted
            ? theme.colorScheme.primary.withOpacity(0.15)
            : theme.colorScheme.surfaceContainerHighest?.withOpacity(0.5) ??
                  theme.colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isHighlighted
                ? theme.colorScheme.primary
                : theme.textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isHighlighted
                  ? theme.colorScheme.primary
                  : theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

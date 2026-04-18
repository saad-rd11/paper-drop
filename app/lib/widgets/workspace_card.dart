import 'package:flutter/material.dart';
import '../models/workspace.dart';
import '../screens/workspace_screen.dart';

class WorkspaceCard extends StatefulWidget {
  final Workspace workspace;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;

  const WorkspaceCard({
    super.key,
    required this.workspace,
    this.onDelete,
    this.onRename,
  });

  @override
  State<WorkspaceCard> createState() => _WorkspaceCardState();
}

class _WorkspaceCardState extends State<WorkspaceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animController.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScaleTransition(
      scale: _scaleAnim,
      child: Hero(
        tag: 'workspace_hero_${widget.workspace.id}',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isPressed
                ? []
                : [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: _isPressed
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surface,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) =>
                      WorkspaceScreen(workspace: widget.workspace),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              ),
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                _isPressed
                                    ? theme.colorScheme.primary.withOpacity(0.7)
                                    : theme.colorScheme.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.folder_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.workspace.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              if (widget.workspace.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.workspace.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(widget.workspace.createdAt),
                                style: TextStyle(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _AnimatedPopupMenu(
                          onRename: widget.onRename,
                          onDelete: widget.onDelete,
                          workspace: widget.workspace,
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

class _AnimatedPopupMenu extends StatefulWidget {
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final Workspace workspace;

  const _AnimatedPopupMenu({
    required this.onRename,
    required this.onDelete,
    required this.workspace,
  });

  @override
  State<_AnimatedPopupMenu> createState() => _AnimatedPopupMenuState();
}

class _AnimatedPopupMenuState extends State<_AnimatedPopupMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _menuController;
  bool _showMenu = false;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: AnimatedRotation(
            turns: _showMenu ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.more_vert),
          ),
          onPressed: () {
            setState(() {
              _showMenu = !_showMenu;
              if (_showMenu) {
                _menuController.forward();
              } else {
                _menuController.reverse();
              }
            });
          },
        ),
        if (_showMenu)
          Positioned(
            right: 0,
            top: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 140,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MenuItem(
                    icon: Icons.open_in_new,
                    label: 'Open',
                    onTap: () {
                      setState(() => _showMenu = false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              WorkspaceScreen(workspace: widget.workspace),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.edit,
                    label: 'Rename',
                    onTap: () {
                      setState(() => _showMenu = false);
                      widget.onRename?.call();
                    },
                  ),
                  _MenuItem(
                    icon: Icons.delete,
                    label: 'Delete',
                    color: Colors.red,
                    onTap: () {
                      setState(() => _showMenu = false);
                      widget.onDelete?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

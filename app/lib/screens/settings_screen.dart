import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          _SectionHeader(title: 'Account', theme: theme),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: const Text('Email'),
                  subtitle: Text(user?.email ?? 'Not signed in'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.logout, color: Colors.red),
                  ),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('Log out of your account'),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text(
                          'Are you sure you want to sign out?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(authProvider.notifier).signOut();
                      if (context.mounted) {
                        // Pop back to root — AuthGate will redirect to login
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Appearance Section
          _SectionHeader(title: 'Appearance', theme: theme),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: const Text('Theme'),
                  subtitle: Text(isDark ? 'Dark mode' : 'Light mode'),
                  trailing: Switch.adaptive(
                    value: isDark,
                    onChanged: (_) {
                      ref.read(themeProvider.notifier).toggleTheme();
                    },
                    activeColor: theme.colorScheme.primary,
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.palette_outlined,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  title: const Text('Accent Color'),
                  subtitle: const Text('Purple (default)'),
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C63FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About Section
          _SectionHeader(title: 'About', theme: theme),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline, color: Colors.blue),
                  ),
                  title: const Text('Version'),
                  subtitle: const Text('1.0.0'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Colors.green,
                    ),
                  ),
                  title: const Text('PaperDrop'),
                  subtitle: const Text(
                    'Chat with your PDFs, generate practice papers',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
        letterSpacing: 1.2,
      ),
    );
  }
}

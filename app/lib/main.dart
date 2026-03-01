import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: PaperDropApp()));
}

class PaperDropApp extends ConsumerWidget {
  const PaperDropApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'PaperDrop',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      home: const _AuthGate(),
    );
  }
}

/// Redirects to LoginScreen or HomeScreen based on auth state.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const LoginScreen(),
      data: (user) {
        if (user == null) return const LoginScreen();
        return const HomeScreen();
      },
    );
  }
}

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth state: null means not authenticated, non-null means logged in.
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((
  ref,
) {
  return AuthNotifier();
});

/// Convenience provider for current user ID (or null).
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).valueOrNull?.id;
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  StreamSubscription<AuthState>? _sub;

  AuthNotifier() : super(const AsyncLoading()) {
    // Seed with current session
    final session = Supabase.instance.client.auth.currentSession;
    state = AsyncData(session?.user);

    // Listen for auth changes (login, logout, token refresh)
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      state = AsyncData(data.session?.user);
    });
  }

  /// Test-only constructor — does not touch Supabase.
  AuthNotifier.test() : super(const AsyncData(null));

  SupabaseClient get _client => Supabase.instance.client;

  /// Returned by [signUp] when the account was created but email
  /// confirmation is required before the user can sign in.
  static const emailConfirmationRequired = '__email_confirmation_required__';

  /// Sign up with email + password.
  ///
  /// Returns:
  ///  - `null` → signed up **and** logged in (no confirmation needed).
  ///  - [emailConfirmationRequired] → account created, confirmation email sent.
  ///  - Any other `String` → error message.
  Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      if (res.user == null) {
        return 'Sign-up failed. Please try again.';
      }
      // Supabase returns a user but no session when email confirmation is
      // enabled in the project dashboard.
      if (res.session == null) {
        return emailConfirmationRequired;
      }
      return null; // success – session is active
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with email + password.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../widgets/logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = ref.read(authProvider.notifier);
    final String? error;

    if (_isSignUp) {
      error = await auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      error = await auth.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (mounted) {
      // Handle email confirmation required (sign-up succeeded, email sent)
      if (error == AuthNotifier.emailConfirmationRequired) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
        _showEmailConfirmationDialog();
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }

  void _showEmailConfirmationDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          Icons.mark_email_read_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        title: const Text('Check your email'),
        content: Text(
          'We\'ve sent a confirmation link to '
          '${_emailController.text.trim()}. '
          'Please verify your email address, then come back and sign in.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _isSignUp = false; // switch to sign-in mode
                _errorMessage = null;
              });
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F0F19),
                    const Color(0xFF1A1035),
                    const Color(0xFF0F0F19),
                  ]
                : [
                    const Color(0xFFF0EDFF),
                    const Color(0xFFE8E0FF),
                    const Color(0xFFF8F9FA),
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: size.width > 500 ? 420 : double.infinity,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Logo + Welcome ──
                        const PaperDropLogo(size: 64),
                        const SizedBox(height: 16),
                        Text(
                          _isSignUp ? 'Create your account' : 'Welcome back',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSignUp
                              ? 'Sign up to start chatting with your PDFs'
                              : 'Sign in to continue to PaperDrop',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // ── Form Card ──
                        Card(
                          elevation: isDark ? 0 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: isDark
                                ? BorderSide(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.15),
                                  )
                                : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Email
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(Icons.email_outlined),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Email is required';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Password
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                        onPressed: () => setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        }),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Password is required';
                                      }
                                      if (value.length < 6) {
                                        return 'At least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),

                                  // Error message
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 24),

                                  // Submit button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: FilledButton(
                                      onPressed: _isLoading ? null : _submit,
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              _isSignUp
                                                  ? 'Create Account'
                                                  : 'Sign In',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Toggle sign-in / sign-up ──
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _isSignUp
                                  ? 'Already have an account?'
                                  : "Don't have an account?",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _isSignUp = !_isSignUp;
                                        _errorMessage = null;
                                      });
                                    },
                              child: Text(
                                _isSignUp ? 'Sign In' : 'Sign Up',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

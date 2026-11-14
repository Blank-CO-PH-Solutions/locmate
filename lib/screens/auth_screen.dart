import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'legal_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

/// Google sign-in returns through a custom URL scheme. Android, iOS and macOS
/// register it; Linux and Windows desktop builds use email sign-in only.
bool get googleSignInSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

class _AuthScreenState extends State<AuthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _creatingAccount = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openLegal(LegalDocument.terms);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openLegal(LegalDocument.privacy);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openLegal(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalScreen(document: document)),
    );
  }

  void _switchMode(bool creating) {
    if (_busy || creating == _creatingAccount) return;
    setState(() {
      _creatingAccount = creating;
      _error = null;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final state = context.read<AppState>();
    try {
      if (_creatingAccount) {
        final signedIn = await state.signUp(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!signedIn && mounted) {
          setState(() => _creatingAccount = false);
          _passwordController.clear();
          await _showConfirmationDialog();
        }
      } else {
        await state.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens the browser for Google sign-in. The session comes back through the
  /// login-callback deep link and AppState's auth listener picks it up.
  Future<void> _signInWithGoogle() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final opened = await context.read<AppState>().signInWithGoogle();
      if (!opened && mounted) {
        setState(
          () => _error = 'Could not open the browser for Google sign-in.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showConfirmationDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_rounded, size: 30),
        title: const Text('Confirm your email'),
        content: Text(
          'We sent a confirmation link to ${_emailController.text.trim()}. '
          'Open it, then return to Locmate and sign in. If the page after the '
          'link does not load, the email is still confirmed.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F0D16)
          : LocmateColors.background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 330,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [LocmateColors.primaryDeep, LocmateColors.primary],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LocmateLogo(size: 62, showShadow: false),
                      const Spacer(),
                      const Text(
                        'Stay close,\nwherever life takes you.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Share your live location with the people who matter.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 282, 18, 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2A2536)
                        : LocmateColors.line,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.1,
                      ),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _creatingAccount
                            ? 'Create your account'
                            : 'Welcome back',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _creatingAccount
                            ? 'One account keeps your circle in sync.'
                            : 'Sign in to see your circle on the map.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_creatingAccount) ...[
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          validator: Validators.name,
                          decoration: const InputDecoration(
                            hintText: 'Full name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        validator: Validators.email,
                        decoration: const InputDecoration(
                          hintText: 'Email address',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: _creatingAccount
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        validator: Validators.password,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        ErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _creatingAccount ? 'Create account' : 'Sign in',
                              ),
                      ),
                      if (googleSignInSupported) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _signInWithGoogle,
                          icon: const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          label: const Text('Continue with Google'),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _switchMode(!_creatingAccount),
                        child: Text(
                          _creatingAccount
                              ? 'Already have an account? Sign in'
                              : 'New here? Create an account',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          text: 'By continuing, you agree to our ',
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: scheme.primary,
                              ),
                              recognizer: _termsRecognizer,
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: scheme.primary,
                              ),
                              recognizer: _privacyRecognizer,
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

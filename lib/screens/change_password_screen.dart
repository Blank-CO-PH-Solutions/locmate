import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils.dart';
import '../widgets/common.dart';

/// Lets the signed-in user replace their password.
///
/// [forced] is used right after signing in with a temporary password: there is
/// no back button and the rest of the app stays blocked until the change
/// succeeds. The optional mode is opened from Settings.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = true});

  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().changePassword(_passwordController.text);
      if (!mounted) return;
      if (widget.forced) {
        // App routing moves on as soon as the flag clears.
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Password updated.')));
      Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: Validators.password,
            decoration: InputDecoration(
              hintText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirm your new password.';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Confirm new password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.forced
                ? 'Use at least 8 characters. This replaces your temporary password.'
                : 'Use at least 8 characters.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: scheme.onSurfaceVariant,
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
                : const Text('Update password'),
          ),
        ],
      ),
    );

    if (!widget.forced) {
      return Scaffold(
        appBar: AppBar(title: const Text('Change password')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: form,
          ),
        ),
      );
    }

    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LocmateLogo(size: 64),
                  const SizedBox(height: 22),
                  Text(
                    'Choose a new password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.userEmail == null
                        ? 'Your account still uses a temporary password.'
                        : '${state.userEmail} still uses a temporary password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SurfaceCard(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: form,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => context.read<AppState>().signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

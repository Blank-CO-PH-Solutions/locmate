import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

enum _SetupMode { create, join }

class CircleSetupScreen extends StatefulWidget {
  const CircleSetupScreen({super.key});

  @override
  State<CircleSetupScreen> createState() => _CircleSetupScreenState();
}

class _CircleSetupScreenState extends State<CircleSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  _SetupMode _mode = _SetupMode.create;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _changeMode(_SetupMode mode) {
    if (_busy || mode == _mode) return;
    setState(() {
      _mode = mode;
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

    try {
      final state = context.read<AppState>();
      if (_mode == _SetupMode.create) {
        await state.createCircle(_nameController.text);
      } else {
        await state.joinCircle(_codeController.text);
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppState>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = state.profile;
    final displayName = profile?.displayName ?? 'there';
    final color = LocmateColors.memberPalette[
        (profile?.colorIndex ?? 0) % LocmateColors.memberPalette.length];
    final initials = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            Row(
              children: [
                const LocmateLogo(size: 42),
                const Spacer(),
                IconButton(
                  onPressed: _busy ? null : _signOut,
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Hi, ${displayName.split(RegExp(r'\s+')).first}',
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a circle for your people or join one with an invite code.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF231C36), const Color(0xFF191622)]
                      : [const Color(0xFFF0EBFF), Colors.white],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? const Color(0xFF332B47) : LocmateColors.line,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? 'Your profile',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Signed in as ${state.userEmail ?? 'your account'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SegmentedButton<_SetupMode>(
              segments: const [
                ButtonSegment(
                  value: _SetupMode.create,
                  label: Text('Create'),
                  icon: Icon(Icons.add_circle_outline_rounded, size: 18),
                ),
                ButtonSegment(
                  value: _SetupMode.join,
                  label: Text('Join'),
                  icon: Icon(Icons.group_add_outlined, size: 18),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) => _changeMode(selection.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF2A2536) : LocmateColors.line,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _mode == _SetupMode.create
                          ? 'Name your circle'
                          : 'Enter an invite code',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mode == _SetupMode.create
                          ? 'You will be the owner and can invite everyone.'
                          : 'Ask the circle owner for the six character code.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_mode == _SetupMode.create)
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: Validators.circleName,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Our family',
                          prefixIcon: Icon(Icons.family_restroom_rounded),
                        ),
                      )
                    else
                      TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        maxLength: 6,
                        onFieldSubmitted: (_) => _submit(),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp('[A-Za-z0-9]'),
                          ),
                          UpperCaseTextFormatter(),
                        ],
                        validator: Validators.inviteCode,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 5,
                        ),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          hintText: 'ABC123',
                          counterText: '',
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _mode == _SetupMode.create
                                  ? Icons.arrow_forward_rounded
                                  : Icons.login_rounded,
                              size: 19,
                            ),
                      label: Text(
                        _mode == _SetupMode.create
                            ? 'Create my circle'
                            : 'Join this circle',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Only people in your circle can see your live location, '
                    'places and messages. You can pause sharing at any time.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.45,
                      color: scheme.onSurfaceVariant,
                    ),
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

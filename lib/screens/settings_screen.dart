import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/member.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/member_avatar.dart';
import 'change_password_screen.dart';
import 'legal_screen.dart';
import 'subscription_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final me = state.currentUserOrNull;
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const ScreenHeader(
              title: 'Settings',
              subtitle: 'Your profile and circle preferences',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SurfaceCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        MemberAvatar(member: me, size: 58),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                me.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                state.userEmail ?? 'Signed in',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      me.isOwner ? 'Owner' : 'Member',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      state.sharingEnabled
                                          ? 'Sharing location'
                                          : 'Sharing paused',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _showRenameDialog(context, state),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                  ),
                  const SectionLabel('Invite your circle'),
                  SurfaceCard(
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.group_add_rounded,
                            size: 21,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.circleName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text.rich(
                                TextSpan(
                                  text: 'Code  ',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: state.inviteCode,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.6,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _copyInvite(context, state),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copy'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SectionLabel('Plan'),
                  _SettingsGroup(
                    children: [
                      _ActionTile(
                        icon: state.trialActive
                            ? Icons.hourglass_bottom_rounded
                            : Icons.workspace_premium_rounded,
                        title: state.trialActive
                            ? 'Premium trial'
                            : state.circlePremium
                            ? 'Locmate Premium'
                            : 'Upgrade to Premium',
                        subtitle: state.trialActive
                            ? '${state.trialDaysLeft} days left · Upgrade to keep Premium'
                            : state.circlePremium
                            ? 'Active for ${state.circleName}'
                            : 'Unlimited members, places and low-battery alerts',
                        onTap: () => _openPremium(context),
                      ),
                      _InfoTile(
                        icon: Icons.groups_outlined,
                        title: 'Circle members',
                        trailing: state.memberLimit == null
                            ? '${state.members.length} · Unlimited'
                            : '${state.members.length} of ${state.memberLimit} on Free',
                      ),
                      _InfoTile(
                        icon: Icons.place_outlined,
                        title: 'Places',
                        trailing: state.placeLimit == null
                            ? '${state.places.length} · Unlimited'
                            : '${state.places.length} of ${state.placeLimit} on Free',
                      ),
                    ],
                  ),
                  const SectionLabel('Privacy & location'),
                  _SettingsGroup(
                    children: [
                      _ToggleTile(
                        icon: Icons.share_location_rounded,
                        title: 'Share my location',
                        subtitle: state.sharingEnabled
                            ? state.backgroundLocationLimited
                                  ? 'Only while the app is open: allow "Always" in iOS Settings'
                                  : 'Visible to your circle, even in the background'
                            : 'Your position is hidden from the circle',
                        value: state.sharingEnabled,
                        onChanged: (_) => state.toggleSharing(),
                      ),
                      _ToggleTile(
                        icon: Icons.battery_saver_rounded,
                        title: 'Battery saver',
                        subtitle: 'Fewer GPS updates, slightly less accuracy',
                        value: state.batterySaver,
                        onChanged: state.setBatterySaver,
                      ),
                      _LocationTile(state: state),
                    ],
                  ),
                  const SectionLabel('Appearance'),
                  _SettingsGroup(
                    children: [
                      _ToggleTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Dark mode',
                        subtitle: 'Easier on the eyes at night',
                        value: state.darkMode,
                        onChanged: state.setDarkMode,
                      ),
                      if (!MapsConfig.usesEmbeddedMap)
                        _ToggleTile(
                          icon: Icons.layers_outlined,
                          title: 'Dark map style',
                          subtitle: 'Use the dark OpenStreetMap tiles',
                          value: state.mapDark,
                          onChanged: (_) => state.toggleMapDark(),
                        ),
                    ],
                  ),
                  const SectionLabel('Circle members'),
                  _SettingsGroup(
                    children: [
                      for (final member in state.members)
                        _MemberTile(
                          member: member,
                          isLast: member == state.members.last,
                        ),
                    ],
                  ),
                  const SectionLabel('Legal'),
                  _SettingsGroup(
                    children: [
                      _ActionTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'How Locmate handles your data',
                        onTap: () => _openLegal(context, LegalDocument.privacy),
                      ),
                      _ActionTile(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        subtitle: 'The agreement for using Locmate',
                        onTap: () => _openLegal(context, LegalDocument.terms),
                      ),
                    ],
                  ),
                  const SectionLabel('Account'),
                  _SettingsGroup(
                    children: [
                      _ActionTile(
                        icon: Icons.password_rounded,
                        title: 'Change password',
                        subtitle: 'Update the password you use to sign in',
                        onTap: () => _openChangePassword(context),
                      ),
                      _ActionTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign out',
                        subtitle: 'Sign back in at any time',
                        onTap: () => _confirmSignOut(context, state),
                      ),
                      _ActionTile(
                        icon: Icons.exit_to_app_rounded,
                        title: 'Leave circle',
                        subtitle: 'Remove yourself from ${state.circleName}',
                        onTap: () => _confirmLeaveCircle(context, state),
                        danger: true,
                      ),
                      _ActionTile(
                        icon: Icons.delete_forever_rounded,
                        title: 'Delete account',
                        subtitle: 'Permanently delete your account and data',
                        onTap: () => _confirmDeleteAccount(context, state),
                        danger: true,
                      ),
                    ],
                  ),
                  const SectionLabel('About'),
                  _SettingsGroup(
                    children: const [
                      _InfoTile(
                        icon: Icons.info_outline_rounded,
                        title: 'Locmate version',
                        trailing: '1.0.0',
                      ),
                      _InfoTile(
                        icon: Icons.map_outlined,
                        title: 'Map data',
                        trailing: 'OpenStreetMap contributors',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Locmate shares your location only with people in your '
                    'circle, including in the background while sharing is on. '
                    'You can pause sharing at any time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    LegalInfo.copyright,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Operated by ${LegalInfo.company}, ${LegalInfo.address}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPremium(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()));
  }

  void _openChangePassword(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ChangePasswordScreen(forced: false),
      ),
    );
  }

  void _openLegal(BuildContext context, LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalScreen(document: document)),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AppState state,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_forever_rounded,
          size: 30,
          color: LocmateColors.danger,
        ),
        title: const Text('Delete your account?'),
        content: Text(
          'This permanently deletes your profile, location, membership, '
          'messages and places. You cannot undo this. If you own '
          '${state.circleName}, another member becomes the owner.\n\n'
          'Your App Store or Google Play subscription must be cancelled '
          'separately in your store account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep my account'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: LocmateColors.danger,
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await state.deleteAccount();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Your account was deleted.')),
        );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  Future<void> _copyInvite(BuildContext context, AppState state) async {
    if (state.inviteCode.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: state.inviteCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Invite code ${state.inviteCode} copied. Share it with your circle.',
          ),
        ),
      );
  }

  Future<void> _showRenameDialog(BuildContext context, AppState state) async {
    final controller = TextEditingController(text: state.currentUser.name);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'Full name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty || !context.mounted) return;
    try {
      await state.renameSelf(result);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Name updated')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  Future<void> _confirmSignOut(BuildContext context, AppState state) async {
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
    if (confirmed != true) return;
    await state.signOut();
  }

  Future<void> _confirmLeaveCircle(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this circle?'),
        content: Text(
          'You will stop sharing your location with ${state.circleName}. '
          'If you are the owner, another member becomes the owner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: LocmateColors.danger,
            ),
            child: const Text('Leave circle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await state.leaveCircle();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(indent: 60, endIndent: 12));
      rows.add(children[i]);
    }
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: rows),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Row(
        children: [
          _SettingIcon(icon: icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = state.locationError != null;
    final color = hasError ? LocmateColors.warning : LocmateColors.safe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Row(
        children: [
          _SettingIcon(icon: Icons.gps_fixed_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location access',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 1),
                Text(
                  state.locationError ??
                      (state.currentUserOrNull?.position != null
                          ? 'Active · updated ${timeAgo(state.currentUserOrNull!.lastUpdated ?? DateTime.now())}'
                          : 'Waiting for the first GPS fix'),
                  style: TextStyle(
                    fontSize: 11,
                    color: hasError
                        ? LocmateColors.warning
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (hasError)
            TextButton(
              onPressed: state.openSystemLocationSettings,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Fix'),
            ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.isLast});

  final Member member;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 8, 14, isLast ? 10 : 8),
      child: Row(
        children: [
          MemberAvatar(member: member, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.isCurrentUser ? '${member.name} (You)' : member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${member.isOwner ? 'Owner' : 'Member'} · '
                  '${member.battery == null ? 'Battery unknown' : '${member.battery!.round()}% battery'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          BatteryBadge(level: member.battery),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          _SettingIcon(icon: icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? LocmateColors.danger : scheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            _SettingIcon(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: danger ? LocmateColors.danger : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

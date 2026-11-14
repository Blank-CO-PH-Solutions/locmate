import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/alert_event.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'subscription_screen.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final alerts = state.alerts;

    final activity = <Widget>[];
    String? currentDay;
    for (final alert in alerts.take(15)) {
      final label = dayLabel(alert.timestamp);
      if (label != currentDay) {
        activity.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6, left: 2),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.3,
              ),
            ),
          ),
        );
        currentDay = label;
      }
      activity.add(_AlertTile(alert: alert));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            ScreenHeader(
              title: 'Safety',
              subtitle: 'Emergency tools and circle activity',
              actions: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SosCard(onSend: () => _confirmSos(context)),
                  const SizedBox(height: 10),
                  _SafeBanner(state: state),
                  if (!state.circlePremium) ...[
                    const SizedBox(height: 10),
                    _PremiumNudge(onTap: () => _openPremium(context)),
                  ],
                  const SizedBox(height: 10),
                  _CircleStatusCard(
                    state: state,
                    onCopyInvite: () => _copyInvite(context),
                  ),
                  const SectionLabel('Activity'),
                  if (activity.isEmpty)
                    const SurfaceCard(
                      child: EmptyState(
                        icon: Icons.history_rounded,
                        title: 'No activity yet',
                        message:
                            'Arrivals, departures and battery alerts show up here.',
                      ),
                    )
                  else
                    ...activity,
                  const SizedBox(height: 16),
                  Text(
                    'SOS alerts are shared with your circle inside Locmate. '
                    'They do not contact emergency services. Call your local '
                    'emergency number if you are in danger.',
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

  Future<void> _copyInvite(BuildContext context) async {
    final code = context.read<AppState>().inviteCode;
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Invite code $code copied')));
  }

  Future<void> _confirmSos(BuildContext context) async {
    final state = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send an SOS alert?'),
        content: Text(
          'Everyone in ${state.circleName} will be notified and can see '
          'your latest shared location.',
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
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await state.sendSos();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('SOS sent to everyone in your circle')),
        );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }
}

class _SosCard extends StatelessWidget {
  const _SosCard({required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C1A63), LocmateColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: LocmateColors.primary.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.health_and_safety_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'EMERGENCY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Send an SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alert everyone in your circle and share your latest '
                  'location instantly.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSend,
              customBorder: const CircleBorder(),
              child: Container(
                width: 82,
                height: 82,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE23B3B),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: LocmateColors.danger.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
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

class _PremiumNudge extends StatelessWidget {
  const _PremiumNudge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      color: scheme.primary.withValues(alpha: 0.06),
      borderColor: scheme.primary.withValues(alpha: 0.16),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Low-battery alerts are included with Premium.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 19,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _SafeBanner extends StatelessWidget {
  const _SafeBanner({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lowBatteryCount = state.lowBatteryCount;
    final alone = state.members.length <= 1;
    final allSharing =
        state.members.isNotEmpty &&
        state.members.every(
          (member) => member.isSharing && member.position != null,
        );
    final healthy = alone ? state.sharingCount > 0 : allSharing;
    final color = healthy ? LocmateColors.safe : LocmateColors.warning;
    final title = alone
        ? 'You’re sharing your location'
        : lowBatteryCount > 0
        ? '$lowBatteryCount member${lowBatteryCount == 1 ? '' : 's'} '
              'need${lowBatteryCount == 1 ? 's' : ''} a charge'
        : allSharing
        ? 'All members are safe'
        : 'Waiting for the full circle';
    final subtitle = alone
        ? 'Invite someone to see each other on the map.'
        : lowBatteryCount > 0
        ? 'Check in with your circle and ask them to charge.'
        : allSharing
        ? 'Everyone has a recent location and enough battery.'
        : 'Some members have not shared a location yet.';

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      color: color.withValues(alpha: isDark ? 0.12 : 0.07),
      borderColor: color.withValues(alpha: 0.25),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              healthy
                  ? Icons.verified_user_rounded
                  : Icons.battery_alert_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${state.sharingCount}/${state.members.length} live',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleStatusCard extends StatelessWidget {
  const _CircleStatusCard({required this.state, required this.onCopyInvite});

  final AppState state;
  final VoidCallback onCopyInvite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paused = state.members
        .where((member) => !member.isSharing)
        .map((member) => member.isCurrentUser ? 'You' : member.firstName)
        .toList();
    final latest = state.members
        .where((member) => member.lastUpdated != null)
        .map((member) => member.lastUpdated!)
        .fold<DateTime?>(null, (latest, time) {
          if (latest == null || time.isAfter(latest)) return time;
          return latest;
        });

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  size: 19,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Circle status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Live overview of ${state.circleName}',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(
                    alpha: isDark ? 0.1 : 0.05,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StatusRow(
            icon: Icons.share_location_rounded,
            label: 'Sharing now',
            value: '${state.sharingCount} of ${state.members.length}',
          ),
          const SizedBox(height: 9),
          _StatusRow(
            icon: Icons.location_off_rounded,
            label: 'Paused',
            value: paused.isEmpty ? 'Nobody' : paused.join(', '),
          ),
          const SizedBox(height: 9),
          _StatusRow(
            icon: Icons.schedule_rounded,
            label: 'Latest update',
            value: latest == null
                ? 'Waiting for the first fix'
                : timeAgo(latest),
          ),
          if (state.members.length <= 1 && state.inviteCode.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.group_add_rounded,
                    size: 17,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Invite code  ${state.inviteCode}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onCopyInvite,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Copy'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final AlertEvent alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = alertColor(alert.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SurfaceCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(alertIcon(alert.type), size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    alert.body,
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
            const SizedBox(width: 8),
            Text(
              timeAgo(alert.timestamp),
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

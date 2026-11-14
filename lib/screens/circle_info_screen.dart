import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/member_avatar.dart';
import 'member_detail_screen.dart';
import 'places_screen.dart';

/// Everything about the circle in one place: name, invite code, members and
/// the circle's places (arrival/departure alerts).
class CircleInfoScreen extends StatelessWidget {
  const CircleInfoScreen({super.key, this.asTab = false});

  /// True when shown as a bottom navigation tab (no back button).
  final bool asTab;

  Future<void> _copyCode(BuildContext context, String code) async {
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Invite code $code copied')),
      );
  }

  void _openMember(BuildContext context, Member member) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberDetailScreen(memberId: member.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final owner = state.members.where((m) => m.isOwner).firstOrNull;
    final sharing = state.members.where((m) => m.isSharing).length;

    return Scaffold(
      appBar: asTab ? null : AppBar(title: const Text('Circle')),
      body: SafeArea(
        top: asTab,
        child: RefreshIndicator(
          onRefresh: state.refreshData,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              if (asTab)
                ScreenHeader(
                  title: 'Circle',
                  subtitle: 'Members, invite code and places',
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SurfaceCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.groups_rounded,
                                  size: 26,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      state.circleName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      owner == null
                                          ? '${state.members.length} members'
                                          : 'Owner: ${owner.isCurrentUser ? 'You' : owner.name}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'INVITE CODE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  state.inviteCode.isEmpty
                                      ? '—'
                                      : state.inviteCode,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 6,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () =>
                                    _copyCode(context, state.inviteCode),
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Copy'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Share this code so family and friends can join '
                            '${state.circleName}.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _Stat(
                                label: 'Members',
                                value: state.memberLimit == null
                                    ? '${state.members.length}'
                                    : '${state.members.length}/${state.memberLimit}',
                              ),
                              _Stat(label: 'Sharing', value: '$sharing'),
                              _Stat(
                                label: 'Places',
                                value: state.placeLimit == null
                                    ? '${state.places.length}'
                                    : '${state.places.length}/${state.placeLimit}',
                              ),
                              _Stat(
                                label: 'Plan',
                                value: state.circlePremium ? 'Premium' : 'Free',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SectionLabel('Members'),
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          for (final member in state.members)
                            ListTile(
                              onTap: () => _openMember(context, member),
                              leading: MemberAvatar(member: member, size: 40),
                              title: Text(
                                member.isCurrentUser
                                    ? '${member.name} (You)'
                                    : member.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${member.isOwner ? 'Owner' : 'Member'} · '
                                '${state.statusFor(member)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: BatteryBadge(level: member.battery),
                            ),
                        ],
                      ),
                    ),
                    const SectionLabel('Places'),
                    const PlacesScreen(embedded: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}


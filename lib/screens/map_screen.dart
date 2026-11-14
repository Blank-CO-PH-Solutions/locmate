import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/place.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/member_avatar.dart';
import 'chat_screen.dart';
import 'member_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _autoCentered = false;

  static const String _tilesUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const LatLng _worldCenter = LatLng(20, 0);

  LatLng? _firstMemberPosition(AppState state) {
    for (final member in state.members) {
      if (member.position != null) return member.position;
    }
    return null;
  }

  LatLng _initialCenter(AppState state) =>
      state.currentUserOrNull?.position ??
      state.lastKnownPosition ??
      _firstMemberPosition(state) ??
      _worldCenter;

  void _focusMember(Member member) {
    context.read<AppState>().selectMember(member.id);
    if (_mapReady && member.position != null) {
      _mapController.move(member.position!, 15.4);
    }
  }

  void _recenter() {
    final state = context.read<AppState>();
    final position = state.currentUserOrNull?.position;
    if (position == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Waiting for your location…')),
        );
      state.refreshMyLocation();
      return;
    }
    if (_mapReady) _mapController.move(position, 15.8);
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
    );
  }

  void _openDetails(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberDetailScreen(memberId: member.id),
      ),
    );
  }

  void _toggleSharing(BuildContext context) {
    final state = context.read<AppState>();
    state.toggleSharing();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            state.sharingEnabled
                ? 'Location sharing resumed'
                : 'Location sharing paused',
          ),
        ),
      );
  }

  Future<void> _copyInviteCode() async {
    final code = context.read<AppState>().inviteCode;
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Invite code $code copied')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = state.selectedMember;
    final mapMembers = [...state.members]
      ..sort((a, b) => a.isCurrentUser == b.isCurrentUser
          ? 0
          : (a.isCurrentUser ? -1 : 1));

    if (!_autoCentered && _mapReady) {
      final position = state.currentUserOrNull?.position;
      if (position != null) {
        _autoCentered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mapController.move(position, 15.6);
        });
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter(state),
              initialZoom: state.currentUserOrNull?.position == null ? 3 : 15,
              minZoom: 2,
              maxZoom: 18,
              onMapReady: () => _mapReady = true,
              onTap: (_, _) => state.selectMember(null),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _tilesUrl,
                userAgentPackageName: 'com.locmate.locmate',
                tileBuilder: state.mapDark ? darkModeTileBuilder : null,
              ),
              MarkerLayer(
                markers: [
                  for (final place in state.places)
                    Marker(
                      point: place.point,
                      width: 36,
                      height: 36,
                      child: _PlaceMarker(place: place),
                    ),
                  for (final member in mapMembers)
                    if (member.position != null)
                      Marker(
                        point: member.position!,
                        width: 88,
                        height: 88,
                        alignment: Alignment.topCenter,
                        child: _MemberMarker(
                          member: member,
                          selected: member.id == selected?.id,
                          onTap: () => _focusMember(member),
                        ),
                      ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _MapHeader(
                state: state,
                onToggleSharing: () => _toggleSharing(context),
              ),
            ),
          ),
          if (state.locationError != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 86,
              left: 14,
              right: 14,
              child: _LocationBanner(
                message: state.locationError!,
                onAction: () => state.openSystemLocationSettings(),
              ),
            ),
          if (state.syncError != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top +
                  (state.locationError != null ? 146 : 86),
              left: 14,
              right: 14,
              child: _SyncErrorBanner(
                message: state.syncError!,
                onRetry: state.refreshData,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _CirclePanel(
                state: state,
                selected: selected,
                onSelect: _focusMember,
                onRecenter: _recenter,
                onOpenChat: _openChat,
                onOpenDetails: _openDetails,
                onCopyInvite: _copyInviteCode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.state,
    required this.onToggleSharing,
  });

  final AppState state;
  final VoidCallback onToggleSharing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sharing = state.sharingEnabled;
    final memberCount = state.members.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2536) : LocmateColors.line,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const LocmateLogo(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.circleName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sharing
                              ? LocmateColors.safe
                              : LocmateColors.warning,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          sharing
                              ? '$memberCount member${memberCount == 1 ? '' : 's'} · '
                                  '${state.sharingCount} sharing'
                              : 'Location sharing paused',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onToggleSharing,
              tooltip: sharing
                  ? 'Pause location sharing'
                  : 'Resume location sharing',
              style: IconButton.styleFrom(
                backgroundColor: sharing
                    ? scheme.primary.withValues(alpha: 0.1)
                    : LocmateColors.warning.withValues(alpha: 0.14),
                padding: const EdgeInsets.all(9),
              ),
              icon: Icon(
                sharing
                    ? Icons.share_location_rounded
                    : Icons.location_disabled_rounded,
                size: 20,
                color: sharing ? scheme.primary : LocmateColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.message, required this.onAction});

  final String message;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            const Icon(
              Icons.location_off_rounded,
              size: 19,
              color: LocmateColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 11.5, height: 1.35),
              ),
            ),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 34),
              ),
              child: const Text('Fix'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncErrorBanner extends StatelessWidget {
  const _SyncErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4F4),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 18,
              color: LocmateColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: LocmateColors.danger,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CirclePanel extends StatelessWidget {
  const _CirclePanel({
    required this.state,
    required this.selected,
    required this.onSelect,
    required this.onRecenter,
    required this.onOpenChat,
    required this.onOpenDetails,
    required this.onCopyInvite,
  });

  final AppState state;
  final Member? selected;
  final ValueChanged<Member> onSelect;
  final VoidCallback onRecenter;
  final VoidCallback onOpenChat;
  final ValueChanged<Member> onOpenDetails;
  final VoidCallback onCopyInvite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alone = state.members.length <= 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2536) : LocmateColors.line,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Circle',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${state.members.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              _MapToolButton(
                icon: Icons.layers_outlined,
                tooltip: state.mapDark ? 'Light map' : 'Dark map',
                onTap: state.toggleMapDark,
              ),
              const SizedBox(width: 6),
              _MapToolButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Recenter on me',
                onTap: onRecenter,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 146,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.members.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final member = state.members[index];
                return _MemberCard(
                  member: member,
                  status: state.statusFor(member),
                  selected: member.id == selected?.id,
                  onTap: () => onSelect(member),
                );
              },
            ),
          ),
          if (alone && state.inviteCode.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InviteRow(
              code: state.inviteCode,
              onCopy: onCopyInvite,
            ),
          ],
          if (selected != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.07),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    selected!.isSharing || selected!.isCurrentUser
                        ? Icons.place_rounded
                        : Icons.location_off_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.statusFor(selected!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          state.locationLabelFor(selected!),
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
                  IconButton(
                    onPressed: onOpenChat,
                    tooltip: 'Message circle',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  FilledButton(
                    onPressed: () => onOpenDetails(selected!),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Details'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Map data © OpenStreetMap contributors',
              style: TextStyle(
                fontSize: 9,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.group_add_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Invite code  ',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: code,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: const Text('Copy'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapToolButton extends StatelessWidget {
  const _MapToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 19, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final Member member;
  final String status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 146,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: isDark ? 0.2 : 0.08)
            : scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.03),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 1.6,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MemberAvatar(member: member, size: 36),
                    const Spacer(),
                    BatteryBadge(level: member.battery),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  member.isCurrentUser
                      ? '${member.firstName} (You)'
                      : member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (member.battery != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (member.battery! / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor:
                          scheme.onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        batteryColor(member.battery!),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberMarker extends StatelessWidget {
  const _MemberMarker({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final Member member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              MemberAvatar(
                member: member,
                size: selected ? 50 : 44,
                showBattery: false,
              ),
              if (member.isCurrentUser)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: const Icon(
                      Icons.near_me_rounded,
                      size: 9,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxWidth: 84),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 7,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              member.isCurrentUser ? 'You' : member.firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceMarker extends StatelessWidget {
  const _PlaceMarker({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = placeColor(place.icon);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(placeIcon(place.icon), size: 18, color: color),
    );
  }
}

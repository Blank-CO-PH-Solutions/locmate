import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/place.dart';
import '../state/app_state.dart';
import 'package:latlong2/latlong.dart';

import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/member_avatar.dart';
import 'member_detail_screen.dart';


/// Live movement view: what every circle member is doing right now —
/// their speed, the direction they are heading, and (when it is clear)
/// which place they are most likely driving toward.
///
/// The "likely destination" is a heuristic: among the circle's places,
/// the one whose bearing from the member best matches their heading
/// (within 60°) while they are moving. There is no turn-by-turn data,
/// so this is a good guess, not a certainty.
class DrivingScreen extends StatelessWidget {
  const DrivingScreen({super.key});

  static const List<String> _compass = [
    'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW',
  ];

  static String _compassLabel(double degrees) =>
      _compass[((degrees % 360) / 45).round() % 8];

  /// Bearing from `from` to `to`, 0–360° with 0 = north.
  static double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static Place? _likelyDestination(Member member, List<Place> places) {
    if (!member.isMoving || member.heading == null) return null;
    Place? best;
    var bestDiff = double.infinity;
    for (final place in places) {
      final bearing = _bearingBetween(member.position!, place.point);
      var diff = (bearing - member.heading!).abs() % 360;
      if (diff > 180) diff = 360 - diff;
      if (diff <= 60 && diff < bestDiff) {
        bestDiff = diff;
        best = place;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.currentUserOrNull;

    final members = [...state.members]..sort((a, b) {
      final byMotion = (b.isMoving ? 1 : 0).compareTo(a.isMoving ? 1 : 0);
      if (byMotion != 0) return byMotion;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const ScreenHeader(
              title: 'Driving',
              subtitle: 'Who is on the move, how fast, and where they are headed',
            ),
            if (members.isEmpty)
              const EmptyState(
                icon: Icons.directions_car_outlined,
                title: 'No members yet',
                message: 'Invite people to your circle to see them on the move.',
              )
            else ...[
              for (final member in members)
                _DrivingCard(
                  member: member,
                  isMe: me != null && member.id == me.id,
                  destination: member.hasLocation
                      ? _likelyDestination(member, state.places)
                      : null,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MemberDetailScreen(memberId: member.id),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrivingCard extends StatelessWidget {
  const _DrivingCard({
    required this.member,
    required this.isMe,
    required this.destination,
    required this.onTap,
  });

  final Member member;
  final bool isMe;
  final Place? destination;
  final VoidCallback onTap;

  IconData get _motionIcon => switch (member.motion) {
    MotionState.driving => Icons.directions_car_rounded,
    MotionState.walking => Icons.directions_walk_rounded,
    MotionState.stationary => Icons.pause_circle_outline_rounded,
  };

  String get _motionLabel => switch (member.motion) {
    MotionState.driving => 'Driving',
    MotionState.walking => 'Walking',
    MotionState.stationary => 'Stationary',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kmh = member.speed * 3.6;

    final subtitle = <String>[
      if (member.isMoving) '${kmh.toStringAsFixed(kmh < 10 ? 1 : 0)} km/h',
      if (member.hasLocation && member.heading != null && member.isMoving)
        'heading ${DrivingScreen._compassLabel(member.heading!)}',
      if (destination != null) '→ ${destination!.name}',
      if (member.lastUpdated != null) timeAgo(member.lastUpdated!),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                MemberAvatar(member: member, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? '${member.firstName} (you)' : member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.hasLocation ? subtitle : 'No location shared yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (member.hasLocation)
                  Column(
                    children: [
                      Transform.rotate(
                        angle: ((member.heading ?? 0) + 180) * math.pi / 180,
                        child: Icon(
                          _motionIcon,
                          size: 22,
                          color: member.isMoving
                              ? scheme.primary
                              : scheme.outline,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _motionLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                else
                  Icon(Icons.location_disabled_outlined, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

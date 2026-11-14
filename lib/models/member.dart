import 'package:material_ui/material_ui.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';

enum MotionState { stationary, walking, driving }

class Member {
  Member({
    required this.id,
    required this.name,
    required this.colorIndex,
    this.isCurrentUser = false,
    this.isOwner = false,
    this.position,
    this.accuracy,
    this.heading,
    this.speed = 0,
    this.battery,
    this.isSharing = true,
    this.lastUpdated,
  });

  final String id;
  String name;
  final int colorIndex;
  final bool isCurrentUser;
  final bool isOwner;

  LatLng? position;
  double? accuracy;
  double? heading;
  double speed;
  double? battery;
  bool isSharing;
  DateTime? lastUpdated;

  Color get color =>
      LocmateColors.memberPalette[colorIndex % LocmateColors.memberPalette.length];

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? name : parts.first;
  }

  MotionState get motion {
    if (speed >= 5.5) return MotionState.driving;
    if (speed >= 0.7) return MotionState.walking;
    return MotionState.stationary;
  }

  bool get isMoving => motion != MotionState.stationary;

  bool get hasLocation => position != null;

  bool get isStale =>
      lastUpdated == null ||
      DateTime.now().difference(lastUpdated!) > const Duration(minutes: 15);
}

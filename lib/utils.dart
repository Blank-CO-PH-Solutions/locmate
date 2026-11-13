import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'models/alert_event.dart';
import 'theme.dart';

const Distance _distance = Distance();

double distanceMeters(LatLng a, LatLng b) =>
    _distance.as(LengthUnit.Meter, a, b);

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 45) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays} d ago';
}

String clockTime(DateTime time) => DateFormat.jm().format(time);

String dayLabel(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat.MMMMEEEEd().format(time);
}

IconData placeIcon(String key) {
  switch (key) {
    case 'home':
      return Icons.home_rounded;
    case 'work':
      return Icons.work_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'gym':
      return Icons.fitness_center_rounded;
    default:
      return Icons.place_rounded;
  }
}

Color placeColor(String key) {
  switch (key) {
    case 'home':
      return LocmateColors.primary;
    case 'work':
      return const Color(0xFF3B82F6);
    case 'school':
      return const Color(0xFFF2994A);
    case 'gym':
      return LocmateColors.safe;
    default:
      return LocmateColors.accent;
  }
}

Color batteryColor(double level) {
  if (level <= 20) return LocmateColors.danger;
  if (level <= 45) return LocmateColors.warning;
  return LocmateColors.safe;
}

IconData batteryIcon(double level) {
  if (level <= 20) return Icons.battery_alert_rounded;
  if (level <= 50) return Icons.battery_3_bar_rounded;
  return Icons.battery_full_rounded;
}

IconData alertIcon(AlertType type) => switch (type) {
      AlertType.arrival => Icons.login_rounded,
      AlertType.departure => Icons.logout_rounded,
      AlertType.sos => Icons.emergency_share_rounded,
      AlertType.battery => Icons.battery_alert_rounded,
      AlertType.speed => Icons.speed_rounded,
      AlertType.info => Icons.info_rounded,
    };

Color alertColor(AlertType type) => switch (type) {
      AlertType.arrival => LocmateColors.safe,
      AlertType.departure => const Color(0xFF3B82F6),
      AlertType.sos => LocmateColors.danger,
      AlertType.battery => LocmateColors.warning,
      AlertType.speed => LocmateColors.accent,
      AlertType.info => LocmateColors.muted,
    };

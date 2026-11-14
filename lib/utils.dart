import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/alert_event.dart';
import 'theme.dart';

const Distance _distance = Distance();

double distanceMeters(LatLng a, LatLng b) =>
    _distance.as(LengthUnit.Meter, a, b);

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String formatCoordinates(LatLng point) =>
    '${point.latitude.toStringAsFixed(4)}, '
    '${point.longitude.toStringAsFixed(4)}';

String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.isNegative || diff.inSeconds < 45) return 'Just now';
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

/// Turns low-level auth/network/database failures into copy that users can act
/// on.
String friendlyError(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'That email and password do not match.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirm your email first, then sign in.';
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return 'An account with that email already exists. Sign in instead.';
    }
    if (message.contains('password')) {
      return error.message;
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    return error.message;
  }
  if (error is PostgrestException) {
    if (error.code == '23505') {
      return 'That invite code is already in use. Create the circle again.';
    }
    return error.message;
  }
  if (error is TimeoutException) {
    return 'Locmate took too long to respond. Check your connection.';
  }
  if (error is FormatException) {
    return 'The server sent an unexpected response. Try again.';
  }
  final raw = error.toString();
  if (raw.contains('SocketException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('Connection refused') ||
      raw.contains('ClientException')) {
    return 'Can’t reach Locmate. Check your internet connection.';
  }
  return raw.replaceFirst('Exception: ', '');
}

class Validators {
  const Validators._();

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _inviteCode = RegExp(r'^[A-Z0-9]{6}$');

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email.';
    if (!_email.hasMatch(text)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter a password.';
    if (text.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your name.';
    if (text.length > 60) return 'Keep your name under 60 characters.';
    return null;
  }

  static String? circleName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Give your circle a name.';
    if (text.length > 60) return 'Keep the name under 60 characters.';
    return null;
  }

  static String? inviteCode(String? value) {
    final text = value?.trim().toUpperCase() ?? '';
    if (text.isEmpty) return 'Enter an invite code.';
    if (!_inviteCode.hasMatch(text)) {
      return 'Invite codes are six letters or numbers.';
    }
    return null;
  }
}

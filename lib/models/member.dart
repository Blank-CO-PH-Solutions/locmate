import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum TravelMode { driving, walking }

enum MotionState { stationary, walking, driving }

class Member {
  Member({
    required this.id,
    required this.name,
    required this.color,
    required this.route,
    required this.travelMode,
    this.isCurrentUser = false,
    this.isOwner = false,
    this.battery = 85,
    this.legIndex = 0,
    this.legT = 0,
    this.dwellTicks = 0,
    this.currentPlaceId,
  }) : position = route[legIndex];

  final String id;
  String name;
  final Color color;
  final bool isCurrentUser;
  final bool isOwner;
  final List<LatLng> route;
  final TravelMode travelMode;

  LatLng position;
  double battery;
  int legIndex;
  double legT;
  int dwellTicks;
  String? currentPlaceId;
  MotionState motion = MotionState.stationary;
  double speedMph = 0;
  DateTime lastUpdated = DateTime.now();
  bool lowBatteryAlerted = false;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String get firstName => name.split(' ').first;

  bool get isMoving => motion != MotionState.stationary;
}

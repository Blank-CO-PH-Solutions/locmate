import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_event.dart';
import '../models/member.dart';
import '../models/message.dart';
import '../models/place.dart';
import '../theme.dart';
import '../utils.dart';

class AppState extends ChangeNotifier {
  static const String circleName = 'Carter Family';
  static const String _settingsKey = 'locmate.settings.v1';
  static const String _placesKey = 'locmate.places.v1';

  final List<Member> _members = [];
  final List<AlertEvent> _alerts = [];
  final List<ChatMessage> _messages = [];
  List<Place> _places = [];

  SharedPreferences? _prefs;
  Timer? _simTimer;
  Timer? _replyTimer;
  final Random _random = Random(360);
  int _tickCount = 0;
  int _messageCounter = 0;
  bool _disposed = false;

  bool isReady = false;
  bool sharingEnabled = true;
  bool notificationsEnabled = true;
  bool batterySaver = false;
  bool darkMode = false;
  bool mapDark = false;
  String? selectedMemberId;
  DateTime circleUpdatedAt = DateTime.now();

  List<Member> get members => List.unmodifiable(_members);
  List<Place> get places => List.unmodifiable(_places);
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  List<AlertEvent> get alerts {
    final copy = [..._alerts];
    copy.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return copy;
  }

  Member get currentUser =>
      _members.firstWhere((member) => member.isCurrentUser);

  Member? get selectedMember => memberById(selectedMemberId);

  Member? memberById(String? id) {
    if (id == null) return null;
    for (final member in _members) {
      if (member.id == id) return member;
    }
    return null;
  }

  Place? placeById(String? id) {
    if (id == null) return null;
    for (final place in _places) {
      if (place.id == id) return place;
    }
    return null;
  }

  Place? placeFor(Member member) => placeById(member.currentPlaceId);

  List<Member> membersAtPlace(Place place) => _members
      .where(
          (member) => distanceMeters(member.position, place.point) <= place.radiusMeters)
      .toList();

  bool isAtPlace(Member member, Place place) =>
      distanceMeters(member.position, place.point) <= place.radiusMeters;

  String statusFor(Member member) {
    final place = placeFor(member);
    if (place != null) return 'At ${place.name}';
    switch (member.motion) {
      case MotionState.driving:
        return 'Driving · ${member.speedMph.round()} mph';
      case MotionState.walking:
        return 'Walking';
      case MotionState.stationary:
        return 'Stationary';
    }
  }

  String locationLabelFor(Member member) {
    final place = placeFor(member);
    if (place != null) return place.address;
    return '${member.position.latitude.toStringAsFixed(4)}, '
        '${member.position.longitude.toStringAsFixed(4)}';
  }

  double distanceToMe(Member member) =>
      distanceMeters(currentUser.position, member.position);

  List<AlertEvent> alertsForMember(String memberId) =>
      alerts.where((alert) => alert.memberId == memberId).toList();

  int get lowBatteryCount =>
      _members.where((member) => member.battery <= 20).length;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final rawSettings = _prefs?.getString(_settingsKey);
    if (rawSettings != null) {
      try {
        final decoded = jsonDecode(rawSettings) as Map<String, dynamic>;
        sharingEnabled = decoded['sharing'] as bool? ?? true;
        notificationsEnabled = decoded['notifications'] as bool? ?? true;
        batterySaver = decoded['batterySaver'] as bool? ?? false;
        darkMode = decoded['darkMode'] as bool? ?? false;
        mapDark = decoded['mapDark'] as bool? ?? false;
      } catch (_) {
        // Ignore malformed settings and fall back to defaults.
      }
    }

    _places = _restorePlaces() ?? _defaultPlaces();
    _seedMembers();
    _seedAlerts();
    _seedMessages();
    _syncInitialPlaces();

    isReady = true;
    circleUpdatedAt = DateTime.now();
    _simTimer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
    notifyListeners();
  }

  void selectMember(String? id) {
    if (selectedMemberId == id) return;
    selectedMemberId = id;
    notifyListeners();
  }

  void toggleSharing() {
    sharingEnabled = !sharingEnabled;
    _saveSettings();
    notifyListeners();
  }

  void setNotifications(bool value) {
    notificationsEnabled = value;
    _saveSettings();
    notifyListeners();
  }

  void setBatterySaver(bool value) {
    batterySaver = value;
    _saveSettings();
    notifyListeners();
  }

  void setDarkMode(bool value) {
    darkMode = value;
    _saveSettings();
    notifyListeners();
  }

  void toggleMapDark() {
    mapDark = !mapDark;
    _saveSettings();
    notifyListeners();
  }

  void renameSelf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    currentUser.name = trimmed;
    notifyListeners();
  }

  void touchMemberLocation(String memberId) {
    final member = memberById(memberId);
    if (member == null) return;
    member.lastUpdated = DateTime.now();
    notifyListeners();
  }

  void addPlace({
    required String name,
    required String category,
    required String address,
    required LatLng point,
    required double radiusMeters,
  }) {
    _places.add(Place(
      id: 'place_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      address: address,
      icon: category,
      point: point,
      radiusMeters: radiusMeters,
    ));
    _savePlaces();
    notifyListeners();
  }

  void removePlace(String id) {
    _places.removeWhere((place) => place.id == id);
    for (final member in _members) {
      if (member.currentPlaceId == id) member.currentPlaceId = null;
    }
    _savePlaces();
    notifyListeners();
  }

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _messages.add(ChatMessage(
      id: 'msg_${_messageCounter++}',
      senderId: currentUser.id,
      text: trimmed,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(milliseconds: 1800), _simulateReply);
  }

  void sendSos() {
    _addAlert(AlertEvent(
      id: _nextAlertId(),
      memberId: currentUser.id,
      memberName: currentUser.name,
      type: AlertType.sos,
      title: '${currentUser.firstName} sent an SOS alert',
      body: 'Emergency assistance requested · circle notified',
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  void resetDemo() {
    _members.clear();
    _alerts.clear();
    _messages.clear();
    _places = _defaultPlaces();
    selectedMemberId = null;
    _savePlaces();
    _seedMembers();
    _seedAlerts();
    _seedMessages();
    _syncInitialPlaces();
    circleUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void _tick() {
    if (_disposed) return;
    _tickCount++;
    for (final member in _members) {
      if (member.dwellTicks > 0) {
        member.dwellTicks--;
        member.motion = MotionState.stationary;
        member.speedMph = 0;
      } else {
        _advanceMember(member);
      }
      _drainBattery(member);
      member.lastUpdated = DateTime.now();
    }
    _checkGeofences();
    circleUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void _advanceMember(Member member) {
    final isDriving = member.travelMode == TravelMode.driving;
    final speedFactor = isDriving ? 4.5 : 7.0;
    final baseSpeed = isDriving ? 12.0 : 1.5;
    var remaining = baseSpeed * speedFactor * 3;

    var guard = 0;
    while (remaining > 0.01 && guard < 60) {
      guard++;
      final from = member.route[member.legIndex];
      final to = member.route[(member.legIndex + 1) % member.route.length];
      final legMeters = distanceMeters(from, to);
      if (legMeters < 1) {
        member.legIndex = (member.legIndex + 1) % member.route.length;
        member.legT = 0;
        continue;
      }
      final left = legMeters * (1 - member.legT);
      if (remaining < left) {
        member.legT += remaining / legMeters;
        remaining = 0;
      } else {
        remaining -= left;
        member.legIndex = (member.legIndex + 1) % member.route.length;
        member.legT = 0;
      }
    }

    final from = member.route[member.legIndex];
    final to = member.route[(member.legIndex + 1) % member.route.length];
    member.position = LatLng(
      from.latitude + (to.latitude - from.latitude) * member.legT,
      from.longitude + (to.longitude - from.longitude) * member.legT,
    );
    member.motion =
        isDriving ? MotionState.driving : MotionState.walking;
    final wobble =
        sin((_tickCount + member.id.length * 3) / 2.4) * 2.5;
    member.speedMph = isDriving
        ? baseSpeed * 2.237 + wobble
        : baseSpeed * 2.237 + wobble.abs();
  }

  void _drainBattery(Member member) {
    final base = member.motion == MotionState.driving
        ? 0.075
        : member.motion == MotionState.walking
            ? 0.05
            : 0.025;
    final drain = base * (batterySaver ? 0.45 : 1.0);
    final before = member.battery;
    member.battery = max(4.0, member.battery - drain);
    if (before > 20 && member.battery <= 20 && !member.lowBatteryAlerted) {
      member.lowBatteryAlerted = true;
      _addAlert(AlertEvent(
        id: _nextAlertId(),
        memberId: member.id,
        memberName: member.name,
        type: AlertType.battery,
        title: "${member.firstName}'s battery is low",
        body: '${member.battery.round()}% remaining · consider charging',
        timestamp: DateTime.now(),
      ));
    }
  }

  void _checkGeofences() {
    for (final member in _members) {
      Place? inside;
      for (final place in _places) {
        if (distanceMeters(member.position, place.point) <=
            place.radiusMeters) {
          inside = place;
          break;
        }
      }
      final newId = inside?.id;
      if (newId == member.currentPlaceId) continue;

      final previous = placeById(member.currentPlaceId);
      member.currentPlaceId = newId;

      if (previous != null) {
        _addAlert(AlertEvent(
          id: _nextAlertId(),
          memberId: member.id,
          memberName: member.name,
          type: AlertType.departure,
          title: '${member.firstName} left ${previous.name}',
          body: 'Left ${previous.address}',
          timestamp: DateTime.now(),
        ));
      }
      if (inside != null) {
        if (member.dwellTicks == 0) {
          member.dwellTicks = 6 + _random.nextInt(7);
        }
        _addAlert(AlertEvent(
          id: _nextAlertId(),
          memberId: member.id,
          memberName: member.name,
          type: AlertType.arrival,
          title: '${member.firstName} arrived at ${inside.name}',
          body: 'Arrived at ${inside.address}',
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  void _addAlert(AlertEvent alert) {
    _alerts.add(alert);
    if (_alerts.length > 60) {
      _alerts.removeRange(0, _alerts.length - 60);
    }
  }

  String _nextAlertId() =>
      'alert_${DateTime.now().microsecondsSinceEpoch}_${_alerts.length}';

  void _simulateReply() {
    if (_disposed || !isReady) return;
    final others =
        _members.where((member) => !member.isCurrentUser).toList();
    if (others.isEmpty) return;
    final sender = others[_random.nextInt(others.length)];
    const replies = [
      'Got it, thanks!',
      'On my way.',
      'Sounds good.',
      'Just left, be home soon.',
      'Can you pick up milk on the way?',
      'Okay, see you then.',
      'I will check the map.',
    ];
    _messages.add(ChatMessage(
      id: 'msg_${_messageCounter++}',
      senderId: sender.id,
      text: replies[_random.nextInt(replies.length)],
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  List<Place> _defaultPlaces() => [
        const Place(
          id: 'home',
          name: 'Home',
          address: '148 Willow Creek Rd',
          icon: 'home',
          point: LatLng(30.2705, -97.7442),
          radiusMeters: 200,
        ),
        Place(
          id: 'work',
          name: 'Work',
          address: '2400 Commerce Center Dr',
          icon: 'work',
          point: LatLng(30.2632, -97.7388),
          radiusMeters: 200,
        ),
        Place(
          id: 'school',
          name: 'Oakwood High',
          address: '700 Oakwood High Blvd',
          icon: 'school',
          point: LatLng(30.2743, -97.7361),
          radiusMeters: 220,
        ),
        Place(
          id: 'gym',
          name: 'FitZone Gym',
          address: '88 Riverside Ave',
          icon: 'gym',
          point: LatLng(30.2608, -97.7475),
          radiusMeters: 150,
        ),
      ];

  void _seedMembers() {
    const home = LatLng(30.2705, -97.7442);
    const work = LatLng(30.2632, -97.7388);
    const school = LatLng(30.2743, -97.7361);
    const gym = LatLng(30.2608, -97.7475);
    final palette = LocmateColors.memberPalette;

    _members.addAll([
      Member(
        id: 'alex',
        name: 'Alex Carter',
        color: palette[0],
        travelMode: TravelMode.driving,
        isCurrentUser: true,
        isOwner: true,
        battery: 78,
        dwellTicks: 2,
        route: const [
          work,
          LatLng(30.2652, -97.7415),
          LatLng(30.2680, -97.7436),
          home,
          LatLng(30.2692, -97.7452),
          LatLng(30.2665, -97.7420),
          LatLng(30.2643, -97.7401),
        ],
      ),
      Member(
        id: 'maria',
        name: 'Maria Carter',
        color: palette[1],
        travelMode: TravelMode.driving,
        battery: 63,
        legIndex: 6,
        dwellTicks: 4,
        route: const [
          home,
          LatLng(30.2692, -97.7418),
          LatLng(30.2668, -97.7404),
          work,
          LatLng(30.2640, -97.7420),
          LatLng(30.2620, -97.7445),
          gym,
          LatLng(30.2642, -97.7460),
          LatLng(30.2672, -97.7455),
          LatLng(30.2694, -97.7449),
        ],
      ),
      Member(
        id: 'ethan',
        name: 'Ethan Carter',
        color: palette[2],
        travelMode: TravelMode.driving,
        battery: 51,
        legIndex: 7,
        dwellTicks: 4,
        route: const [
          school,
          LatLng(30.2720, -97.7390),
          LatLng(30.2690, -97.7395),
          LatLng(30.2662, -97.7412),
          gym,
          LatLng(30.2660, -97.7440),
          LatLng(30.2685, -97.7445),
          home,
          LatLng(30.2715, -97.7420),
          LatLng(30.2735, -97.7385),
        ],
      ),
      Member(
        id: 'lily',
        name: 'Lily Carter',
        color: palette[3],
        travelMode: TravelMode.walking,
        battery: 20.4,
        legIndex: 3,
        dwellTicks: 5,
        route: const [
          home,
          LatLng(30.2712, -97.7420),
          LatLng(30.2726, -97.7398),
          school,
          LatLng(30.2725, -97.7378),
          LatLng(30.2708, -97.7402),
          LatLng(30.2688, -97.7428),
        ],
      ),
      Member(
        id: 'noah',
        name: 'Noah Carter',
        color: palette[4],
        travelMode: TravelMode.walking,
        battery: 96,
        legIndex: 2,
        route: const [
          home,
          LatLng(30.2688, -97.7480),
          LatLng(30.2665, -97.7502),
          LatLng(30.2652, -97.7472),
          LatLng(30.2676, -97.7448),
        ],
      ),
    ]);
  }

  void _seedAlerts() {
    final now = DateTime.now();
    _alerts.addAll([
      AlertEvent(
        id: 'seed_1',
        memberId: 'maria',
        memberName: 'Maria Carter',
        type: AlertType.arrival,
        title: 'Maria arrived at Home',
        body: 'Arrived at 148 Willow Creek Rd',
        timestamp: now.subtract(const Duration(minutes: 12)),
      ),
      AlertEvent(
        id: 'seed_2',
        memberId: 'ethan',
        memberName: 'Ethan Carter',
        type: AlertType.departure,
        title: 'Ethan left Oakwood High',
        body: 'Left 700 Oakwood High Blvd',
        timestamp: now.subtract(const Duration(minutes: 58)),
      ),
      AlertEvent(
        id: 'seed_3',
        memberId: 'lily',
        memberName: 'Lily Carter',
        type: AlertType.battery,
        title: "Lily's battery dropped below 20%",
        body: '19% remaining · charging not detected',
        timestamp: now.subtract(const Duration(hours: 2, minutes: 40)),
      ),
      AlertEvent(
        id: 'seed_4',
        memberId: 'noah',
        memberName: 'Noah Carter',
        type: AlertType.arrival,
        title: 'Noah arrived at Home',
        body: 'Arrived at 148 Willow Creek Rd',
        timestamp: now.subtract(const Duration(hours: 4, minutes: 5)),
      ),
      AlertEvent(
        id: 'seed_5',
        memberId: 'alex',
        memberName: 'Alex Carter',
        type: AlertType.info,
        title: 'Location sharing is active',
        body: 'All 5 circle members are sharing their location',
        timestamp: now.subtract(const Duration(hours: 6)),
      ),
      AlertEvent(
        id: 'seed_6',
        memberId: 'maria',
        memberName: 'Maria Carter',
        type: AlertType.speed,
        title: 'Maria was driving 72 mph',
        body: 'Speed alert on Route 71',
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
      ),
    ]);
  }

  void _seedMessages() {
    final now = DateTime.now();
    _messageCounter = 10;
    _messages.addAll([
      ChatMessage(
        id: 'seed_msg_1',
        senderId: 'maria',
        text: "Dinner at 7? I'm making pasta.",
        timestamp: now.subtract(const Duration(minutes: 38)),
      ),
      ChatMessage(
        id: 'seed_msg_2',
        senderId: 'ethan',
        text: 'Can I get a ride home after practice?',
        timestamp: now.subtract(const Duration(minutes: 30)),
      ),
      ChatMessage(
        id: 'seed_msg_3',
        senderId: 'alex',
        text: "Sure, I'll pick you up at 6.",
        timestamp: now.subtract(const Duration(minutes: 26)),
      ),
      ChatMessage(
        id: 'seed_msg_4',
        senderId: 'lily',
        text: "I'm at the library with Mia. Home by 5.",
        timestamp: now.subtract(const Duration(minutes: 15)),
      ),
      ChatMessage(
        id: 'seed_msg_5',
        senderId: 'noah',
        text: 'Can we get pizza tonight?',
        timestamp: now.subtract(const Duration(minutes: 8)),
      ),
    ]);
  }

  void _syncInitialPlaces() {
    for (final member in _members) {
      for (final place in _places) {
        if (distanceMeters(member.position, place.point) <=
            place.radiusMeters) {
          member.currentPlaceId = place.id;
          break;
        }
      }
    }
  }

  List<Place>? _restorePlaces() {
    final raw = _prefs?.getString(_placesKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final restored = decoded
          .map((item) => Place.fromJson(item as Map<String, dynamic>))
          .toList();
      return restored.isEmpty ? null : restored;
    } catch (_) {
      return null;
    }
  }

  void _savePlaces() {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setString(
      _placesKey,
      jsonEncode(_places.map((place) => place.toJson()).toList()),
    );
  }

  void _saveSettings() {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setString(
      _settingsKey,
      jsonEncode({
        'sharing': sharingEnabled,
        'notifications': notificationsEnabled,
        'batterySaver': batterySaver,
        'darkMode': darkMode,
        'mapDark': mapDark,
      }),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _simTimer?.cancel();
    _replyTimer?.cancel();
    super.dispose();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Circle;
import 'package:locmate/models/alert_event.dart';
import 'package:locmate/models/circle.dart';
import 'package:locmate/models/member.dart';
import 'package:locmate/models/place.dart';
import 'package:locmate/models/profile.dart';
import 'package:locmate/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Place', () {
    test('round-trips through JSON', () {
      const place = Place(
        id: 'home',
        name: 'Home',
        address: '1 Main St',
        icon: 'home',
        point: LatLng(30.2672, -97.7431),
        radiusMeters: 180,
      );

      final restored = Place.fromJson(place.toJson());

      expect(restored.id, place.id);
      expect(restored.name, place.name);
      expect(restored.address, place.address);
      expect(restored.icon, place.icon);
      expect(restored.point.latitude, place.point.latitude);
      expect(restored.point.longitude, place.point.longitude);
      expect(restored.radiusMeters, place.radiusMeters);
    });

    test('falls back to coordinates when the address is blank', () {
      const place = Place(
        id: 'pin',
        name: 'Pin',
        address: '',
        icon: 'other',
        point: LatLng(1.2345, -6.789),
      );

      expect(place.displayAddress, contains('1.2345'));
      expect(place.displayAddress, contains('-6.7890'));
    });
  });

  group('AppState presentation helpers', () {
    late AppState state;
    late Member me;
    late Member maria;
    late Place home;

    setUp(() {
      me = Member(
        id: 'me',
        name: 'Jordan Lee',
        colorIndex: 0,
        isCurrentUser: true,
        isOwner: true,
        position: const LatLng(30.2672, -97.7431),
        battery: 84,
        isSharing: true,
        lastUpdated: DateTime.now(),
      );
      maria = Member(
        id: 'maria',
        name: 'Maria Lee',
        colorIndex: 1,
        position: const LatLng(30.26725, -97.74315),
        battery: 18,
        isSharing: true,
        lastUpdated: DateTime.now(),
      );
      home = const Place(
        id: 'home',
        name: 'Home',
        address: '1 Main St',
        icon: 'home',
        point: LatLng(30.2672, -97.7431),
        radiusMeters: 200,
      );
      state = AppState.preview(
        profile: const UserProfile(
          id: 'me',
          displayName: 'Jordan Lee',
          colorIndex: 0,
        ),
        circle: const Circle(
          id: 'circle',
          name: 'The Lee Family',
          inviteCode: 'ABC123',
          ownerId: 'me',
        ),
        members: [me, maria],
        places: [home],
      );
    });

    tearDown(() => state.dispose());

    test('reports places, distance and low batteries', () {
      expect(state.currentUser, me);
      expect(state.statusFor(me), 'At Home');
      expect(state.membersAtPlace(home), hasLength(2));
      expect(state.distanceToMe(maria), lessThan(20));
      expect(state.lowBatteryCount, 1);
      expect(state.locationLabelFor(me), '1 Main St');
    });

    test('shows paused sharing for other members', () {
      maria.isSharing = false;
      maria.position = null;

      expect(state.statusFor(maria), 'Location sharing paused');
      expect(state.sharingCount, 1);
      expect(state.distanceToMe(maria), isNull);
    });

    test('exposes alerts newest first', () {
      final older = AlertEvent(
        id: 'a',
        memberId: 'maria',
        memberName: 'Maria Lee',
        type: AlertType.arrival,
        title: 'Maria arrived at Home',
        body: '',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final newer = AlertEvent(
        id: 'b',
        memberId: 'me',
        memberName: 'Jordan Lee',
        type: AlertType.sos,
        title: 'SOS',
        body: '',
        timestamp: DateTime.now(),
      );
      final alertState = AppState.preview(
        profile: const UserProfile(
          id: 'me',
          displayName: 'Jordan Lee',
          colorIndex: 0,
        ),
        members: [me],
        alerts: [older, newer],
      );

      expect(alertState.alerts.first.id, 'b');
      expect(alertState.alertsForMember('maria'), hasLength(1));
      alertState.dispose();
    });
  });

  group('AppState initialization', () {
    test('starts signed out with no preloaded circle data', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.init();

      expect(state.phase, AppPhase.signedOut);
      expect(state.members, isEmpty);
      expect(state.places, isEmpty);
      expect(state.messages, isEmpty);
      expect(state.alerts, isEmpty);
      state.dispose();
    });

    test('persists appearance preferences locally', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.init();

      state.setDarkMode(true);
      state.toggleMapDark();
      state.setBatterySaver(true);

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('locmate.settings.v2');
      expect(stored, contains('"darkMode":true'));
      expect(stored, contains('"mapDark":true'));
      expect(stored, contains('"batterySaver":true'));
      state.dispose();
    });
  });
}

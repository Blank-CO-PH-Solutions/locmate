import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:locmate/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seeds the circle, places and chat', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.init();
    expect(state.isReady, isTrue);
    expect(state.members.length, 5);
    expect(state.currentUser.name, 'Alex Carter');
    expect(state.currentUser.isCurrentUser, isTrue);
    expect(state.places.length, 4);
    expect(state.messages.length, 5);
    expect(state.alerts, isNotEmpty);
    state.dispose();
  });

  test('sending a message triggers a simulated reply', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.init();
    final before = state.messages.length;
    state.sendMessage('Hello circle');
    expect(state.messages.length, before + 1);
    expect(state.messages.last.text, 'Hello circle');
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    expect(state.messages.length, before + 2);
    state.dispose();
  });

  test('settings and places persist locally', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.init();
    state.toggleSharing();
    expect(state.sharingEnabled, isFalse);

    final count = state.places.length;
    state.addPlace(
      name: 'School Drop-off',
      category: 'school',
      address: 'Test address',
      point: const LatLng(30.2672, -97.7431),
      radiusMeters: 150,
    );
    expect(state.places.length, count + 1);
    final added = state.places.last;
    expect(added.name, 'School Drop-off');
    state.removePlace(added.id);
    expect(state.places.length, count);
    state.dispose();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locmate.settings.v1'), contains('"sharing":false'));
    expect(prefs.getString('locmate.places.v1'), isNotNull);
  });
}

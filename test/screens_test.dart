import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locmate/screens/chat_screen.dart';
import 'package:locmate/screens/member_detail_screen.dart';
import 'package:locmate/screens/places_screen.dart';
import 'package:locmate/screens/safety_screen.dart';
import 'package:locmate/screens/settings_screen.dart';
import 'package:locmate/state/app_state.dart';
import 'package:locmate/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(AppState state, Widget child) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: buildLocmateTheme(Brightness.light),
      home: child,
    ),
  );
}

Future<AppState> _createState() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState();
  await state.init();
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    testWidgets('core screens lay out at ${size.width.toInt()}x'
        '${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final state = await _createState();
      try {
        await tester.pumpWidget(_wrap(state, const PlacesScreen()));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(_wrap(state, const SafetyScreen()));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _wrap(state, const ChatScreen(embedded: true)),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(_wrap(state, const SettingsScreen()));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _wrap(state, MemberDetailScreen(memberId: state.currentUser.id)),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      } finally {
        state.dispose();
      }
    });
  }

  testWidgets('add place sheet opens from header and tile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = await _createState();
    try {
      await tester.pumpWidget(_wrap(state, const PlacesScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add a place'));
      await tester.pumpAndSettle();
      expect(find.text('Add a place'), findsOneWidget);
      expect(find.text('Save place'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Save place'), findsNothing);

      await tester.tap(find.text('Add another place'));
      await tester.pumpAndSettle();
      expect(find.text('Save place'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      state.dispose();
    }
  });
}

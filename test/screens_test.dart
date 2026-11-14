import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Circle;
import 'package:locmate/app.dart';
import 'package:locmate/models/circle.dart';
import 'package:locmate/models/member.dart';
import 'package:locmate/models/profile.dart';
import 'package:locmate/screens/auth_screen.dart';
import 'package:locmate/screens/change_password_screen.dart';
import 'package:locmate/screens/chat_screen.dart';
import 'package:locmate/screens/circle_setup_screen.dart';
import 'package:locmate/screens/home_shell.dart';
import 'package:locmate/screens/legal_screen.dart';
import 'package:locmate/screens/map_screen.dart';
import 'package:locmate/screens/member_detail_screen.dart';
import 'package:locmate/screens/places_screen.dart';
import 'package:locmate/screens/safety_screen.dart';
import 'package:locmate/screens/settings_screen.dart';
import 'package:locmate/screens/subscription_screen.dart';
import 'package:locmate/state/app_state.dart';
import 'package:locmate/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

Widget _wrap(AppState state, Widget child) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(theme: buildLocmateTheme(Brightness.light), home: child),
  );
}

Member _member({bool sharing = true}) => Member(
  id: 'me',
  name: 'Jordan Lee',
  colorIndex: 0,
  isCurrentUser: true,
  isOwner: true,
  position: const LatLng(30.2672, -97.7431),
  battery: 82,
  isSharing: sharing,
  lastUpdated: DateTime.now(),
);

AppState _readyState({
  bool sharing = true,
  bool mustChangePassword = false,
  bool trialActive = false,
  int trialDaysLeft = 0,
}) => AppState.preview(
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
  members: [_member(sharing: sharing)],
  mustChangePassword: mustChangePassword,
  circlePremium: trialActive,
  trialActive: trialActive,
  trialDaysLeft: trialDaysLeft,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    testWidgets('core screens lay out at ${size.width.toInt()}x'
        '${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final state = _readyState();
      try {
        await tester.pumpWidget(_wrap(state, const PlacesScreen()));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(_wrap(state, const SafetyScreen()));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(_wrap(state, const ChatScreen(embedded: true)));
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

  testWidgets('auth screen renders signed out', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState.preview(phase: AppPhase.signedOut);
    try {
      await tester.pumpWidget(_wrap(state, const AuthScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
      expect(tester.takeException(), isNull);
    } finally {
      state.dispose();
    }
  });

  testWidgets('temporary password blocks the app until changed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _readyState(mustChangePassword: true);
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const LocmateApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose a new password'), findsOneWidget);
      expect(find.text('Update password'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      state.dispose();
    }
  });

  testWidgets('change password screen renders in optional mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _readyState();
    try {
      await tester.pumpWidget(
        _wrap(state, const ChangePasswordScreen(forced: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Update password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      state.dispose();
    }
  });

  testWidgets('circle setup renders create and join modes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState.preview(
      phase: AppPhase.setup,
      profile: const UserProfile(
        id: 'me',
        displayName: 'Jordan Lee',
        colorIndex: 0,
      ),
    );
    try {
      await tester.pumpWidget(_wrap(state, const CircleSetupScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Create my circle'), findsOneWidget);

      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      expect(find.text('Join this circle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      state.dispose();
    }
  });

  testWidgets('add place sheet opens from header and tile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _readyState();
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

  testWidgets('paused sharing is visible in the member detail', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState.preview(
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
      members: [_member(sharing: false)],
    );
    try {
      await tester.pumpWidget(
        _wrap(state, MemberDetailScreen(memberId: state.currentUser.id)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Location paused'), findsWidgets);
      expect(tester.takeException(), isNull);
    } finally {
      state.dispose();
    }
  });

  testWidgets('settings shows plan, legal and account actions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _readyState();
    try {
      await tester.pumpWidget(_wrap(state, const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Upgrade to Premium'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      state.dispose();
    }
  });

  testWidgets('legal documents render bundled markdown', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _readyState();
    try {
      await tester.pumpWidget(
        _wrap(state, const LegalScreen(document: LegalDocument.privacy)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('1. Information we collect'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('10. Contact us'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('10. Contact us'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      state.dispose();
    }
  });

  testWidgets('subscription screen renders the free plan', (tester) async {
    // Tall enough to render the whole paywall without scrolling.
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _readyState();
    try {
      await tester.pumpWidget(_wrap(state, const SubscriptionScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Free plan'), findsOneWidget);
      expect(find.text('Unlimited circle members'), findsOneWidget);
      expect(
        find.text('Purchases are available in the mobile apps'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      state.dispose();
    }
  });

  testWidgets('subscription screen shows the 7-day trial', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _readyState(trialActive: true, trialDaysLeft: 5);
    try {
      await tester.pumpWidget(_wrap(state, const SubscriptionScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Your Premium trial'), findsOneWidget);
      expect(find.text('Premium trial active'), findsOneWidget);
      expect(find.textContaining('5 days left'), findsWidgets);
      expect(find.text('Manage subscription'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      state.dispose();
    }
  });

  testWidgets('the map is the first screen after login', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _readyState();
    // Google Maps is a native platform view that cannot render in tests.
    MapScreen.useGoogleMapsOverride = false;
    addTearDown(() => MapScreen.useGoogleMapsOverride = null);
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: buildLocmateTheme(Brightness.light),
            home: const HomeShell(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MapScreen), findsOneWidget);
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
      expect(find.text('Circle'), findsWidgets);
    } finally {
      state.dispose();
    }
  });

  testWidgets('the circle panel minimizes to show the whole map', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _readyState();
    MapScreen.useGoogleMapsOverride = false;
    addTearDown(() => MapScreen.useGoogleMapsOverride = null);
    try {
      await tester.pumpWidget(_wrap(state, const MapScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      // Expanded: the member list is visible.
      expect(find.byTooltip('Minimize panel'), findsOneWidget);
      expect(find.textContaining('Jordan Lee'), findsOneWidget);

      await tester.tap(find.byTooltip('Minimize panel'));
      await tester.pump(const Duration(milliseconds: 300));

      // Minimized: only the slim control bar remains, so the map is clear.
      expect(find.byTooltip('Expand panel'), findsOneWidget);
      expect(find.textContaining('Jordan Lee'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Expand panel'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Minimize panel'), findsOneWidget);
      expect(find.textContaining('Jordan Lee'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      state.dispose();
    }
  });
}

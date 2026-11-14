import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'screens/auth_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/circle_setup_screen.dart';
import 'screens/home_shell.dart';
import 'screens/startup_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/notice_toast.dart';

class LocmateApp extends StatelessWidget {
  const LocmateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final needsNewPassword =
        state.mustChangePassword &&
        (state.phase == AppPhase.setup || state.phase == AppPhase.ready);

    final Widget home;
    if (needsNewPassword) {
      home = const ChangePasswordScreen(forced: true);
    } else {
      home = switch (state.phase) {
        AppPhase.loading => const SplashScreen(),
        AppPhase.signedOut => const AuthScreen(),
        AppPhase.setup => const CircleSetupScreen(),
        AppPhase.ready =>
          state.currentUserOrNull == null
              ? const StartupErrorScreen()
              : const HomeShell(),
        AppPhase.error => const StartupErrorScreen(),
      };
    }

    return MaterialApp(
      title: 'Locmate',
      debugShowCheckedModeBanner: false,
      theme: buildLocmateTheme(Brightness.light),
      darkTheme: buildLocmateTheme(Brightness.dark),
      themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: home,
      builder: (context, child) => NoticeToastHost(
        notices: state.notices,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

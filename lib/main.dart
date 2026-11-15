import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(
    const String.fromEnvironment("ACCESS_TOKEN"),
  );
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => AppState(client: Supabase.instance.client)..init(),
      child: const LocmateApp(),
    ),
  );
}

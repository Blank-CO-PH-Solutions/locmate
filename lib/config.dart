import 'package:flutter/foundation.dart';

/// Supabase project configuration.
///
/// The values below are the public project URL and the public anon key. They
/// are safe to ship in a mobile client; all access is protected by row level
/// security. Override them for another environment with:
///
/// ```sh
/// flutter run \
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your-anon-key
/// ```
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://radrullnoovvllikabmw.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_WC5HtowcvekplFyXR01fYw_rpnFKLwM',
  );

  /// Deep link used to return from browser-based OAuth (Google) sign-in.
  /// Must be added to the Supabase Auth redirect URL allowlist:
  ///   Supabase Dashboard → Authentication → URL Configuration →
  ///   Redirect URLs → com.locmate.locmate://login-callback
  static const String authRedirectUrl = 'com.locmate.locmate://login-callback';

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

/// Map configuration.
///
/// The map and place lookup use keyless services so there is nothing to
/// configure per environment:
///
/// * In-app map: Google Maps' public `output=embed` URL, loaded in a WebView
///   (Android/iOS) or iframe (web).
/// * Place search/reverse geocoding: OpenStreetMap Nominatim.
/// * Directions: Google Maps deep links.
///
/// Desktop builds (Linux, Windows, macOS) keep the OpenStreetMap `flutter_map`
/// layer, which also renders every member pin and place geofence.
class MapsConfig {
  const MapsConfig._();

  /// Identifies the app to Nominatim, whose usage policy requires it.
  static const String userAgent = 'Locmate/1.0 (hello@blankcoph.solutions)';

  /// Contact address sent with Nominatim requests (recommended by its policy).
  static const String contactEmail = 'hello@blankcoph.solutions';

  /// Whether this build renders the keyless Google Maps embed (WebView on
  /// Android/iOS, iframe on web) instead of the desktop OpenStreetMap layer.
  /// Desktop builds keep OpenStreetMap so every member pin and place geofence
  /// stays visible on one map.
  static bool get usesEmbeddedMap =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// RevenueCat (subscriptions) configuration. The public SDK keys come from
/// RevenueCat → Project settings → API keys and are safe to ship in the app:
///
/// ```sh
/// flutter run \
///   --dart-define=REVENUECAT_APPLE_KEY=appl_xxx \
///   --dart-define=REVENUECAT_GOOGLE_KEY=goog_xxx
/// ```
class RevenueCatConfig {
  const RevenueCatConfig._();

  static const String appleApiKey = String.fromEnvironment(
    'REVENUECAT_APPLE_KEY',
  );
  static const String googleApiKey = String.fromEnvironment(
    'REVENUECAT_GOOGLE_KEY',
  );

  /// Entitlement identifier configured in the RevenueCat dashboard.
  static const String entitlementId = 'premium';
}

/// Free plan limits. The database enforces the same values
/// (supabase/migrations/20261114120000_subscriptions.sql).
class PlanLimits {
  const PlanLimits._();

  static const int freeMembers = 5;
  static const int freePlaces = 2;

  /// New accounts get Premium for this many days (enforced in Supabase by
  /// `start_profile_trial`).
  static const int trialDays = 7;
}

/// Company and legal details shown in the app and in `assets/legal/`.
class LegalInfo {
  const LegalInfo._();

  static const String company = 'Blank CO PH Solutions';
  static const String contactEmail = 'hello@blankcoph.solutions';
  static const String address = 'Philippines';
  static const String effectiveDate = 'November 14, 2026';
  static const String copyright =
      '© 2026 Blank CO PH Solutions. All rights reserved.';
}

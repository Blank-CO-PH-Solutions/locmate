# Locmate

A location-sharing app for your circle: see your family and friends on a live map, get alerts when they arrive at or leave places, and reach them quickly in an emergency.

Built with Flutter and [Supabase](https://supabase.com) (auth, Postgres, realtime).

## Features

- **Circles**: create a circle or join one with an invite code
- **Live map**: see circle members' locations, battery level and last update; get directions to a member
- **Places**: geofences that send arrival and departure alerts
- **Safety**: SOS alerts, low-battery alerts, invite sharing
- **Chat**: real-time circle chat
- **Settings**: location sharing toggle, battery saver, dark mode for the app and the map
- **Sign-in**: email and password, or Google
- **Premium**: unlimited members and places, low-battery alerts, subscriptions through RevenueCat

## Project layout

```
lib/
  main.dart, app.dart     App entry and root widget
  config.dart             Supabase keys, OAuth redirect, plan limits, legal details
  state/app_state.dart    Single Provider: auth, circle, realtime, location, alerts, chat
  models/                 Circle, Member, Place, Message, AlertEvent, Profile
  screens/                Startup, auth, circle setup, home shell, legal, subscription
  services/               RevenueCat subscription wrapper
  widgets/                Shared UI (avatars, logo, banners)
assets/legal/             Privacy Policy, Terms of Service and copyright text
supabase/migrations/      Database schema, plan limits and account deletion
supabase/functions/       RevenueCat webhook
test/                     State and widget tests
```

## Getting started

```bash
flutter pub get
flutter run
```

Supabase settings default to the values in `lib/config.dart`. To use a different project, override them at build time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

Apply the database schema in `supabase/migrations/` to your Supabase project (for example with `supabase db push`).

### Google sign-in setup

1. In Supabase, go to **Authentication → Providers → Google**, turn it on, and add your Google OAuth client ID and secret.
2. Go to **Authentication → URL Configuration → Redirect URLs** and add:
   `com.locmate.locmate://login-callback`

The app already handles this deep link on Android (`AndroidManifest.xml`), iOS (`Info.plist`) and macOS (`Info.plist`).

### Background location

Android runs location sharing as a foreground service with a persistent notification. iOS enables the `location` background mode and asks for "Always" permission after "While using". macOS has the location entitlement in both `.entitlements` files. On Windows, location comes from the Windows location API and the system permission prompt. On Linux, location comes from GeoClue (permission is handled by the desktop portal). Background streams are only configured for Android and iOS; on desktop, location updates run while the app is open.

## Subscriptions (Free / Premium)

The Free plan includes 5 members and 2 places per circle. Premium removes both limits and enables low-battery alerts. The limits live in `lib/config.dart` (`PlanLimits`) and are enforced by the database in `supabase/migrations/20261114120000_subscriptions.sql`.

1. Run the migrations:

   ```bash
   supabase db push
   ```

2. In [RevenueCat](https://app.revenuecat.com), create an entitlement with the identifier `premium` (the app reads this from `RevenueCatConfig.entitlementId`). Add your App Store and Google Play products to an offering.

3. Pass the public SDK keys at build time:

   ```bash
   flutter run \
     --dart-define=REVENUECAT_APPLE_KEY=appl_xxx \
     --dart-define=REVENUECAT_GOOGLE_KEY=goog_xxx
   ```

4. Deploy the webhook and set its shared secret:

   ```bash
   supabase functions deploy revenuecat-webhook --no-verify-jwt
   supabase secrets set REVENUECAT_WEBHOOK_SECRET=<random-secret>
   ```

5. In RevenueCat → Integrations → Webhooks, add:

   - URL: `https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook`
   - Authorization header: `Bearer <same random secret>`

The app calls `Purchases.logIn(<Supabase user id>)`, so RevenueCat's `app_user_id` is the Supabase user id. The webhook writes the plan to `public.subscriptions`; clients can only read their own row.

Purchases are available on iOS, Android and macOS. Windows and Linux builds show the plans but cannot purchase.

### Internal team access

Blank CO PH Solutions staff can use Premium without a store purchase. After the team member has created an account, add them in the Supabase SQL editor:

```sql
select public.add_internal_tester('teammate@blankcoph.solutions');
```

Remove access with:

```sql
select public.remove_internal_tester('teammate@blankcoph.solutions');
```

Internal access is stored in `public.internal_testers` and is checked by `public.is_premium()`, so the database enforces it just like a paid subscription. A circle is Premium when its **owner** is internal; external users and circles owned by them stay on the Free plan.

Accounts created with `"must_change_password": true` in their user metadata are sent straight to the change-password screen after sign-in; the rest of the app stays blocked until they choose a new password. You can set the flag later in the Supabase SQL editor:

```sql
update auth.users
set raw_user_meta_data = raw_user_meta_data || '{"must_change_password": true}'
where email = 'teammate@blankcoph.solutions';
```

Users can change their password at any time from **Settings → Change password**.

Once RevenueCat is configured, you can also comp access there: open the customer in RevenueCat, click **Grant** in the Entitlements card, and choose the `premium` entitlement and an end date. RevenueCat sends that to the webhook as a promotional `NON_RENEWING_PURCHASE`, so the app picks it up without a rebuild. Use one method or the other; `internal_testers` is the option that works before RevenueCat is set up.

## Desktop builds

The `linux/`, `macos/` and `windows/` runner projects are checked in. Build them with the usual commands:

```bash
flutter run -d macos
flutter run -d windows
flutter run -d linux
```

macOS and Windows support location and battery reporting through their plugins. Linux gets location from GeoClue and battery state from UPower (install `upower` if it is missing); location only updates while the app is open. Google sign-in uses a custom URL scheme, and the Linux/Windows runners do not register it, so use email sign-in on those platforms.

## Legal and copyright

The Privacy Policy and Terms of Service are in `assets/legal/` and are rendered inside the app from **Settings → Legal**. The company name, contact email, address and copyright line are in `LegalInfo` in `lib/config.dart`. `LICENSE` contains the proprietary copyright notice for the source code.

The app asks Supabase to delete the account and its data from **Settings → Delete account** (the `delete_account` database function).

## Release signing (Android)

Create a keystore once:

```bash
keytool -genkey -v -keystore ~/locmate-release.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias locmate
```

Then create `android/key.properties`. Git ignores this file, so never commit it:

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=locmate
storeFile=/home/<you>/locmate-release.jks
```

Then run `flutter build appbundle`. If `key.properties` is missing, release builds are signed with the debug key.

## Tests

```bash
flutter test
```

## Regenerating icons and splash screen

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

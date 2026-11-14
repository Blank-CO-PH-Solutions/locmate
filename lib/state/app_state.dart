import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Circle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../services/subscription_service.dart';
import '../models/alert_event.dart';
import '../models/circle.dart';
import '../models/member.dart';
import '../models/message.dart';
import '../models/place.dart';
import '../models/profile.dart';
import '../utils.dart';

enum AppPhase { loading, signedOut, setup, ready, error }

/// Central app state backed by Supabase.
///
/// The current user authenticates with Supabase Auth, belongs to one circle and
/// receives live updates for locations, places, chat and alerts through
/// Supabase Realtime.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({SupabaseClient? client})
    : _client =
          client ??
          SupabaseClient(SupabaseConfig.url, SupabaseConfig.publishableKey);

  @visibleForTesting
  AppState.preview({
    this.phase = AppPhase.ready,
    this.profile,
    this.circle,
    List<Member> members = const [],
    List<Place> places = const [],
    List<ChatMessage> messages = const [],
    List<AlertEvent> alerts = const [],
    this.darkMode = false,
    this.mapDark = false,
    this.circlePremium = false,
    this.trialActive = false,
    this.trialEndsAt,
    this.trialDaysLeft = 0,
    this.mustChangePassword = false,
  }) : _client = SupabaseClient(
         SupabaseConfig.url,
         SupabaseConfig.publishableKey,
         authOptions: const AuthClientOptions(autoRefreshToken: false),
       ) {
    _members = [...members];
    _places = [...places];
    _messages = [...messages];
    _alerts = [...alerts];
    for (final member in members) {
      if (member.isCurrentUser) {
        sharingEnabled = member.isSharing;
        break;
      }
    }
  }

  static const String _settingsKey = 'locmate.settings.v2';
  static const String _lastLocationKey = 'locmate.last_location.v1';
  static const Duration _publishInterval = Duration(seconds: 15);

  /// How often the circle is re-synced and the current location re-published
  /// even when nothing moved, so every member's state is under a minute old.
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const double _publishDistanceMeters = 25;

  final SupabaseClient _client;
  final Battery _battery = Battery();
  final Uuid _uuid = const Uuid();

  SharedPreferences? _prefs;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<Position>? _positionSub;
  RealtimeChannel? _channel;
  Timer? _heartbeat;
  bool _heartbeatRunning = false;
  final StreamController<AppNotice> _notices =
      StreamController<AppNotice>.broadcast();
  Future<void>? _sessionFuture;
  int _authGeneration = 0;
  bool _disposed = false;
  bool _publishingLocation = false;
  bool _geofencePrimed = false;
  bool _batteryAlerted = false;
  DateTime? _lastPublishAt;
  DateTime? _lastSavedAt;
  LatLng? _lastPublishedPosition;
  String? _lastPlaceId;

  AppPhase phase = AppPhase.loading;
  String? startupError;
  String? syncError;
  String? locationError;
  bool locationPermissionDenied = false;
  bool locationServiceDisabled = false;

  /// True on iOS when only "While using the app" was granted, so updates stop
  /// shortly after the app goes to the background.
  bool backgroundLocationLimited = false;
  bool _askedForAlways = false;
  UserProfile? profile;
  Circle? circle;
  LatLng? currentPosition;
  LatLng? lastKnownPosition;
  LatLng? _lastPosition;
  bool sharingEnabled = true;
  bool darkMode = false;
  bool mapDark = false;
  bool batterySaver = false;
  bool refreshing = false;
  String? selectedMemberId;

  // Subscription plan. A circle is Premium when its owner subscribes; the
  // database enforces the Free limits (see PlanLimits).
  bool circlePremium = false;
  bool userPremium = false;

  /// New accounts get a 7-day Premium trial. `trialActive` is only true while
  /// there is no paid subscription or internal-tester access.
  bool trialActive = false;
  DateTime? trialEndsAt;
  int trialDaysLeft = 0;

  /// True when the account still uses a temporary password. The app blocks the
  /// rest of the UI until the user chooses a new one.
  bool mustChangePassword = false;

  int? get memberLimit => circlePremium ? null : PlanLimits.freeMembers;
  int? get placeLimit => circlePremium ? null : PlanLimits.freePlaces;
  bool get canAddPlace => placeLimit == null || _places.length < placeLimit!;
  bool get isOwner {
    final id = userId ?? currentUserOrNull?.id;
    return circle != null && circle!.ownerId == id;
  }

  List<Member> _members = [];
  List<Place> _places = [];
  List<ChatMessage> _messages = [];
  List<AlertEvent> _alerts = [];

  List<Member> get members => List.unmodifiable(_members);
  List<Place> get places => List.unmodifiable(_places);
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// In-app notifications (new alerts and chat messages from other members).
  /// The UI shows these as a toast and vibrates the phone.
  Stream<AppNotice> get notices => _notices.stream;

  /// Emits a notice. Public so the UI and tests can trigger one directly.
  void notify(AppNotice notice) {
    if (!_notices.isClosed) _notices.add(notice);
  }

  List<AlertEvent> get alerts {
    final copy = [..._alerts];
    copy.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return copy;
  }

  String? get userId => _client.auth.currentUser?.id;
  String? get userEmail => _client.auth.currentUser?.email;
  String get circleName => circle?.name ?? 'Your circle';
  String get inviteCode => circle?.inviteCode ?? '';

  Member? get currentUserOrNull {
    for (final member in _members) {
      if (member.isCurrentUser) return member;
    }
    return null;
  }

  Member get currentUser => _members.firstWhere(
    (member) => member.isCurrentUser,
    orElse: () => throw StateError('The current user is not loaded yet.'),
  );

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

  Place? placeFor(Member member) {
    if (member.position == null) return null;
    for (final place in _places) {
      if (distanceMeters(member.position!, place.point) <= place.radiusMeters) {
        return place;
      }
    }
    return null;
  }

  List<Member> membersAtPlace(Place place) => _members
      .where(
        (member) =>
            member.position != null &&
            distanceMeters(member.position!, place.point) <= place.radiusMeters,
      )
      .toList();

  bool isAtPlace(Member member, Place place) =>
      member.position != null &&
      distanceMeters(member.position!, place.point) <= place.radiusMeters;

  int get lowBatteryCount =>
      _members.where((member) => (member.battery ?? 100) <= 20).length;

  int get sharingCount => _members
      .where((member) => member.isSharing && member.position != null)
      .length;

  String statusFor(Member member) {
    if (!member.isSharing) return 'Location sharing paused';
    if (member.position == null) {
      return member.isCurrentUser
          ? 'Waiting for your location'
          : 'Waiting for location';
    }
    final place = placeFor(member);
    if (place != null) return 'At ${place.name}';
    if (member.isStale && !member.isCurrentUser) {
      return 'Last seen ${timeAgo(member.lastUpdated!)}';
    }
    return switch (member.motion) {
      MotionState.driving =>
        'Driving · ${(member.speed * 2.23694).round()} mph',
      MotionState.walking => 'Walking',
      MotionState.stationary => 'Stationary',
    };
  }

  String locationLabelFor(Member member) {
    if (!member.isSharing) return 'Location paused';
    final place = placeFor(member);
    if (place != null) return place.displayAddress;
    if (member.position != null) return formatCoordinates(member.position!);
    return 'Location not available yet';
  }

  double? distanceToMe(Member member) {
    final me = currentUserOrNull;
    if (me?.position == null || member.position == null) return null;
    return distanceMeters(me!.position!, member.position!);
  }

  List<AlertEvent> alertsForMember(String memberId) =>
      alerts.where((alert) => alert.memberId == memberId).toList();

  // ---------------------------------------------------------------------------
  // Lifecycle and auth
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    lastKnownPosition = _loadLastLocation();
    WidgetsBinding.instance.addObserver(this);
    _authSub = _client.auth.onAuthStateChange.listen(_onAuthState);

    if (_client.auth.currentSession == null) {
      _handleSignedOut();
    } else {
      await _loadSession();
    }
  }

  void _onAuthState(AuthState authState) {
    switch (authState.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.tokenRefreshed:
        if (phase == AppPhase.signedOut || phase == AppPhase.loading) {
          unawaited(_loadSession());
        }
      case AuthChangeEvent.signedOut:
        _handleSignedOut();
      default:
        break;
    }
  }

  Future<void> _loadSession() {
    return _sessionFuture ??= _doLoadSession().whenComplete(() {
      _sessionFuture = null;
    });
  }

  Future<void> _doLoadSession() async {
    final generation = ++_authGeneration;
    final user = _client.auth.currentUser;
    if (user == null) {
      _handleSignedOut();
      return;
    }

    // Accounts created with a temporary password must choose a new one before
    // they can use the app. The flag lives in the auth user's metadata so it
    // survives sign-out and works on every platform.
    mustChangePassword = user.userMetadata?['must_change_password'] == true;

    phase = AppPhase.loading;
    startupError = null;
    notifyListeners();

    try {
      final profileRow = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (generation != _authGeneration) return;

      UserProfile loadedProfile;
      if (profileRow == null) {
        final row = await _client
            .from('profiles')
            .insert({
              'id': user.id,
              'display_name': _fallbackName(user),
              'color_index': _fallbackColor(user.id),
            })
            .select()
            .single();
        if (generation != _authGeneration) return;
        loadedProfile = UserProfile.fromMap(_asMap(row));
      } else {
        loadedProfile = UserProfile.fromMap(_asMap(profileRow));
      }
      profile = loadedProfile;

      final membership = await _client
          .from('circle_members')
          .select('circle_id')
          .eq('user_id', user.id)
          .maybeSingle();
      if (generation != _authGeneration) return;

      if (membership == null) {
        circle = null;
        _members = [];
        _places = [];
        _messages = [];
        _alerts = [];
        phase = AppPhase.setup;
        notifyListeners();
        return;
      }

      final circleRow = await _client
          .from('circles')
          .select()
          .eq('id', membership['circle_id'] as String)
          .single();
      if (generation != _authGeneration) return;
      circle = Circle.fromMap(_asMap(circleRow));

      await _loadCircleData();
      if (generation != _authGeneration) return;

      _subscribeRealtime();
      phase = AppPhase.ready;
      notifyListeners();
      if (!mustChangePassword) unawaited(_startLocationUpdates());
    } catch (error) {
      if (generation != _authGeneration) return;
      startupError = friendlyError(error);
      phase = AppPhase.error;
      notifyListeners();
    }
  }

  String _fallbackName(User user) {
    final metadataName = user.userMetadata?['display_name'];
    if (metadataName is String && metadataName.trim().isNotEmpty) {
      return metadataName.trim();
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Locmate user';
  }

  int _fallbackColor(String id) =>
      id.codeUnits.fold<int>(0, (sum, value) => sum + value) % 5;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (phase == AppPhase.signedOut || phase == AppPhase.loading) {
      await _loadSession();
    }
  }

  /// Returns true when a session was created immediately. When Supabase has
  /// email confirmation enabled, false means the user must confirm by email
  /// before signing in.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
    );
    if (response.session != null &&
        (phase == AppPhase.signedOut || phase == AppPhase.loading)) {
      await _loadSession();
    }
    return response.session != null;
  }

  Future<void> signOut() async {
    await SubscriptionService.instance.logOut();
    await _client.auth.signOut();
    _handleSignedOut();
  }

  /// Replaces the current account password and clears the temporary-password
  /// flag. Supabase stores the flag in the user's metadata, so it is removed
  /// here in the same request.
  Future<void> changePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
        data: {'must_change_password': false},
      ),
    );
    mustChangePassword = false;
    notifyListeners();
    if (phase == AppPhase.ready) unawaited(_startLocationUpdates());
  }

  /// Permanently deletes the account and its data (Settings → Delete account).
  Future<void> deleteAccount() async {
    await _client.rpc('delete_account');
    await SubscriptionService.instance.logOut();
    try {
      await _client.auth.signOut();
    } catch (_) {
      // The user no longer exists; the local session is cleared below anyway.
    }
    _handleSignedOut();
  }

  Future<void> _loadPlan() async {
    final activeCircle = circle;
    if (activeCircle == null) return;
    try {
      final plan = _asMap(
        await _client.rpc(
          'circle_plan',
          params: {'p_circle_id': activeCircle.id},
        ),
      );
      circlePremium = plan['circle_premium'] as bool? ?? false;
      userPremium = plan['user_premium'] as bool? ?? false;
      trialActive = plan['trial_active'] as bool? ?? false;
      trialDaysLeft = (plan['trial_days_left'] as num?)?.toInt() ?? 0;
      final trialEnds = plan['trial_ends_at'];
      trialEndsAt = trialEnds is String
          ? DateTime.tryParse(trialEnds)?.toLocal()
          : null;
    } catch (_) {
      // Keep the last known plan; the server still enforces limits.
    }
  }

  /// Re-reads the plan after a purchase. The RevenueCat webhook updates
  /// Supabase a few seconds after the store confirms, so retry briefly.
  Future<void> refreshPlan({bool waitForPremium = false}) async {
    for (var attempt = 0; attempt < (waitForPremium ? 6 : 1); attempt++) {
      await _loadPlan();
      notifyListeners();
      if (!waitForPremium || userPremium) return;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  /// Opens the system browser for Google sign-in. The session arrives through
  /// the [SupabaseConfig.authRedirectUrl] deep link and is picked up by the
  /// auth state listener. Returns false when the browser could not be opened.
  ///
  /// Before opening the browser it checks that the Google provider is enabled
  /// in Supabase. Otherwise the browser would only show the raw
  /// "Unsupported provider: provider is not enabled" error.
  Future<bool> signInWithGoogle() async {
    if (await isGoogleProviderEnabled() == false) {
      throw const GoogleSignInUnavailable();
    }
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: SupabaseConfig.authRedirectUrl,
      scopes: 'email profile',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Reads the public Supabase Auth settings to see whether Google sign-in is
  /// turned on. Returns null when the check itself fails (offline, timeout) so
  /// the caller can still try the normal flow.
  static Future<bool?> isGoogleProviderEnabled({http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(
            Uri.parse('${SupabaseConfig.url}/auth/v1/settings'),
            headers: {'apikey': SupabaseConfig.publishableKey},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map) return null;
      final external = body['external'];
      if (external is! Map) return null;
      return external['google'] == true;
    } catch (_) {
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  void _handleSignedOut() {
    _authGeneration++;
    _positionSub?.cancel();
    _positionSub = null;
    _channel?.unsubscribe();
    _channel = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    selectedMemberId = null;
    profile = null;
    circle = null;
    currentPosition = null;
    _members = [];
    _places = [];
    _messages = [];
    _alerts = [];
    circlePremium = false;
    userPremium = false;
    trialActive = false;
    trialEndsAt = null;
    trialDaysLeft = 0;
    mustChangePassword = false;
    phase = AppPhase.signedOut;
    startupError = null;
    syncError = null;
    locationError = null;
    notifyListeners();
  }

  Future<void> retry() async {
    phase = AppPhase.loading;
    startupError = null;
    notifyListeners();
    await _loadSession();
  }

  // ---------------------------------------------------------------------------
  // Circle setup
  // ---------------------------------------------------------------------------

  Future<void> createCircle(String name) async {
    final data = await _client.rpc(
      'create_circle',
      params: {'p_name': name.trim()},
    );
    await _enterCircle(Circle.fromMap(_asMap(data)));
  }

  Future<void> joinCircle(String code) async {
    final data = await _client.rpc(
      'join_circle',
      params: {'p_invite_code': code.trim().toUpperCase()},
    );
    await _enterCircle(Circle.fromMap(_asMap(data)));
  }

  Future<void> _enterCircle(Circle joinedCircle) async {
    circle = joinedCircle;
    await _loadCircleData();
    _subscribeRealtime();
    phase = AppPhase.ready;
    refreshMaybe();
    unawaited(_startLocationUpdates());
  }

  Future<void> leaveCircle() async {
    await _client.rpc('leave_circle');
    _positionSub?.cancel();
    _positionSub = null;
    _channel?.unsubscribe();
    _channel = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    circle = null;
    _members = [];
    _places = [];
    _messages = [];
    _alerts = [];
    selectedMemberId = null;
    _geofencePrimed = false;
    phase = AppPhase.setup;
    notifyListeners();
  }

  void refreshMaybe() {
    if (!_disposed) notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Loading data
  // ---------------------------------------------------------------------------

  Future<void> _loadCircleData() async {
    final activeCircle = circle;
    final me = userId;
    if (activeCircle == null || me == null) return;

    final memberRows = _asMapList(
      await _client
          .from('circle_members')
          .select('user_id, joined_at')
          .eq('circle_id', activeCircle.id),
    );
    final memberIds = memberRows
        .map((row) => row['user_id'] as String)
        .toList(growable: false);

    if (memberIds.isEmpty) {
      _members = [];
    } else {
      final profileRows = _asMapList(
        await _client.from('profiles').select().inFilter('id', memberIds),
      );
      final locationRows = _asMapList(
        await _client
            .from('locations')
            .select()
            .eq('circle_id', activeCircle.id),
      );
      final locations = {
        for (final row in locationRows) row['user_id'] as String: row,
      };

      final builtMembers = <Member>[];
      for (final memberRow in memberRows) {
        final id = memberRow['user_id'] as String;
        Map<String, dynamic>? profileRow;
        for (final row in profileRows) {
          if (row['id'] == id) {
            profileRow = row;
            break;
          }
        }
        if (profileRow == null) continue;
        final member = Member(
          id: id,
          name: profileRow['display_name'] as String? ?? 'Locmate user',
          colorIndex: (profileRow['color_index'] as num?)?.toInt() ?? 0,
          isCurrentUser: id == me,
          isOwner: id == activeCircle.ownerId,
        );
        final location = locations[id];
        if (location != null) _applyLocation(member, location);
        builtMembers.add(member);
      }
      builtMembers.sort((a, b) {
        if (a.isCurrentUser != b.isCurrentUser) {
          return a.isCurrentUser ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      _members = builtMembers;

      final currentMember = currentUserOrNull;
      if (currentMember != null) {
        sharingEnabled = currentMember.isSharing;
        if (currentPosition != null) {
          currentMember.position = currentPosition;
          currentMember.lastUpdated = DateTime.now();
        }
      }
    }

    _places = _asMapList(
      await _client
          .from('places')
          .select()
          .eq('circle_id', activeCircle.id)
          .order('created_at'),
    ).map(Place.fromMap).toList();

    await _loadPlan();

    final messageRows = _asMapList(
      await _client
          .from('messages')
          .select()
          .eq('circle_id', activeCircle.id)
          .order('created_at', ascending: false)
          .limit(100),
    );
    _messages = messageRows.map(ChatMessage.fromMap).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final alertRows = _asMapList(
      await _client
          .from('alerts')
          .select()
          .eq('circle_id', activeCircle.id)
          .order('created_at', ascending: false)
          .limit(100),
    );
    _alerts = alertRows
        .map(
          (row) => AlertEvent.fromMap(
            row,
            memberName:
                memberById(row['member_id'] as String?)?.name ?? 'Member',
          ),
        )
        .toList();
    _geofencePrimed = false;
  }

  void _applyLocation(Member member, Map<String, dynamic> location) {
    final isSharing = location['is_sharing'] as bool? ?? true;
    member.isSharing = isSharing;
    member.battery = (location['battery'] as num?)?.toDouble();
    var updatedAt = DateTime.now();
    final rawUpdatedAt = location['updated_at'];
    if (rawUpdatedAt is String) {
      updatedAt = DateTime.parse(rawUpdatedAt).toLocal();
    }
    member.lastUpdated = updatedAt;

    if (!isSharing ||
        location['latitude'] == null ||
        location['longitude'] == null) {
      member.position = null;
      member.accuracy = null;
      member.heading = null;
      member.speed = 0;
      return;
    }

    member.position = LatLng(
      (location['latitude'] as num).toDouble(),
      (location['longitude'] as num).toDouble(),
    );
    member.accuracy = (location['accuracy'] as num?)?.toDouble();
    member.heading = (location['heading'] as num?)?.toDouble();
    member.speed = (location['speed'] as num?)?.toDouble() ?? 0;
  }

  Future<void> refreshData() async {
    if (phase != AppPhase.ready || circle == null) return;
    refreshing = true;
    notifyListeners();
    try {
      await _loadCircleData();
      syncError = null;
    } catch (error) {
      syncError = friendlyError(error);
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------------

  void _subscribeRealtime() {
    final activeCircle = circle;
    if (activeCircle == null) return;
    _channel?.unsubscribe();
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'circle_id',
      value: activeCircle.id,
    );

    final channel = _client.channel(
      'circle:${activeCircle.id}:${DateTime.now().microsecondsSinceEpoch}',
    );
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'locations',
          filter: filter,
          callback: _handleLocationChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: filter,
          callback: _handleMessageChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alerts',
          filter: filter,
          callback: _handleAlertChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'places',
          filter: filter,
          callback: (_) => unawaited(_reloadPlaces()),
        )
        .subscribe();
    _channel = channel;
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _onHeartbeat());
  }

  /// Keeps the circle fresh when realtime events are missed and re-publishes
  /// this device's location (with a new battery reading) while standing still,
  /// because the position stream only fires after the device moves.
  Future<void> _onHeartbeat() async {
    if (_disposed || _heartbeatRunning) return;
    if (phase != AppPhase.ready || circle == null) return;
    _heartbeatRunning = true;
    try {
      final last = _lastPosition;
      final stale =
          _lastPublishAt == null ||
          DateTime.now().difference(_lastPublishAt!) >= heartbeatInterval;
      if (sharingEnabled && last != null && stale) {
        await _publishLocation(last, force: true);
      }
      await _loadCircleData();
      if (syncError != null) syncError = null;
      notifyListeners();
    } catch (_) {
      // Transient; the next heartbeat or a manual refresh retries.
    } finally {
      _heartbeatRunning = false;
    }
  }

  void _handleLocationChange(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.delete) return;
    final record = payload.newRecord;
    final member = memberById(record['user_id'] as String?);
    if (member == null || member.isCurrentUser) return;
    _applyLocation(member, record);
    notifyListeners();
  }

  void _handleMessageChange(PostgresChangePayload payload) {
    final message = ChatMessage.fromMap(payload.newRecord);
    final isNew = !_messages.any((existing) => existing.id == message.id);
    _addMessage(message);
    notifyListeners();
    if (isNew && message.senderId != userId) {
      final sender = memberById(message.senderId);
      notify(
        AppNotice(
          title: sender?.name ?? 'New message',
          body: message.text,
          icon: Icons.chat_bubble_rounded,
          color: sender?.color,
        ),
      );
    }
  }

  void _handleAlertChange(PostgresChangePayload payload) {
    final record = payload.newRecord;
    final alert = AlertEvent.fromMap(
      record,
      memberName: memberById(record['member_id'] as String?)?.name ?? 'Member',
    );
    final isNew = !_alerts.any((existing) => existing.id == alert.id);
    _addAlert(alert);
    notifyListeners();
    if (isNew && alert.memberId != userId) {
      notify(
        AppNotice(
          title: alert.title,
          body: alert.body,
          icon: alertIcon(alert.type),
          urgent: alert.type == AlertType.sos,
        ),
      );
    }
  }

  Future<void> _reloadPlaces() async {
    final activeCircle = circle;
    if (activeCircle == null) return;
    try {
      final rows = _asMapList(
        await _client
            .from('places')
            .select()
            .eq('circle_id', activeCircle.id)
            .order('created_at'),
      );
      _places = rows.map(Place.fromMap).toList();
      notifyListeners();
    } catch (error) {
      syncError = friendlyError(error);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Location tracking
  // ---------------------------------------------------------------------------

  LocationAccuracy get _accuracy =>
      batterySaver ? LocationAccuracy.medium : LocationAccuracy.high;
  int get _distanceFilter => batterySaver ? 50 : 15;

  /// Settings for a single position fix (never starts a background service).
  LocationSettings get _locationSettings =>
      LocationSettings(accuracy: _accuracy, distanceFilter: _distanceFilter);

  /// Settings for the continuous stream. On Android this runs a foreground
  /// service with a persistent notification and on iOS it enables background
  /// location updates, so the circle keeps seeing you while the app is closed.
  LocationSettings get _streamSettings {
    if (kIsWeb) return _locationSettings;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: _accuracy,
          distanceFilter: _distanceFilter,
          intervalDuration: Duration(seconds: batterySaver ? 30 : 10),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Locmate is sharing your location',
            notificationText:
                'Your circle can see where you are. Pause sharing in Settings.',
            notificationChannelName: 'Location sharing',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: _accuracy,
          distanceFilter: _distanceFilter,
          activityType: ActivityType.other,
          pauseLocationUpdatesAutomatically: batterySaver,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        );
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: _accuracy,
          distanceFilter: _distanceFilter,
        );
      default:
        return _locationSettings;
    }
  }

  Future<void> _startLocationUpdates() async {
    if (_disposed || phase != AppPhase.ready || circle == null) return;
    if (!sharingEnabled) {
      await _stopLocationUpdates();
      return;
    }
    try {
      locationServiceDisabled = !await Geolocator.isLocationServiceEnabled();
      if (locationServiceDisabled) {
        locationError = 'Location services are turned off for this device.';
        notifyListeners();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      // iOS: after "While using", ask once more so iOS can offer "Always".
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          permission == LocationPermission.whileInUse &&
          !_askedForAlways) {
        _askedForAlways = true;
        permission = await Geolocator.requestPermission();
      }
      backgroundLocationLimited =
          permission == LocationPermission.whileInUse &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        locationPermissionDenied = true;
        locationError = permission == LocationPermission.deniedForever
            ? 'Location access is blocked. Enable it in system settings.'
            : 'Location access is needed to share your position.';
        notifyListeners();
        return;
      }

      locationPermissionDenied = false;
      locationServiceDisabled = false;
      locationError = null;
      notifyListeners();

      await _positionSub?.cancel();
      _positionSub = null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
      await _handlePosition(position, forcePublish: true);

      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: _streamSettings,
          ).listen((position) {
            unawaited(_handlePosition(position));
          });
    } catch (error) {
      locationError =
          'Could not start location updates. '
          '${friendlyError(error)}';
      notifyListeners();
    }
  }

  Future<void> _stopLocationUpdates() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }

  Future<void> _handlePosition(
    Position position, {
    bool forcePublish = false,
  }) async {
    if (_disposed || circle == null) return;
    final point = LatLng(position.latitude, position.longitude);
    currentPosition = point;
    _lastPosition = point;
    lastKnownPosition = point;
    _saveLastLocation(point);

    final me = currentUserOrNull;
    if (me != null) {
      me.position = sharingEnabled ? point : null;
      me.accuracy = sharingEnabled ? position.accuracy : null;
      me.heading = sharingEnabled && position.heading >= 0
          ? position.heading
          : null;
      me.speed = sharingEnabled && position.speed >= 0 ? position.speed : 0;
      me.lastUpdated = DateTime.now();
      me.isSharing = sharingEnabled;
    }
    notifyListeners();

    if (sharingEnabled) {
      final movedFarEnough =
          _lastPublishedPosition == null ||
          distanceMeters(_lastPublishedPosition!, point) >=
              _publishDistanceMeters;
      final intervalPassed =
          _lastPublishAt == null ||
          DateTime.now().difference(_lastPublishAt!) >= _publishInterval;
      if (forcePublish || movedFarEnough || intervalPassed) {
        await _publishLocation(point, force: true);
      }
      await _checkGeofences(point);
    }
  }

  Future<void> _publishLocation(LatLng point, {bool force = false}) async {
    if (_publishingLocation || circle == null || userId == null) return;
    _publishingLocation = true;
    try {
      final batteryLevel = await _readBatteryLevel();
      _maybeAlertBattery(batteryLevel);
      final now = DateTime.now().toUtc();
      await _client.from('locations').upsert({
        'user_id': userId,
        'circle_id': circle!.id,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'accuracy': currentUserOrNull?.accuracy,
        'heading': currentUserOrNull?.heading,
        'speed': currentUserOrNull?.speed ?? 0,
        'battery': batteryLevel,
        'is_sharing': true,
        'updated_at': now.toIso8601String(),
      }, onConflict: 'user_id');
      _lastPublishAt = DateTime.now();
      _lastPublishedPosition = point;
      if (syncError != null) {
        syncError = null;
        notifyListeners();
      }
    } catch (error) {
      syncError = friendlyError(error);
      notifyListeners();
    } finally {
      _publishingLocation = false;
    }
  }

  Future<void> _publishPaused() async {
    if (circle == null || userId == null) return;
    try {
      final batteryLevel = await _readBatteryLevel();
      await _client.from('locations').upsert({
        'user_id': userId,
        'circle_id': circle!.id,
        'latitude': null,
        'longitude': null,
        'accuracy': null,
        'heading': null,
        'speed': 0,
        'battery': batteryLevel,
        'is_sharing': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
      _lastPublishAt = null;
      _lastPublishedPosition = null;
    } catch (error) {
      syncError = friendlyError(error);
      notifyListeners();
    }
  }

  Future<int?> _readBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }

  void _maybeAlertBattery(int? level) {
    if (level == null || !sharingEnabled || !circlePremium) return;
    if (level > 20) {
      _batteryAlerted = false;
      return;
    }
    if (_batteryAlerted) return;
    _batteryAlerted = true;
    final me = currentUserOrNull;
    if (me == null) return;
    unawaited(
      _insertAlert(
        type: AlertType.battery,
        title: "${me.firstName}'s battery is low",
        body: '$level% remaining · consider charging',
      ),
    );
  }

  Future<void> _checkGeofences(LatLng point) async {
    final me = currentUserOrNull;
    if (me == null) return;

    Place? inside;
    for (final place in _places) {
      if (distanceMeters(point, place.point) <= place.radiusMeters) {
        inside = place;
        break;
      }
    }

    final previousId = _lastPlaceId;
    final newId = inside?.id;
    if (!_geofencePrimed) {
      _geofencePrimed = true;
      _lastPlaceId = newId;
      return;
    }
    if (newId == previousId) return;
    _lastPlaceId = newId;

    final previous = placeById(previousId);
    if (previous != null) {
      await _insertAlert(
        type: AlertType.departure,
        title: '${me.firstName} left ${previous.name}',
        body: 'Left ${previous.displayAddress}',
      );
    }
    if (inside != null) {
      await _insertAlert(
        type: AlertType.arrival,
        title: '${me.firstName} arrived at ${inside.name}',
        body: 'Arrived at ${inside.displayAddress}',
      );
    }
  }

  Future<void> _insertAlert({
    required AlertType type,
    required String title,
    required String body,
  }) async {
    final me = currentUserOrNull;
    if (me == null || circle == null) return;
    try {
      final row = await _client
          .from('alerts')
          .insert({
            'circle_id': circle!.id,
            'member_id': me.id,
            'type': type.name,
            'title': title,
            'body': body,
          })
          .select()
          .single();
      _addAlert(AlertEvent.fromMap(_asMap(row), memberName: me.name));
      notifyListeners();
    } catch (error) {
      syncError = friendlyError(error);
      notifyListeners();
    }
  }

  Future<void> refreshMyLocation() async {
    if (phase != AppPhase.ready) return;
    await _startLocationUpdates();
  }

  Future<void> refreshMemberLocation(String memberId) async {
    final member = memberById(memberId);
    if (member == null) return;
    if (member.isCurrentUser) {
      await refreshMyLocation();
      return;
    }
    try {
      final row = await _client
          .from('locations')
          .select()
          .eq('user_id', memberId)
          .maybeSingle();
      if (row != null) _applyLocation(member, _asMap(row));
      notifyListeners();
    } catch (error) {
      syncError = friendlyError(error);
      notifyListeners();
    }
  }

  Future<void> openSystemLocationSettings() async {
    if (locationPermissionDenied) {
      await Geolocator.openAppSettings();
    } else {
      await Geolocator.openLocationSettings();
    }
    await _startLocationUpdates();
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  void _loadSettings() {
    final raw = _prefs?.getString(_settingsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      darkMode = decoded['darkMode'] as bool? ?? false;
      mapDark = decoded['mapDark'] as bool? ?? false;
      batterySaver = decoded['batterySaver'] as bool? ?? false;
    } catch (_) {
      // Ignore malformed preferences and keep defaults.
    }
  }

  void _saveSettings() {
    _prefs?.setString(
      _settingsKey,
      jsonEncode({
        'darkMode': darkMode,
        'mapDark': mapDark,
        'batterySaver': batterySaver,
      }),
    );
  }

  void toggleSharing() {
    sharingEnabled = !sharingEnabled;
    final me = currentUserOrNull;
    if (me != null) {
      me.isSharing = sharingEnabled;
      if (!sharingEnabled) {
        me.position = null;
        me.speed = 0;
      } else if (_lastPosition != null) {
        me.position = _lastPosition;
        me.lastUpdated = DateTime.now();
      }
    }
    if (!sharingEnabled) {
      _lastPublishedPosition = null;
      _lastPublishAt = null;
    }
    notifyListeners();
    if (sharingEnabled) {
      final point = _lastPosition ?? currentPosition;
      if (point != null) {
        unawaited(_publishLocation(point, force: true));
      }
      unawaited(_startLocationUpdates());
    } else {
      unawaited(_stopLocationUpdates());
      unawaited(_publishPaused());
    }
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

  void setBatterySaver(bool value) {
    batterySaver = value;
    _saveSettings();
    notifyListeners();
    _positionSub?.cancel();
    _positionSub = null;
    unawaited(_startLocationUpdates());
  }

  void selectMember(String? id) {
    if (selectedMemberId == id) return;
    selectedMemberId = id;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Profile, places, chat and SOS
  // ---------------------------------------------------------------------------

  Future<void> renameSelf(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || profile == null) return;
    await _client
        .from('profiles')
        .update({'display_name': trimmed})
        .eq('id', profile!.id);
    profile = UserProfile(
      id: profile!.id,
      displayName: trimmed,
      colorIndex: profile!.colorIndex,
    );
    currentUserOrNull?.name = trimmed;
    notifyListeners();
  }

  Future<void> addPlace({
    required String name,
    required String category,
    required String address,
    required LatLng point,
    required double radiusMeters,
  }) async {
    if (circle == null) throw StateError('Join a circle before adding places.');
    if (!canAddPlace) {
      throw StateError(
        'The Free plan includes ${PlanLimits.freePlaces} places. '
        'Upgrade to Premium for unlimited places.',
      );
    }
    final row = await _client
        .from('places')
        .insert({
          'circle_id': circle!.id,
          'name': name.trim(),
          'address': address.trim(),
          'icon': category,
          'latitude': point.latitude,
          'longitude': point.longitude,
          'radius_meters': radiusMeters.round(),
          'created_by': userId,
        })
        .select()
        .single();
    final place = Place.fromMap(_asMap(row));
    if (!_places.any((existing) => existing.id == place.id)) {
      _places.add(place);
    }
    notifyListeners();
  }

  Future<void> removePlace(String id) async {
    await _client.from('places').delete().eq('id', id);
    _places.removeWhere((place) => place.id == id);
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || circle == null) return;
    final row = await _client
        .from('messages')
        .insert({
          'id': _uuid.v4(),
          'circle_id': circle!.id,
          'sender_id': userId,
          'body': trimmed,
        })
        .select()
        .single();
    _addMessage(ChatMessage.fromMap(_asMap(row)));
    notifyListeners();
  }

  Future<void> sendSos() async {
    final me = currentUserOrNull;
    if (me == null) throw StateError('Your profile is still loading.');
    await _insertAlert(
      type: AlertType.sos,
      title: '${me.firstName} sent an SOS alert',
      body: 'Emergency assistance requested · $circleName notified',
    );
    if (sharingEnabled && _lastPosition != null) {
      await _publishLocation(_lastPosition!, force: true);
    }
  }

  void _addMessage(ChatMessage message) {
    if (_messages.any((existing) => existing.id == message.id)) return;
    _messages.add(message);
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (_messages.length > 200) {
      _messages.removeRange(0, _messages.length - 200);
    }
  }

  void _addAlert(AlertEvent alert) {
    if (_alerts.any((existing) => existing.id == alert.id)) return;
    _alerts.add(alert);
    _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (_alerts.length > 100) {
      _alerts.removeRange(100, _alerts.length);
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  void _saveLastLocation(LatLng point) {
    final now = DateTime.now();
    if (_lastSavedAt != null &&
        now.difference(_lastSavedAt!) < const Duration(seconds: 30)) {
      return;
    }
    _lastSavedAt = now;
    _prefs?.setString(
      _lastLocationKey,
      jsonEncode({'lat': point.latitude, 'lng': point.longitude}),
    );
  }

  LatLng? _loadLastLocation() {
    final raw = _prefs?.getString(_lastLocationKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return LatLng(
        (decoded['lat'] as num).toDouble(),
        (decoded['lng'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _asMap(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  List<Map<String, dynamic>> _asMapList(dynamic value) => (value as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The position stream keeps running while the app is in the background
    // (Android foreground service / iOS background mode). On resume we only
    // restart it if the OS stopped it, and refresh circle data.
    if (state == AppLifecycleState.resumed && phase == AppPhase.ready) {
      if (_positionSub == null) unawaited(_startLocationUpdates());
      unawaited(refreshData());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _positionSub?.cancel();
    _channel?.unsubscribe();
    _heartbeat?.cancel();
    _notices.close();
    super.dispose();
  }
}

/// Thrown when Google sign-in is not enabled for the Supabase project.
class GoogleSignInUnavailable implements Exception {
  const GoogleSignInUnavailable();

  @override
  String toString() =>
      'Google sign-in is not available yet. Use your email and password '
      'for now.';
}

/// A short in-app notification shown as a toast.
class AppNotice {
  const AppNotice({
    required this.title,
    this.body = '',
    this.icon = Icons.notifications_rounded,
    this.color,
    this.urgent = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color? color;

  /// Urgent notices (SOS) vibrate longer and stay on screen longer.
  final bool urgent;
}

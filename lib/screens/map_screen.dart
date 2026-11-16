import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/place.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/member_avatar.dart';
import 'chat_screen.dart';
import 'circle_info_screen.dart';
import 'member_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final osm.MapController _osmController = osm.MapController();
  final ValueNotifier<double> _rotation = ValueNotifier<double>(0);
  late final AnimationController _followAnimation;

  /// Last current-user position the camera followed. Live updates compare
  /// against this to animate the camera to each new location.
  LatLng? _followPosition;
  double _followZoom = 15.6;
  _LatLngTween? _centerTween;
  bool _mapReady = false;
  bool _autoCentered = false;
  bool _following = false;
  bool _panelMinimized = false;
  double _panelHeight = 0;

  static const String _tilesUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const LatLng _worldCenter = LatLng(20, 0);

  @override
  void initState() {
    super.initState();
    _followAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(_tickFollowAnimation);
  }

  @override
  void dispose() {
    _followAnimation
      ..removeListener(_tickFollowAnimation)
      ..dispose();
    _rotation.dispose();
    _osmController.dispose();
    super.dispose();
  }

  void _tickFollowAnimation() {
    if (!_mapReady || _centerTween == null) return;
    _osmController.move(_centerTween!.evaluate(_followAnimation), _followZoom);
  }

  static bool _samePoint(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < 1e-7 &&
      (a.longitude - b.longitude).abs() < 1e-7;

  LatLng? _firstMemberPosition(AppState state) {
    for (final member in state.members) {
      if (member.position != null) return member.position;
    }
    return null;
  }

  LatLng _initialCenter(AppState state) =>
      state.currentUserOrNull?.position ??
      state.lastKnownPosition ??
      _firstMemberPosition(state) ??
      _worldCenter;

  void _stopFollowing() {
    if (_followAnimation.isAnimating) _followAnimation.stop();
    if (!_following) return;
    setState(() => _following = false);
  }

  void _startFollowing(LatLng position) {
    _followPosition = position;
    if (!_following) setState(() => _following = true);
  }

  void _moveCamera(LatLng target, double zoom, {bool animated = false}) {
    if (!_mapReady) return;
    _followZoom = zoom;
    if (!animated) {
      if (_followAnimation.isAnimating) _followAnimation.stop();
      _osmController.move(target, zoom);
      return;
    }
    final camera = _osmController.camera;
    _centerTween = _LatLngTween(begin: camera.center, end: target);
    _followAnimation
      ..reset()
      ..forward();
  }

  /// Keeps the camera centered on live location updates while following.
  void _syncFollow(AppState state) {
    if (!_mapReady) return;
    final position = state.currentUserOrNull?.position;
    if (position == null) return;
    if (!_autoCentered) {
      _autoCentered = true;
      _followPosition = position;
      // This runs from build(), so update the flag directly and let the
      // in-progress build pick it up instead of calling setState().
      _following = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _moveCamera(position, 15.6);
      });
      return;
    }
    if (_following &&
        (_followPosition == null || !_samePoint(_followPosition!, position))) {
      _followPosition = position;
      // Starting the animation from build() is unsafe; schedule it after the
      // current frame instead.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_following) return;
        _moveCamera(position, _followZoom, animated: true);
      });
    }
  }

  void _onPositionChanged(osm.MapCamera camera, bool hasGesture) {
    // A notifier avoids rebuilding the whole map on every camera tick.
    _rotation.value = camera.rotation;
    // Dragging, pinching or rotating the map means the user took over, so stop
    // following and cancel any in-flight camera animation.
    if (hasGesture) _stopFollowing();
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    _stopFollowing();
    final camera = _osmController.camera;
    final zoom = (camera.zoom + delta).clamp(2.0, 18.0).toDouble();
    _osmController.move(camera.center, zoom);
  }

  void _resetNorth() {
    if (!_mapReady) return;
    _osmController.rotate(0);
    _rotation.value = 0;
  }

  List<LatLng> _circlePoints(LatLng center, double radiusMeters) {
    final latOffset = radiusMeters / 111320;
    final lngOffset =
        radiusMeters /
        (111320 * math.cos(center.latitudeInRad).clamp(0.01, 1.0));
    return [
      LatLng(center.latitude - latOffset, center.longitude - lngOffset),
      LatLng(center.latitude + latOffset, center.longitude + lngOffset),
      center,
    ];
  }

  void _fitAll() {
    if (!_mapReady) return;
    _stopFollowing();
    final state = context.read<AppState>();
    final points = <LatLng>[
      for (final member in state.members)
        if (member.position != null) member.position!,
      for (final place in state.places)
        ..._circlePoints(place.point, place.radiusMeters),
    ];
    if (points.isEmpty) {
      _moveCamera(_worldCenter, 3);
      return;
    }
    _osmController.fitCamera(
      osm.CameraFit.bounds(
        bounds: osm.LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(28, 112, 28, 220),
        maxZoom: 16,
      ),
    );
  }

  void _focusMember(Member member) {
    context.read<AppState>().selectMember(member.id);
    _stopFollowing();
    if (member.position != null) {
      _moveCamera(member.position!, 15.4, animated: true);
    }
  }

  void _recenter() {
    final state = context.read<AppState>();
    final position = state.currentUserOrNull?.position;
    if (position == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Waiting for your location…')),
        );
      state.refreshMyLocation();
      return;
    }
    _startFollowing(position);
    _moveCamera(position, 15.8);
  }

  void _openChat() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ChatScreen()));
  }

  void _openDetails(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberDetailScreen(memberId: member.id),
      ),
    );
  }

  void _openCircleInfo() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CircleInfoScreen()));
  }

  void _toggleSharing(BuildContext context) {
    final state = context.read<AppState>();
    state.toggleSharing();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            state.sharingEnabled
                ? 'Location sharing resumed'
                : 'Location sharing paused',
          ),
        ),
      );
  }

  Future<void> _copyInviteCode() async {
    final code = context.read<AppState>().inviteCode;
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Invite code $code copied')));
  }

  List<Member> _mapMembers(AppState state) => [...state.members]
    ..sort(
      (a, b) =>
          a.isCurrentUser == b.isCurrentUser ? 0 : (a.isCurrentUser ? -1 : 1),
    );

  Widget _buildMap() {
    final state = context.watch<AppState>();
    final selected = state.selectedMember;
    return osm.FlutterMap(
      mapController: _osmController,
      options: osm.MapOptions(
        initialCenter: _initialCenter(state),
        initialZoom: state.currentUserOrNull?.position == null ? 3 : 15,
        minZoom: 2,
        maxZoom: 18,
        onMapReady: () => _mapReady = true,
        onTap: (_, _) => state.selectMember(null),
        onPositionChanged: _onPositionChanged,
        interactionOptions: const osm.InteractionOptions(
          flags: osm.InteractiveFlag.all,
        ),
      ),
      children: [
        osm.TileLayer(
          urlTemplate: _tilesUrl,
          userAgentPackageName: 'com.locmate.locmate',
          tileBuilder: state.mapDark ? osm.darkModeTileBuilder : null,
        ),
        osm.CircleLayer(
          circles: [
            for (final place in state.places)
              osm.CircleMarker(
                point: place.point,
                radius: place.radiusMeters,
                useRadiusInMeter: true,
                color: placeColor(place.icon).withValues(alpha: 0.11),
                borderColor: placeColor(place.icon).withValues(alpha: 0.55),
                borderStrokeWidth: 2,
              ),
          ],
        ),
        osm.MarkerLayer(
          markers: [
            for (final place in state.places)
              osm.Marker(
                point: place.point,
                width: 36,
                height: 36,
                child: _PlaceMarker(place: place),
              ),
            for (final member in _mapMembers(state))
              if (member.position != null)
                osm.Marker(
                  point: member.position!,
                  width: 88,
                  height: 104,
                  alignment: Alignment.topCenter,
                  child: _MemberMarker(
                    member: member,
                    selected: member.id == selected?.id,
                    onTap: () => _focusMember(member),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapControls() {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      right: 12,
      bottom: _panelHeight + 16,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _rotation,
                builder: (context, rotation, _) => IconButton(
                  onPressed: _resetNorth,
                  tooltip: 'Reset north (${rotation.round()}°)',
                  icon: Icon(
                    Icons.explore_outlined,
                    color: rotation.abs() < 1
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _zoomBy(1),
                tooltip: 'Zoom in',
                icon: const Icon(Icons.add_rounded),
              ),
              IconButton(
                onPressed: () => _zoomBy(-1),
                tooltip: 'Zoom out',
                icon: const Icon(Icons.remove_rounded),
              ),
              IconButton(
                onPressed: _fitAll,
                tooltip: 'Show everyone',
                icon: const Icon(Icons.groups_outlined),
              ),
              IconButton(
                onPressed: _recenter,
                tooltip: _following ? 'Following you' : 'Follow me',
                icon: Icon(
                  Icons.my_location_rounded,
                  color: _following ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = state.selectedMember;
    _syncFollow(state);

    final me = state.currentUserOrNull;
    final showMovement =
        _following &&
        me != null &&
        state.locationError == null &&
        state.syncError == null;

    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _MapHeader(
                state: state,
                onToggleSharing: () => _toggleSharing(context),
                onOpenCircle: _openCircleInfo,
              ),
            ),
          ),
          if (showMovement)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 84,
              left: 14,
              child: _MovementBadge(member: me),
            ),
          if (state.locationError != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 86,
              left: 14,
              right: 14,
              child: _LocationBanner(
                message: state.locationError!,
                onAction: () => state.openSystemLocationSettings(),
              ),
            ),
          if (state.syncError != null)
            Positioned(
              top:
                  MediaQuery.paddingOf(context).top +
                  (state.locationError != null ? 146 : 86),
              left: 14,
              right: 14,
              child: _SyncErrorBanner(
                message: state.syncError!,
                onRetry: state.refreshData,
              ),
            ),
          _buildMapControls(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _SizeReporter(
                onSize: (size) {
                  if (!mounted || (size.height - _panelHeight).abs() < 1) {
                    return;
                  }
                  setState(() => _panelHeight = size.height);
                },
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: _CirclePanel(
                    state: state,
                    selected: selected,
                    minimized: _panelMinimized,
                    onToggleMinimized: () =>
                        setState(() => _panelMinimized = !_panelMinimized),
                    onSelect: _focusMember,
                    onRecenter: _recenter,
                    onFitAll: _fitAll,
                    onOpenChat: _openChat,
                    onOpenDetails: _openDetails,
                    onOpenCircle: _openCircleInfo,
                    onCopyInvite: _copyInviteCode,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reports its child's size after layout so the map can pad around the
/// floating panel.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _lastSize) return;
    _lastSize = size;
    final reported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(reported));
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.state,
    required this.onToggleSharing,
    required this.onOpenCircle,
  });

  final AppState state;
  final VoidCallback onToggleSharing;
  final VoidCallback onOpenCircle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sharing = state.sharingEnabled;
    final memberCount = state.members.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2536) : LocmateColors.line,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const LocmateLogo(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: onOpenCircle,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.circleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sharing
                                ? LocmateColors.safe
                                : LocmateColors.warning,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            sharing
                                ? '$memberCount member${memberCount == 1 ? '' : 's'} · '
                                      '${state.sharingCount} sharing'
                                : 'Location sharing paused',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: onOpenCircle,
              tooltip: 'Circle info',
              icon: Icon(
                Icons.info_outline_rounded,
                size: 21,
                color: scheme.onSurfaceVariant,
              ),
            ),
            IconButton(
              onPressed: onToggleSharing,
              tooltip: sharing
                  ? 'Pause location sharing'
                  : 'Resume location sharing',
              style: IconButton.styleFrom(
                backgroundColor: sharing
                    ? scheme.primary.withValues(alpha: 0.1)
                    : LocmateColors.warning.withValues(alpha: 0.14),
                padding: const EdgeInsets.all(9),
              ),
              icon: Icon(
                sharing
                    ? Icons.share_location_rounded
                    : Icons.location_disabled_rounded,
                size: 20,
                color: sharing ? scheme.primary : LocmateColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.message, required this.onAction});

  final String message;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            const Icon(
              Icons.location_off_rounded,
              size: 19,
              color: LocmateColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 11.5, height: 1.35),
              ),
            ),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 34),
              ),
              child: const Text('Fix'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncErrorBanner extends StatelessWidget {
  const _SyncErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4F4),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 18,
              color: LocmateColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: LocmateColors.danger,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CirclePanel extends StatelessWidget {
  const _CirclePanel({
    required this.state,
    required this.selected,
    required this.minimized,
    required this.onToggleMinimized,
    required this.onSelect,
    required this.onRecenter,
    required this.onFitAll,
    required this.onOpenChat,
    required this.onOpenDetails,
    required this.onOpenCircle,
    required this.onCopyInvite,
  });

  final AppState state;
  final Member? selected;
  final bool minimized;
  final VoidCallback onToggleMinimized;
  final ValueChanged<Member> onSelect;
  final VoidCallback onRecenter;
  final VoidCallback onFitAll;
  final VoidCallback onOpenChat;
  final ValueChanged<Member> onOpenDetails;
  final VoidCallback onOpenCircle;
  final VoidCallback onCopyInvite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alone = state.members.length <= 1;

    final header = Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onToggleMinimized,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Circle',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${state.members.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _MapToolButton(
          icon: Icons.groups_rounded,
          tooltip: 'Circle info',
          onTap: onOpenCircle,
        ),
        const SizedBox(width: 6),
        _MapToolButton(
          icon: Icons.layers_outlined,
          tooltip: state.mapDark ? 'Light map' : 'Dark map',
          onTap: state.toggleMapDark,
        ),
        const SizedBox(width: 6),
        _MapToolButton(
          icon: Icons.zoom_out_map_rounded,
          tooltip: 'Show everyone',
          onTap: onFitAll,
        ),
        const SizedBox(width: 6),
        _MapToolButton(
          icon: Icons.my_location_rounded,
          tooltip: 'Recenter on me',
          onTap: onRecenter,
        ),
        const SizedBox(width: 6),
        _MapToolButton(
          icon: minimized
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          tooltip: minimized ? 'Expand panel' : 'Minimize panel',
          onTap: onToggleMinimized,
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2536) : LocmateColors.line,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggleMinimized,
            onVerticalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if ((v > 200 && !minimized) || (v < -200 && minimized)) {
                onToggleMinimized();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          header,
          const SizedBox(height: 8),
          // When minimized the panel collapses to this slim bar so the whole
          // map is visible. The handle and the expand chevron open it again.
          if (!minimized) ...[
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.members.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final member = state.members[index];
                  return _MemberCard(
                    member: member,
                    status: state.statusFor(member),
                    selected: member.id == selected?.id,
                    onTap: () => onSelect(member),
                  );
                },
              ),
            ),
            if (alone && state.inviteCode.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InviteRow(code: state.inviteCode, onCopy: onCopyInvite),
            ],
            if (selected != null) ...[
              const SizedBox(height: 10),
              _SelectedBar(
                state: state,
                member: selected!,
                onOpenChat: onOpenChat,
                onOpenDetails: () => onOpenDetails(selected!),
              ),
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Map data © OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 9,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedBar extends StatelessWidget {
  const _SelectedBar({
    required this.state,
    required this.member,
    required this.onOpenChat,
    required this.onOpenDetails,
  });

  final AppState state;
  final Member member;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            member.isSharing || member.isCurrentUser
                ? Icons.place_rounded
                : Icons.location_off_rounded,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.statusFor(member),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  state.locationLabelFor(member),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onOpenChat,
            tooltip: 'Message circle',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 20,
              color: scheme.primary,
            ),
          ),
          FilledButton(
            onPressed: onOpenDetails,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Details'),
          ),
        ],
      ),
    );
  }
}

/// Large, easy-to-read battery level: big icon plus bold percentage.
class _LargeBattery extends StatelessWidget {
  const _LargeBattery({required this.level});

  final double? level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = level;
    final color = value == null ? LocmateColors.muted : batteryColor(value);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          value == null ? Icons.battery_unknown_rounded : batteryIcon(value),
          size: 26,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          value == null ? '—' : '${value.round()}%',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: value != null && value <= 20 ? color : scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.group_add_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Invite code  ',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: code,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: const Text('Copy'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapToolButton extends StatelessWidget {
  const _MapToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 19, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final Member member;
  final String status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 156,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: isDark ? 0.2 : 0.08)
            : scheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.03),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 1.6,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MemberAvatar(member: member, size: 36),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        member.isCurrentUser
                            ? '${member.name} (You)'
                            : member.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                _LargeBattery(level: member.battery),
                if (member.battery != null) ...[
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (member.battery! / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        batteryColor(member.battery!),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberMarker extends StatelessWidget {
  const _MemberMarker({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final Member member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final live = member.isSharing && !member.isStale;
    final moving = live && member.motion != MotionState.stationary;
    final motionIcon = switch (member.motion) {
      MotionState.driving => Icons.directions_car_rounded,
      MotionState.walking => Icons.directions_walk_rounded,
      MotionState.stationary => null,
    };
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              MemberAvatar(
                member: member,
                size: selected ? 50 : 44,
                showBattery: false,
              ),
              if (moving && member.heading != null)
                Positioned(
                  top: -6,
                  left: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: Transform.rotate(
                      angle: member.heading! * math.pi / 180,
                      child: const Icon(
                        Icons.navigation_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (member.isCurrentUser)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: const Icon(
                      Icons.near_me_rounded,
                      size: 9,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxWidth: 84),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 7,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              member.isCurrentUser ? 'You' : member.firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (moving && motionIcon != null)
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(motionIcon, size: 10, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(
                    member.motion == MotionState.driving
                        ? '${(member.speed * 2.23694).round()} mph'
                        : 'Moving',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceMarker extends StatelessWidget {
  const _PlaceMarker({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = placeColor(place.icon);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(placeIcon(place.icon), size: 18, color: color),
    );
  }
}

/// Floating chip that makes live follow mode and movement obvious while the
/// camera is tracking someone who is walking or driving.
class _MovementBadge extends StatelessWidget {
  const _MovementBadge({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final driving = member.motion == MotionState.driving;
    final icon = switch (member.motion) {
      MotionState.driving => Icons.directions_car_rounded,
      MotionState.walking => Icons.directions_walk_rounded,
      MotionState.stationary => Icons.my_location_rounded,
    };
    final label = switch (member.motion) {
      MotionState.driving =>
        'Following · ${(member.speed * 2.23694).round()} mph',
      MotionState.walking => 'Following · Walking',
      MotionState.stationary => 'Following you',
    };
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(14),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (driving) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Interpolates coordinates so live location updates glide instead of jump.
class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) => LatLng(
    begin!.latitude + (end!.latitude - begin!.latitude) * t,
    begin!.longitude + (end!.longitude - begin!.longitude) * t,
  );
}

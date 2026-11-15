import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../models/member.dart';
import '../models/place.dart';
import '../theme.dart';
import '../utils.dart';

/// Draws Google Maps marker bitmaps for members and places.
///
/// Google Maps markers are images, not widgets, so the avatar look from
/// [MemberAvatar] is painted onto a canvas. Results are cached by their visual
/// inputs, so a marker is only redrawn when something it shows changes.
class MapMarkerIcons {
  MapMarkerIcons({required this.pixelRatio});

  final double pixelRatio;
  final Map<String, BitmapDescriptor> _cache = {};

  static const double _memberWidth = 92;
  static const double _labelHeight = 22;

  /// Key describing everything a member marker shows.
  static String memberKey(Member member, {required bool selected}) => [
    'm',
    member.id,
    member.initials,
    member.colorIndex,
    member.isCurrentUser ? 'You' : member.firstName,
    member.isCurrentUser,
    member.isSharing,
    selected,
  ].join('|');

  static String placeKey(Place place) => 'p|${place.icon}';

  BitmapDescriptor? cached(String key) => _cache[key];

  Future<BitmapDescriptor> member(
    Member member, {
    required bool selected,
  }) async {
    final key = memberKey(member, selected: selected);
    final hit = _cache[key];
    if (hit != null) return hit;
    final bytes = await _paint(
      const Size(_memberWidth, 50 + 6 + _labelHeight + 4),
      (canvas, size) => _paintMember(canvas, size, member, selected),
    );
    return _cache[key] = BitmapDescriptor.bytes(
      bytes,
      imagePixelRatio: pixelRatio,
    );
  }

  Future<BitmapDescriptor> place(Place place) async {
    final key = placeKey(place);
    final hit = _cache[key];
    if (hit != null) return hit;
    final bytes = await _paint(
      const Size(40, 40),
      (canvas, size) => _paintPlace(canvas, size, place),
    );
    return _cache[key] = BitmapDescriptor.bytes(
      bytes,
      imagePixelRatio: pixelRatio,
    );
  }

  Future<Uint8List> _paint(
    Size size,
    void Function(Canvas canvas, Size size) painter,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    painter(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * pixelRatio).ceil(),
      (size.height * pixelRatio).ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    return data!.buffer.asUint8List();
  }

  void _paintMember(Canvas canvas, Size size, Member member, bool selected) {
    final diameter = selected ? 50.0 : 44.0;
    final center = Offset(size.width / 2, 4 + 50 / 2);
    final radius = diameter / 2;

    // Shadow.
    canvas.drawCircle(
      center.translate(0, 2.5),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // White ring.
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    // Gradient fill.
    final inner = Rect.fromCircle(center: center, radius: radius * 0.88);
    canvas.drawCircle(
      center,
      radius * 0.88,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(member.color, Colors.white, 0.12)!,
            Color.lerp(member.color, Colors.black, 0.14)!,
          ],
        ).createShader(inner),
    );
    if (selected) {
      canvas.drawCircle(
        center,
        radius + 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = LocmateColors.primary,
      );
    }
    _paintText(
      canvas,
      member.initials,
      center,
      TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: diameter * 0.34,
      ),
    );

    if (member.isCurrentUser) {
      final badge = center.translate(radius * 0.72, -radius * 0.72);
      canvas.drawCircle(badge, 9, Paint()..color = Colors.white);
      canvas.drawCircle(badge, 7.6, Paint()..color = LocmateColors.primary);
      _paintIcon(canvas, Icons.near_me_rounded, badge, 10, Colors.white);
    } else if (!member.isSharing) {
      final badge = center.translate(radius * 0.72, radius * 0.72);
      canvas.drawCircle(badge, 9, Paint()..color = Colors.white);
      _paintIcon(
        canvas,
        Icons.location_disabled_rounded,
        badge,
        12,
        LocmateColors.muted,
      );
    }

    // Name label.
    final label = member.isCurrentUser ? 'You' : member.firstName;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: LocmateColors.ink,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width - 18);
    final labelWidth = painter.width + 16;
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, 4 + 50 + 6 + _labelHeight / 2),
        width: labelWidth,
        height: _labelHeight - 2,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      labelRect.shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(labelRect, Paint()..color = Colors.white);
    if (selected) {
      canvas.drawRRect(
        labelRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = LocmateColors.primary,
      );
    }
    painter.paint(
      canvas,
      labelRect.center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  void _paintPlace(Canvas canvas, Size size, Place place) {
    final color = placeColor(place.icon);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      const Radius.circular(11),
    );
    canvas.drawRRect(
      rect.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.35),
    );
    _paintIcon(canvas, placeIcon(place.icon), rect.center, 20, color);
  }

  void _paintIcon(
    Canvas canvas,
    IconData icon,
    Offset center,
    double size,
    Color color,
  ) {
    _paintText(
      canvas,
      String.fromCharCode(icon.codePoint),
      center,
      TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: size,
        color: color,
        height: 1,
      ),
    );
  }

  void _paintText(Canvas canvas, String text, Offset center, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }
}

/// Google Maps night style used when "Dark map style" is on.
const String googleMapDarkStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d1b26"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8f8aa3"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1d1b26"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#3a3548"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#262232"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1f2a26"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2e2a3b"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1d1b26"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#43395c"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#c4bdd9"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2a2637"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#121722"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4b5572"}]}
]
''';

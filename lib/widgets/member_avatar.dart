import 'package:flutter/material.dart';

import '../models/member.dart';
import '../theme.dart';
import '../utils.dart';

class BatteryBadge extends StatelessWidget {
  const BatteryBadge({
    super.key,
    required this.level,
    this.dense = false,
  });

  final double level;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = batteryColor(level);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 5 : 8,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191622) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF332D42) : Colors.white,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            batteryIcon(level),
            size: dense ? 11 : 14,
            color: color,
          ),
          SizedBox(width: dense ? 1 : 2),
          Text(
            '${level.round()}%',
            style: TextStyle(
              fontSize: dense ? 9 : 11,
              fontWeight: FontWeight.w700,
              color: isDark ? scheme.onSurface : LocmateColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    this.size = 44,
    this.showBattery = false,
  });

  final Member member;
  final double size;
  final bool showBattery;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ringColor = isDark ? const Color(0xFF191622) : Colors.white;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(member.color, Colors.white, 0.12)!,
                Color.lerp(member.color, Colors.black, 0.14)!,
              ],
            ),
            border: Border.all(color: ringColor, width: size * 0.06),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: size * 0.18,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            member.initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.34,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (showBattery)
          Positioned(
            right: -4,
            bottom: -4,
            child: BatteryBadge(level: member.battery, dense: true),
          ),
      ],
    );
  }
}

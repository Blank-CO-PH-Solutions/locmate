import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vibration/vibration.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Listens to [AppState.notices] and shows each one as a toast in the top-left
/// corner while vibrating the phone.
class NoticeToastHost extends StatefulWidget {
  const NoticeToastHost({
    super.key,
    required this.notices,
    required this.child,
    this.vibrate = true,
  });

  final Stream<AppNotice> notices;
  final Widget child;
  final bool vibrate;

  @override
  State<NoticeToastHost> createState() => _NoticeToastHostState();
}

class _NoticeToastHostState extends State<NoticeToastHost> {
  StreamSubscription<AppNotice>? _sub;
  final List<_ToastEntry> _toasts = [];
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.notices.listen(_show);
  }

  @override
  void didUpdateWidget(NoticeToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notices != widget.notices) {
      _sub?.cancel();
      _sub = widget.notices.listen(_show);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final toast in _toasts) {
      toast.timer.cancel();
    }
    super.dispose();
  }

  void _show(AppNotice notice) {
    if (!mounted) return;
    final id = _nextId++;
    final timer = Timer(
      Duration(seconds: notice.urgent ? 8 : 4),
      () => _dismiss(id),
    );
    setState(() {
      _toasts.insert(0, _ToastEntry(id, notice, timer));
      while (_toasts.length > 3) {
        _toasts.removeLast().timer.cancel();
      }
    });
    if (widget.vibrate) unawaited(_buzz(notice.urgent));
  }

  void _dismiss(int id) {
    if (!mounted) return;
    setState(() {
      _toasts.removeWhere((toast) {
        if (toast.id != id) return false;
        toast.timer.cancel();
        return true;
      });
    });
  }

  Future<void> _buzz(bool urgent) async {
    try {
      if (!kIsWeb && await Vibration.hasVibrator()) {
        await Vibration.vibrate(
          pattern: urgent
              ? const [0, 400, 150, 400, 150, 600]
              : const [0, 120, 80, 120],
        );
        return;
      }
    } catch (_) {}
    await HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            bottom: false,
            right: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (width - 24).clamp(0, 380).toDouble(),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final toast in _toasts)
                      Padding(
                        key: ValueKey(toast.id),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _NoticeToast(
                          notice: toast.notice,
                          onDismiss: () => _dismiss(toast.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToastEntry {
  _ToastEntry(this.id, this.notice, this.timer);

  final int id;
  final AppNotice notice;
  final Timer timer;
}

class _NoticeToast extends StatelessWidget {
  const _NoticeToast({required this.notice, required this.onDismiss});

  final AppNotice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = notice.urgent
        ? LocmateColors.danger
        : (notice.color ?? scheme.primary);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(-24 * (1 - t), 0),
          child: child,
        ),
      ),
      child: Material(
        color: notice.urgent
            ? (isDark ? const Color(0xFF3A1717) : const Color(0xFFFFF1F1))
            : scheme.surface,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onDismiss,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(notice.icon, size: 19, color: accent),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (notice.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          notice.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

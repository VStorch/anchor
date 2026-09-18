import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// A page with an add button that steps aside while its list scrolls down —
/// at rest the button sits over the right column, where amounts and statuses
/// are — and comes back when the list scrolls up, reaches its end, cannot
/// scroll at all, or the content changes ([contentKey]: another month, filter
/// or reload). Once the list leaves the top the extended button shrinks to its
/// icon.
///
/// [builder] receives the button to put in `Scaffold.floatingActionButton`,
/// so the Scaffold keeps placing it above the system insets and snackbars.
class ScrollAwareFab extends StatefulWidget {
  const ScrollAwareFab({
    super.key,
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.builder,
    this.contentKey,
    this.extended = true,
    this.visible = true,
  });

  final String heroTag;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Widget Function(BuildContext context, Widget? fab) builder;
  final Object? contentKey;

  /// False keeps the button round from the start, as the table needs.
  final bool extended;

  /// False leaves the page with no button at all.
  final bool visible;

  @override
  State<ScrollAwareFab> createState() => _ScrollAwareFabState();
}

class _ScrollAwareFabState extends State<ScrollAwareFab> {
  static const double _collapseAfter = 8;

  bool _hidden = false;
  bool _scrolled = false;

  @override
  void didUpdateWidget(ScrollAwareFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentKey != widget.contentKey ||
        oldWidget.visible != widget.visible) {
      _hidden = false;
      _scrolled = false;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    _follow(
      notification.metrics,
      direction: notification is UserScrollNotification
          ? notification.direction
          : null,
    );
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    _follow(notification.metrics);
    return false;
  }

  void _follow(ScrollMetrics metrics, {ScrollDirection? direction}) {
    if (metrics.axis != Axis.vertical) return;

    var hidden = _hidden;
    if (direction == ScrollDirection.reverse) hidden = true;
    if (direction == ScrollDirection.forward) hidden = false;
    if (metrics.maxScrollExtent <= 0 || metrics.extentAfter <= 0) {
      hidden = false;
    }
    final scrolled = metrics.pixels > _collapseAfter;

    if (hidden == _hidden && scrolled == _scrolled) return;
    void apply() {
      if (!mounted) return;
      setState(() {
        _hidden = hidden;
        _scrolled = scrolled;
      });
    }

    // Metrics arrive during layout, when no rebuild may be scheduled.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.builder(context, widget.visible ? _fab(context) : null),
      ),
    );
  }

  Widget _fab(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final extended = widget.extended && !_scrolled;

    return IgnorePointer(
      ignoring: _hidden,
      child: ExcludeSemantics(
        excluding: _hidden,
        child: AnimatedSlide(
          offset: _hidden ? const Offset(0, 2) : Offset.zero,
          duration: duration,
          child: AnimatedScale(
            scale: _hidden ? 0 : 1,
            duration: duration,
            child: FloatingActionButton.extended(
              heroTag: widget.heroTag,
              onPressed: widget.onPressed,
              isExtended: extended,
              tooltip: extended ? null : widget.label,
              icon: Icon(widget.icon),
              label: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}

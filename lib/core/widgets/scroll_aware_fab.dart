import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A page body with its add button, which steps aside while the list scrolls
/// down — at rest it sits over the right column, where amounts and statuses
/// are — and comes back when the list scrolls up or reaches its end. Once the
/// list leaves the top the extended button shrinks to its icon.
class ScrollAwareFab extends StatefulWidget {
  const ScrollAwareFab({
    super.key,
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.child,
    this.extended = true,
  });

  final String heroTag;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Widget child;

  /// False keeps the button round from the start, as the table needs.
  final bool extended;

  @override
  State<ScrollAwareFab> createState() => _ScrollAwareFabState();
}

class _ScrollAwareFabState extends State<ScrollAwareFab> {
  static const double _collapseAfter = 8;

  bool _hidden = false;
  bool _scrolled = false;

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;

    var hidden = _hidden;
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) hidden = true;
      if (notification.direction == ScrollDirection.forward) hidden = false;
    }
    if (metrics.extentAfter <= 0) hidden = false;
    final scrolled = metrics.pixels > _collapseAfter;

    if (hidden != _hidden || scrolled != _scrolled) {
      setState(() {
        _hidden = hidden;
        _scrolled = scrolled;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final extended = widget.extended && !_scrolled;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: IgnorePointer(
            ignoring: _hidden,
            child: AnimatedSlide(
              offset: _hidden ? const Offset(0, 2) : Offset.zero,
              duration: duration,
              child: AnimatedOpacity(
                opacity: _hidden ? 0 : 1,
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
        ),
      ],
    );
  }
}

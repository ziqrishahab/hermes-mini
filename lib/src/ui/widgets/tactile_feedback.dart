import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A wrapper widget that provides a fluid, tactile physical spring press animation.
/// Suitable for Neumorphic buttons, cards, and list rows.
class TactileContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;
  final HitTestBehavior behavior;

  const TactileContainer({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.975,
    this.duration = const Duration(milliseconds: 130),
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<TactileContainer> createState() => _TactileContainerState();
}

class _TactileContainerState extends State<TactileContainer> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) {
      return widget.child;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: _isPressed ? Curves.easeOutQuad : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

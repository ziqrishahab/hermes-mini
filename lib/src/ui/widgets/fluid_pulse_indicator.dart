import 'package:flutter/material.dart';

/// Minimalist breathing heartbeat pulse beacon dot.
/// Perfect for indicating live gateway connection or real-time agent status.
class FluidPulseIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final bool animate;

  const FluidPulseIndicator({
    super.key,
    required this.color,
    this.size = 7.0,
    this.animate = true,
  });

  @override
  State<FluidPulseIndicator> createState() => _FluidPulseIndicatorState();
}

class _FluidPulseIndicatorState extends State<FluidPulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuad),
    );

    if (widget.animate) {
      _ctrl.repeat();
    }
  }

  @override
  void didUpdateWidget(FluidPulseIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return SizedBox(
          width: widget.size * 2.2,
          height: widget.size * 2.2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.animate)
                Opacity(
                  opacity: (1.0 - _pulse.value) * 0.45,
                  child: Container(
                    width: widget.size + (_pulse.value * widget.size * 1.2),
                    height: widget.size + (_pulse.value * widget.size * 1.2),
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

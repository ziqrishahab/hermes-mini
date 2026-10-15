import "package:flutter/material.dart";
import "../../theme.dart";

/// A sleek, modern Neumorphic Liquid Capsule Progress Indicator
/// replacing traditional rigid circular spinners with a fluid ambient light sweep.
class HermesLoadingIndicator extends StatefulWidget {
  final double width;
  final double height;
  final String? statusText;

  const HermesLoadingIndicator({
    super.key,
    this.width = 140,
    this.height = 5,
    this.statusText,
  });

  @override
  State<HermesLoadingIndicator> createState() => _HermesLoadingIndicatorState();
}

class _HermesLoadingIndicatorState extends State<HermesLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Recessed Capsule Track
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: HermesTokens.bgTertiary,
            borderRadius: BorderRadius.circular(widget.height),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                offset: Offset(0, 1.5),
                blurRadius: 2,
              ),
              BoxShadow(
                color: Colors.white,
                offset: Offset(0, -1),
                blurRadius: 1.5,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              const runnerWidthRatio = 0.35;
              final runnerWidth = widget.width * runnerWidthRatio;
              final availableTrack = widget.width - runnerWidth;
              final leftOffset = _animation.value * availableTrack;

              return Stack(
                children: [
                  Positioned(
                    left: leftOffset,
                    top: 0,
                    bottom: 0,
                    width: runnerWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.height),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF38BDF8), // Electric cyan-blue (matches wing glow)
                            HermesTokens.accent, // Hermes purple
                            Color(0xFF818CF8), // Soft violet
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: HermesTokens.accent.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.statusText != null) ...[
          const SizedBox(height: 10),
          Text(
            widget.statusText!,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: HermesTokens.textMuted,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme.dart';

enum HermesToastType { success, error, info }

class HermesToast {
  static void show(
    BuildContext context, {
    required String message,
    HermesToastType type = HermesToastType.info,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final IconData icon;
    final Color iconColor;

    switch (type) {
      case HermesToastType.success:
        icon = Icons.check_circle_rounded;
        iconColor = HermesTokens.success;
        break;
      case HermesToastType.error:
        icon = Icons.error_outline_rounded;
        iconColor = HermesTokens.error;
        break;
      case HermesToastType.info:
        icon = Icons.info_outline_rounded;
        iconColor = HermesTokens.accent;
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        padding: EdgeInsets.zero,
        duration: duration,
        content: Center(
          child: _FluidToastEntrance(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: HermesTokens.bgElevated,
                borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
                border: Border.all(color: HermesTokens.borderBright, width: 0.8),
                boxShadow: const [
                  BoxShadow(
                    color: HermesTokens.neuShadowLight,
                    offset: Offset(-3, -3),
                    blurRadius: 7,
                  ),
                  BoxShadow(
                    color: HermesTokens.neuShadowDark,
                    offset: Offset(3, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: HermesTokens.bgTertiary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 14, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: HermesTokens.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FluidToastEntrance extends StatefulWidget {
  final Widget child;
  const _FluidToastEntrance({required this.child});

  @override
  State<_FluidToastEntrance> createState() => _FluidToastEntranceState();
}

class _FluidToastEntranceState extends State<_FluidToastEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

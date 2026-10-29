import 'package:flutter/material.dart';
import '../../../../theme.dart';

String formatCapabilityCategory(String cat) {
  if (cat.isEmpty) return "General";
  return cat.replaceAll("-", " ").split(" ").map((w) {
    if (w.isEmpty) return "";
    return w[0].toUpperCase() + w.substring(1);
  }).join(" ");
}

IconData getIconForCapabilitySkill(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('image')) return Icons.image_outlined;
  if (lower.contains('translation') || lower.contains('translate')) return Icons.translate_outlined;
  if (lower.contains('privacy') || lower.contains('shield')) return Icons.shield_outlined;
  if (lower.contains('code') ||
      lower.contains('programming') ||
      lower.contains('codex') ||
      lower.contains('claude')) {
    return Icons.code_outlined;
  }
  if (lower.contains('logic') || lower.contains('reason') || lower.contains('agent')) {
    return Icons.psychology_outlined;
  }
  if (lower.contains('core') || lower.contains('engine') || lower.contains('computer')) {
    return Icons.computer_outlined;
  }
  if (lower.contains('speed') || lower.contains('turbo')) return Icons.speed_outlined;
  if (lower.contains('video') || lower.contains('media')) return Icons.movie_outlined;
  if (lower.contains('web') || lower.contains('search')) return Icons.language_outlined;
  return Icons.build_outlined;
}

class CapabilitiesEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool showRetry;
  final VoidCallback? onRetry;

  const CapabilitiesEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.showRetry = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: NeumorphicDecoration.raised(radius: 16),
                  child: Icon(icon, size: 26, color: HermesTokens.accent),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HermesTokens.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: HermesTokens.textMuted,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (showRetry && onRetry != null) ...[
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: onRetry,
                    child: Text("Retry", style: TextStyle(color: HermesTokens.accentText)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CapabilitiesConnectionFailedState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const CapabilitiesConnectionFailedState(
    this.error,
    this.onRetry, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: NeumorphicDecoration.raised(radius: 16),
                  child: const Icon(Icons.wifi_off_rounded, size: 26, color: HermesTokens.error),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Connection Failed",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HermesTokens.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  error,
                  style: TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: onRetry,
                  child: Text("Retry", style: TextStyle(color: HermesTokens.accentText)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

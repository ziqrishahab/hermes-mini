import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

enum RemoteSetupMethod { tailscale, cloudflare }

class HermesSetupGuide extends StatefulWidget {
  final bool compact;

  const HermesSetupGuide({
    super.key,
    this.compact = false,
  });

  @override
  State<HermesSetupGuide> createState() => _HermesSetupGuideState();
}

class _HermesSetupGuideState extends State<HermesSetupGuide> {
  RemoteSetupMethod _selectedMethod = RemoteSetupMethod.tailscale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Method Selector Tabs
        Container(
          padding: const EdgeInsets.all(4),
          decoration: NeumorphicDecoration.recessed(radius: 12),
          child: Row(
            children: [
              _buildMethodTab(RemoteSetupMethod.tailscale, "Tailscale (Mesh VPN)"),
              _buildMethodTab(RemoteSetupMethod.cloudflare, "Cloudflare Tunnel"),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Method Details
        if (_selectedMethod == RemoteSetupMethod.tailscale)
          _buildTailscaleGuide()
        else
          _buildCloudflareGuide(),
      ],
    );
  }

  Widget _buildMethodTab(RemoteSetupMethod method, String label) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedMethod = method);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: isSelected
              ? NeumorphicDecoration.switcherThumb(radius: 8)
              : null,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? HermesTokens.accent : HermesTokens.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTailscaleGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader("1. Install Tailscale"),
        const SizedBox(height: 4),
        Text(
          "Install Tailscale on both your host computer and Android phone. Sign in with the same account (Google, GitHub, etc.) on both devices.",
          style: TextStyle(
            fontSize: 11,
            color: HermesTokens.textSecondary,
            height: 1.45,
          ),
        ),

        const SizedBox(height: 12),

        _buildStepHeader("2. Start Hermes Host"),
        const SizedBox(height: 4),
        Text(
          "Run Hermes daemon on your host computer:",
          style: TextStyle(
            fontSize: 11,
            color: HermesTokens.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        _buildCodeBox("hermes dashboard --port 9119"),

        const SizedBox(height: 12),

        _buildStepHeader("3. Connect using Tailscale IP"),
        const SizedBox(height: 4),
        Text(
          "Copy your host computer's 100.x.y.z Tailscale IP from the Tailscale app, then connect using:",
          style: TextStyle(
            fontSize: 11,
            color: HermesTokens.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        _buildCodeBox("http://100.x.y.z:9119"),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: HermesTokens.bgTertiary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HermesTokens.border, width: 0.8),
          ),
          child: Text(
            "Advantage: End-to-end encrypted direct connection. Works over 4G/5G anywhere in the world without exposing ports to the public internet.",
            style: TextStyle(
              fontSize: 10,
              color: HermesTokens.textMuted,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCloudflareGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader("1. Run Cloudflare Quick Tunnel"),
        const SizedBox(height: 4),
        Text(
          "Run this single command on your host computer terminal. No account or domain required:",
          style: TextStyle(
            fontSize: 11,
            color: HermesTokens.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        _buildCodeBox("cloudflared tunnel --url http://localhost:9119"),

        const SizedBox(height: 12),

        _buildStepHeader("2. Copy Public HTTPS URL"),
        const SizedBox(height: 4),
        Text(
          "Cloudflared will output a public HTTPS link in your terminal, for example:",
          style: TextStyle(
            fontSize: 11,
            color: HermesTokens.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        _buildCodeBox("https://xxxx.trycloudflare.com"),

        const SizedBox(height: 12),

        _buildStepHeader("3. Connect from Mobile"),
        const SizedBox(height: 4),
        Text(
          "Paste the HTTPS URL into the Gateway URL field above and enter your Hermes password.",
          style: TextStyle(
            fontSize: 11,
            color: HermesTokens.textSecondary,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: HermesTokens.bgTertiary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HermesTokens.border, width: 0.8),
          ),
          child: Text(
            "Advantage: Instant public HTTPS tunnel without installing client apps on your phone or configuring router firewall.",
            style: TextStyle(
              fontSize: 10,
              color: HermesTokens.textMuted,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: HermesTokens.textPrimary,
      ),
    );
  }

  Widget _buildCodeBox(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: HermesTokens.bgTertiary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HermesTokens.borderBright, width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              code,
              style: TextStyle(
                fontFamily: "monospace",
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: HermesTokens.accent,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Copied to clipboard"),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.copy_rounded,
                size: 13,
                color: HermesTokens.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

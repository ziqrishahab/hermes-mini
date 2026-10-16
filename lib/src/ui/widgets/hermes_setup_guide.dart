import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

enum TargetOs { windows, linux, macos }

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
  TargetOs _selectedOs = TargetOs.windows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // OS Selector Tabs
        Container(
          padding: const EdgeInsets.all(4),
          decoration: NeumorphicDecoration.recessed(radius: 10),
          child: Row(
            children: [
              _buildOsTab(TargetOs.windows, "Windows"),
              _buildOsTab(TargetOs.linux, "Linux"),
              _buildOsTab(TargetOs.macos, "macOS"),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Step 1: Start Server
        _buildStepHeader("1. Start Hermes Host"),
        const SizedBox(height: 4),
        const Text(
          "Run this in your host terminal to listen for LAN connections:",
          style: TextStyle(
            fontSize: 11,
            color: HermesTokens.textMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        _buildCodeBox("hermes dashboard --host 0.0.0.0 --port 9119"),

        const SizedBox(height: 12),

        // Step 2: Get Host IP
        _buildStepHeader("2. Find Host Local IP"),
        const SizedBox(height: 4),
        Text(
          _getIpInstruction(),
          style: const TextStyle(
            fontSize: 11,
            color: HermesTokens.textMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        _buildCodeBox(_getIpCommand()),

        const SizedBox(height: 12),

        // Step 3: Connect
        _buildStepHeader("3. Connect from Mobile"),
        const SizedBox(height: 4),
        const Text(
          "Ensure phone and host are on the same Wi-Fi.\n"
          "- Gateway URL: http://<host-ip>:9119\n"
          "- Password: Your Hermes dashboard password",
          style: TextStyle(
            fontSize: 11,
            color: HermesTokens.textMuted,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 10),

        // Remote Access note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: HermesTokens.bgTertiary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HermesTokens.border, width: 0.8),
          ),
          child: const Text(
            "Remote Access: When away from home Wi-Fi, use Tailscale (http://100.x.y.z:9119) or a secure tunnel.",
            style: TextStyle(
              fontSize: 10,
              color: HermesTokens.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOsTab(TargetOs os, String label) {
    final isSelected = _selectedOs == os;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedOs = os);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? HermesTokens.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: HermesTokens.accent.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : HermesTokens.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: HermesTokens.textPrimary,
      ),
    );
  }

  String _getIpInstruction() {
    switch (_selectedOs) {
      case TargetOs.windows:
        return "Open PowerShell or Command Prompt, run this command, and look for 'IPv4 Address' under your Wi-Fi adapter:";
      case TargetOs.linux:
        return "Run this in your terminal to display your local network IP:";
      case TargetOs.macos:
        return "Run this in Terminal to print your active Wi-Fi IP address (or check System Settings > Wi-Fi > Details):";
    }
  }

  String _getIpCommand() {
    switch (_selectedOs) {
      case TargetOs.windows:
        return "ipconfig";
      case TargetOs.linux:
        return "hostname -I";
      case TargetOs.macos:
        return "ipconfig getifaddr en0";
    }
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
              style: const TextStyle(
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
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
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

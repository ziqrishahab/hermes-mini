import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'accessibility_service.dart';

class MobileActionResult {
  final bool success;
  final String action;
  final String message;
  final Map<String, dynamic>? data;

  const MobileActionResult({
    required this.success,
    required this.action,
    required this.message,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'action': action,
        'message': message,
        if (data != null) 'data': data,
      };

  @override
  String toString() => jsonEncode(toJson());
}

class MobileActionRequest {
  final String action;
  final Map<String, dynamic> params;
  final String rawMatch;

  const MobileActionRequest({
    required this.action,
    required this.params,
    required this.rawMatch,
  });
}

class DeviceExecutorService {
  static const String deviceCapabilityPrompt = '''
[DEVICE CONTROL CAPABILITY]
You can execute automated actions on the user's Android phone. To execute an action, output a JSON block in this exact format:
```mobile_action
{"action": "send_whatsapp", "phone": "08123456789", "message": "Halo bep"}
```
Supported actions:
- `send_whatsapp`: Sends a WhatsApp message automatically. Params: "phone" (optional if opening active chat), "message".
- `click`: Clicks an element on screen. Params: "text" (button text or label), "id" (view resource ID), or "x" and "y" (screen coordinates).
- `type`: Types text into the currently active/focused input field. Param: "text".
- `read_screen`: Reads all active UI elements and visible text currently shown on screen.
- `global`: Performs Android system navigation. Param: "target" ("back", "home", "recents", "notifications", "lock").
- `swipe`: Swipes on screen. Params: "startX", "startY", "endX", "endY".
- `open_app`: Opens app. Target can be "youtube", "whatsapp", "maps", "spotify", "chrome", "settings", or app package name.
- `call`: Opens phone dialer. Param: "phone".
- `send_sms`: Sends SMS. Params: "phone", "message".
- `open_url`: Opens web link. Param: "url".
- `get_connectivity`: Checks network (Wi-Fi, 4G/5G Cellular, Offline).
- `get_device_info`: Returns Android OS and device specs.
- `get_clipboard` / `set_clipboard`: Reads or writes text to device clipboard.
- `vibrate`: Vibrates the device.
- `check_accessibility`: Checks if Android Accessibility Service is active for zero-touch automation.
''';

  /// Extracts all embedded mobile action blocks from text.
  static List<MobileActionRequest> extractActions(String text) {
    final results = <MobileActionRequest>[];

    // 1. Matches ```mobile_action ... ```
    final mdRegex = RegExp(r'```mobile_action\s*([\s\S]*?)```', caseSensitive: false);
    for (final m in mdRegex.allMatches(text)) {
      final jsonStr = m.group(1)?.trim() ?? '';
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          results.add(MobileActionRequest(
            action: (decoded['action'] ?? '').toString().toLowerCase().trim(),
            params: decoded,
            rawMatch: m.group(0) ?? '',
          ));
        }
      } catch (_) {}
    }

    // 2. Matches <mobile_action>...</mobile_action>
    final tagRegex = RegExp(r'<mobile_action>([\s\S]*?)</mobile_action>', caseSensitive: false);
    for (final m in tagRegex.allMatches(text)) {
      final jsonStr = m.group(1)?.trim() ?? '';
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          results.add(MobileActionRequest(
            action: (decoded['action'] ?? '').toString().toLowerCase().trim(),
            params: decoded,
            rawMatch: m.group(0) ?? '',
          ));
        }
      } catch (_) {}
    }

    return results;
  }

  /// Executes a given mobile action natively on the device.
  static Future<MobileActionResult> execute(String action, Map<String, dynamic> params) async {
    final act = action.toLowerCase().trim();

    switch (act) {
      case 'send_whatsapp':
      case 'whatsapp':
        final phone = (params['phone'] ?? params['number'] ?? params['target'] ?? '').toString().trim();
        final message = (params['message'] ?? params['text'] ?? params['body'] ?? '').toString();
        return await _sendWhatsApp(phone: phone, message: message);

      case 'click':
        return await _click(params);

      case 'type':
      case 'input_text':
        final text = (params['text'] ?? params['content'] ?? '').toString();
        return await _typeText(text);

      case 'read_screen':
      case 'screen':
        return await _readScreen();

      case 'global':
      case 'navigate':
        final target = (params['target'] ?? params['action'] ?? 'back').toString().toLowerCase().trim();
        return await _performGlobal(target);

      case 'swipe':
        return await _swipe(params);

      case 'check_accessibility':
      case 'a11y':
        final isEnabled = await AccessibilityService.isEnabled();
        return MobileActionResult(
          success: isEnabled,
          action: 'check_accessibility',
          message: isEnabled
              ? 'Hermes Accessibility Service is ACTIVE. Full zero-touch automation is ready.'
              : 'Hermes Accessibility Service is NOT ACTIVE. Please enable it in Settings for full zero-touch automation.',
          data: {'is_active': isEnabled},
        );

      case 'enable_accessibility':
        final ok = await AccessibilityService.openSettings();
        return MobileActionResult(
          success: ok,
          action: 'enable_accessibility',
          message: ok
              ? 'Opened Android Accessibility Settings. Please turn on "Hermes Mobile Agent".'
              : 'Failed to open Accessibility Settings',
        );

      case 'call':
      case 'dial':
        final phone = (params['phone'] ?? params['number'] ?? params['target'] ?? '').toString().trim();
        return await _callPhone(phone);

      case 'send_sms':
      case 'sms':
        final phone = (params['phone'] ?? params['number'] ?? params['target'] ?? '').toString().trim();
        final message = (params['message'] ?? params['text'] ?? params['body'] ?? '').toString();
        return await _sendSms(phone: phone, message: message);

      case 'open_app':
        final target = (params['target'] ?? params['app'] ?? params['package'] ?? '').toString().toLowerCase().trim();
        return await _openApp(target);

      case 'open_url':
        final urlStr = (params['url'] ?? params['target'] ?? '').toString().trim();
        return await _openUrl(urlStr);

      case 'get_connectivity':
      case 'network':
        return await _getConnectivity();

      case 'get_device_info':
      case 'device_info':
        return await _getDeviceInfo();

      case 'get_clipboard':
        return await _getClipboard();

      case 'set_clipboard':
        final text = (params['text'] ?? params['content'] ?? '').toString();
        return await _setClipboard(text);

      case 'vibrate':
        return await _vibrate();

      default:
        return MobileActionResult(
          success: false,
          action: action,
          message: 'Unsupported device action "$action"',
        );
    }
  }

  static Future<MobileActionResult> _sendWhatsApp({required String phone, required String message}) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('+')) {
      cleanPhone = cleanPhone.substring(1);
    }

    final encodedMsg = Uri.encodeComponent(message);
    Uri targetUri;
    if (cleanPhone.isNotEmpty) {
      targetUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMsg');
    } else {
      targetUri = Uri.parse('whatsapp://send?text=$encodedMsg');
    }

    bool launched = false;
    try {
      launched = await launchUrl(targetUri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!launched) {
      // Fallback wa.me
      final fallbackUrl = cleanPhone.isNotEmpty
          ? 'https://wa.me/$cleanPhone?text=$encodedMsg'
          : 'https://wa.me/?text=$encodedMsg';
      try {
        launched = await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    if (!launched) {
      return const MobileActionResult(
        success: false,
        action: 'send_whatsapp',
        message: 'Could not open WhatsApp. Ensure WhatsApp is installed on device.',
      );
    }

    // Check if Accessibility Service is active for automated zero-touch click
    final a11yActive = await AccessibilityService.isEnabled();
    if (a11yActive) {
      // Wait for WhatsApp window to render
      await Future.delayed(const Duration(milliseconds: 950));

      // Try clicking WhatsApp Send button by ID or text
      bool clicked = await AccessibilityService.clickById('com.whatsapp:id/send');
      if (!clicked) {
        clicked = await AccessibilityService.clickByText('Send', exact: true);
      }
      if (!clicked) {
        clicked = await AccessibilityService.clickByText('Kirim', exact: true);
      }

      if (clicked) {
        // Wait for WhatsApp animation to deliver message, then return to Hermes app
        await Future.delayed(const Duration(milliseconds: 750));
        await AccessibilityService.performGlobal('back');
      }

      return MobileActionResult(
        success: true,
        action: 'send_whatsapp',
        message: clicked
            ? 'WhatsApp message to $cleanPhone sent automatically via Accessibility Service'
            : 'WhatsApp opened with prefilled message (Please tap send)',
        data: {'phone': cleanPhone, 'auto_clicked': clicked},
      );
    }

    return MobileActionResult(
      success: true,
      action: 'send_whatsapp',
      message: 'WhatsApp opened with prefilled message. (Tip: Turn on Accessibility Service in Settings for zero-touch auto send).',
      data: {'phone': cleanPhone, 'auto_clicked': false},
    );
  }

  static Future<MobileActionResult> _click(Map<String, dynamic> params) async {
    final a11yActive = await AccessibilityService.isEnabled();
    if (!a11yActive) {
      return const MobileActionResult(
        success: false,
        action: 'click',
        message: 'Accessibility Service is not enabled. Run "/device a11y" to enable it in Settings.',
      );
    }

    final text = (params['text'] ?? '').toString().trim();
    final id = (params['id'] ?? params['viewId'] ?? '').toString().trim();
    final x = (params['x'] is num) ? (params['x'] as num).toDouble() : null;
    final y = (params['y'] is num) ? (params['y'] as num).toDouble() : null;

    if (id.isNotEmpty) {
      final ok = await AccessibilityService.clickById(id);
      return MobileActionResult(
        success: ok,
        action: 'click',
        message: ok ? 'Clicked view ID "$id"' : 'Could not find view ID "$id"',
      );
    }

    if (text.isNotEmpty) {
      final ok = await AccessibilityService.clickByText(text);
      return MobileActionResult(
        success: ok,
        action: 'click',
        message: ok ? 'Clicked text "$text"' : 'Could not find element with text "$text"',
      );
    }

    if (x != null && y != null) {
      final ok = await AccessibilityService.clickCoords(x, y);
      return MobileActionResult(
        success: ok,
        action: 'click',
        message: ok ? 'Clicked coordinates ($x, $y)' : 'Click gesture failed',
      );
    }

    return const MobileActionResult(
      success: false,
      action: 'click',
      message: 'No click target specified (provide "text", "id", or "x, y")',
    );
  }

  static Future<MobileActionResult> _typeText(String text) async {
    final a11yActive = await AccessibilityService.isEnabled();
    if (!a11yActive) {
      return const MobileActionResult(
        success: false,
        action: 'type',
        message: 'Accessibility Service is not enabled. Run "/device a11y" to enable it in Settings.',
      );
    }

    final ok = await AccessibilityService.inputText(text);
    return MobileActionResult(
      success: ok,
      action: 'type',
      message: ok ? 'Text entered successfully' : 'No active input field found to type into',
      data: {'text': text},
    );
  }

  static Future<MobileActionResult> _readScreen() async {
    final a11yActive = await AccessibilityService.isEnabled();
    if (!a11yActive) {
      return const MobileActionResult(
        success: false,
        action: 'read_screen',
        message: 'Accessibility Service is not enabled. Run "/device a11y" to enable it in Settings.',
      );
    }

    final elements = await AccessibilityService.readScreen();
    final texts = elements
        .map((e) => (e['text'] ?? e['desc'] ?? '').toString().trim())
        .where((t) => t.isNotEmpty)
        .toList();

    return MobileActionResult(
      success: true,
      action: 'read_screen',
      message: 'Screen contains ${elements.length} elements (${texts.length} readable text nodes)',
      data: {
        'count': elements.length,
        'visible_texts': texts.take(30).toList(),
        'elements': elements.take(25).toList(),
      },
    );
  }

  static Future<MobileActionResult> _performGlobal(String action) async {
    final a11yActive = await AccessibilityService.isEnabled();
    if (!a11yActive) {
      return const MobileActionResult(
        success: false,
        action: 'global',
        message: 'Accessibility Service is not enabled. Run "/device a11y" to enable it in Settings.',
      );
    }

    final ok = await AccessibilityService.performGlobal(action);
    return MobileActionResult(
      success: ok,
      action: 'global',
      message: ok ? 'Global action "$action" performed' : 'Global action "$action" failed',
    );
  }

  static Future<MobileActionResult> _swipe(Map<String, dynamic> params) async {
    final a11yActive = await AccessibilityService.isEnabled();
    if (!a11yActive) {
      return const MobileActionResult(
        success: false,
        action: 'swipe',
        message: 'Accessibility Service is not enabled. Run "/device a11y" to enable it in Settings.',
      );
    }

    final startX = ((params['startX'] ?? params['x1'] ?? 500) as num).toDouble();
    final startY = ((params['startY'] ?? params['y1'] ?? 1200) as num).toDouble();
    final endX = ((params['endX'] ?? params['x2'] ?? 500) as num).toDouble();
    final endY = ((params['endY'] ?? params['y2'] ?? 400) as num).toDouble();
    final duration = ((params['durationMs'] ?? 300) as num).toInt();

    final ok = await AccessibilityService.swipe(startX, startY, endX, endY, durationMs: duration);
    return MobileActionResult(
      success: ok,
      action: 'swipe',
      message: ok ? 'Swipe performed from ($startX, $startY) to ($endX, $endY)' : 'Swipe failed',
    );
  }

  static Future<MobileActionResult> _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      return const MobileActionResult(
        success: false,
        action: 'call',
        message: 'No phone number specified',
      );
    }
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return MobileActionResult(
        success: ok,
        action: 'call',
        message: ok ? 'Dialer opened for "$cleanPhone"' : 'Failed to launch dialer',
      );
    } catch (e) {
      return MobileActionResult(success: false, action: 'call', message: 'Error: $e');
    }
  }

  static Future<MobileActionResult> _sendSms({required String phone, required String message}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return MobileActionResult(
        success: ok,
        action: 'send_sms',
        message: ok ? 'SMS opened with draft message' : 'Failed to open SMS app',
      );
    } catch (e) {
      return MobileActionResult(success: false, action: 'send_sms', message: 'Error: $e');
    }
  }

  static Future<MobileActionResult> _openApp(String target) async {
    if (target.isEmpty) {
      return const MobileActionResult(
        success: false,
        action: 'open_app',
        message: 'No app target specified',
      );
    }

    final lower = target.toLowerCase();
    Uri? uriToLaunch;

    if (lower.contains('youtube')) {
      uriToLaunch = Uri.parse('vnd.youtube://');
    } else if (lower.contains('whatsapp')) {
      uriToLaunch = Uri.parse('whatsapp://send');
    } else if (lower.contains('map')) {
      uriToLaunch = Uri.parse('geo:0,0?q=');
    } else if (lower.contains('spotify')) {
      uriToLaunch = Uri.parse('spotify://');
    } else if (lower.contains('chrome') || lower.contains('browser')) {
      uriToLaunch = Uri.parse('https://www.google.com');
    } else if (lower.contains('settings')) {
      uriToLaunch = Uri.parse('package:com.android.settings');
    } else if (lower.startsWith('http://') || lower.startsWith('https://')) {
      uriToLaunch = Uri.parse(target);
    } else if (lower.contains('://')) {
      uriToLaunch = Uri.parse(target);
    }

    if (uriToLaunch != null) {
      try {
        final ok = await launchUrl(uriToLaunch, mode: LaunchMode.externalApplication);
        if (ok) {
          return MobileActionResult(
            success: true,
            action: 'open_app',
            message: 'App "$target" launched successfully via intent',
          );
        }
      } catch (_) {}
    }

    // Fallbacks
    Uri? fallbackUri;
    if (lower.contains('youtube')) {
      fallbackUri = Uri.parse('https://www.youtube.com');
    } else if (lower.contains('whatsapp')) {
      fallbackUri = Uri.parse('https://wa.me/');
    } else if (lower.contains('map')) {
      fallbackUri = Uri.parse('https://maps.google.com');
    } else if (lower.contains('spotify')) {
      fallbackUri = Uri.parse('https://open.spotify.com');
    }

    if (fallbackUri != null) {
      try {
        final ok = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        if (ok) {
          return MobileActionResult(
            success: true,
            action: 'open_app',
            message: 'Opened "$target" via web fallback',
          );
        }
      } catch (_) {}
    }

    return MobileActionResult(
      success: false,
      action: 'open_app',
      message: 'Could not launch app "$target". Make sure the app is installed.',
    );
  }

  static Future<MobileActionResult> _openUrl(String urlStr) async {
    if (urlStr.isEmpty) {
      return const MobileActionResult(
        success: false,
        action: 'open_url',
        message: 'No URL specified',
      );
    }
    String normalized = urlStr;
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    try {
      final uri = Uri.parse(normalized);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) {
        return MobileActionResult(
          success: true,
          action: 'open_url',
          message: 'URL "$normalized" opened successfully',
        );
      }
    } catch (e) {
      return MobileActionResult(
        success: false,
        action: 'open_url',
        message: 'Failed to open URL: $e',
      );
    }
    return MobileActionResult(
      success: false,
      action: 'open_url',
      message: 'Could not open URL "$normalized"',
    );
  }

  static Future<MobileActionResult> _getConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      final hasWifi = result.contains(ConnectivityResult.wifi);
      final hasMobile = result.contains(ConnectivityResult.mobile);
      final hasEthernet = result.contains(ConnectivityResult.ethernet);
      final isNone = result.contains(ConnectivityResult.none) || result.isEmpty;

      String type = 'offline';
      if (hasWifi) {
        type = 'Wi-Fi';
      } else if (hasMobile) {
        type = 'Cellular Mobile Data (4G/5G)';
      } else if (hasEthernet) {
        type = 'Ethernet';
      }

      return MobileActionResult(
        success: !isNone,
        action: 'get_connectivity',
        message: isNone ? 'Device is offline' : 'Connected via $type',
        data: {
          'type': type,
          'is_connected': !isNone,
          'has_wifi': hasWifi,
          'has_cellular': hasMobile,
        },
      );
    } catch (e) {
      return MobileActionResult(
        success: false,
        action: 'get_connectivity',
        message: 'Failed to check connectivity: $e',
      );
    }
  }

  static Future<MobileActionResult> _getDeviceInfo() async {
    final os = Platform.operatingSystem;
    final osVersion = Platform.operatingSystemVersion;
    final locale = Platform.localeName;
    final numProcessors = Platform.numberOfProcessors;

    return MobileActionResult(
      success: true,
      action: 'get_device_info',
      message: 'Device info retrieved',
      data: {
        'os': os,
        'os_version': osVersion,
        'locale': locale,
        'cpu_cores': numProcessors,
        'is_android': Platform.isAndroid,
      },
    );
  }

  static Future<MobileActionResult> _getClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      return MobileActionResult(
        success: true,
        action: 'get_clipboard',
        message: text.isNotEmpty ? 'Clipboard content read' : 'Clipboard is empty',
        data: {'content': text},
      );
    } catch (e) {
      return MobileActionResult(
        success: false,
        action: 'get_clipboard',
        message: 'Failed to read clipboard: $e',
      );
    }
  }

  static Future<MobileActionResult> _setClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return MobileActionResult(
        success: true,
        action: 'set_clipboard',
        message: 'Text copied to device clipboard',
        data: {'length': text.length},
      );
    } catch (e) {
      return MobileActionResult(
        success: false,
        action: 'set_clipboard',
        message: 'Failed to set clipboard: $e',
      );
    }
  }

  static Future<MobileActionResult> _vibrate() async {
    try {
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
      return const MobileActionResult(
        success: true,
        action: 'vibrate',
        message: 'Device haptic vibration triggered',
      );
    } catch (e) {
      return MobileActionResult(
        success: false,
        action: 'vibrate',
        message: 'Failed to vibrate: $e',
      );
    }
  }
}

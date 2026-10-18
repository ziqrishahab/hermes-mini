import 'dart:async';
import 'package:flutter/services.dart';

class AccessibilityService {
  static const MethodChannel _channel = MethodChannel('com.hermesmobile/accessibility');

  /// Checks if the Hermes Accessibility Service is active.
  static Future<bool> isEnabled() async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android Accessibility Settings page so user can turn on Hermes.
  static Future<bool> openSettings() async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('openAccessibilitySettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Clicks a view on screen matching text or content description.
  static Future<bool> clickByText(String text, {bool exact = false}) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('clickByText', {
        'text': text,
        'exact': exact,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Clicks a view by resource ID (e.g. "com.whatsapp:id/send").
  static Future<bool> clickById(String viewId) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('clickById', {
        'viewId': viewId,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Performs a click gesture at coordinates (x, y).
  static Future<bool> clickCoords(double x, double y) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('clickCoords', {
        'x': x,
        'y': y,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Performs a swipe/drag gesture from start to end coordinates.
  static Future<bool> swipe(double startX, double startY, double endX, double endY, {int durationMs = 300}) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('swipe', {
        'startX': startX,
        'startY': startY,
        'endX': endX,
        'endY': endY,
        'durationMs': durationMs,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Inputs text into the currently focused text field or active input node.
  static Future<bool> inputText(String text) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('inputText', {
        'text': text,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sets text targeting a specific view identified by hint/text/id.
  static Future<bool> setTextByTarget(String target, String text) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('setTextByTarget', {
        'target': target,
        'text': text,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Performs global action: "back", "home", "recents", "notifications", "quick_settings", "lock".
  static Future<bool> performGlobal(String action) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('performGlobal', {
        'action': action,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Reads all active UI elements on screen.
  static Future<List<Map<String, dynamic>>> readScreen() async {
    try {
      final dynamic raw = await _channel.invokeMethod('readScreen');
      if (raw is List) {
        return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

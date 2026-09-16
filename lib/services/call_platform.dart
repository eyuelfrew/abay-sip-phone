import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android call service bridge (foreground + notifications).
class CallPlatform {
  CallPlatform._();

  static const _channel = MethodChannel('abay/call');
  static bool _ready = false;

  static void Function()? onAnswerFromNotification;
  static void Function()? onRejectFromNotification;

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    if (_ready) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'answer':
          onAnswerFromNotification?.call();
        case 'reject':
          onRejectFromNotification?.call();
      }
    });
    try {
      await _channel.invokeMethod('setAnswerHandler');
      await _channel.invokeMethod('setRejectHandler');
      _ready = true;
    } catch (e) {
      debugPrint('CallPlatform init failed: $e');
    }
  }

  static Future<void> startService() async {
    if (!Platform.isAndroid) return;
    await init();
    try {
      await _channel.invokeMethod('startService');
    } catch (e) {
      debugPrint('startService: $e');
    }
  }

  static Future<void> stopService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopService');
    } catch (_) {}
  }

  static Future<void> showRegistered(String title, String text) async {
    if (!Platform.isAndroid) return;
    await init();
    try {
      await _channel.invokeMethod('registered', {'title': title, 'text': text});
    } catch (e) {
      debugPrint('showRegistered: $e');
    }
  }

  static Future<void> showIncoming(String title, String text) async {
    if (!Platform.isAndroid) return;
    await init();
    try {
      await _channel.invokeMethod('incoming', {'title': title, 'text': text});
    } catch (e) {
      debugPrint('showIncoming: $e');
    }
  }

  static Future<void> showOngoing(String title, String text) async {
    if (!Platform.isAndroid) return;
    await init();
    try {
      await _channel.invokeMethod('ongoing', {'title': title, 'text': text});
    } catch (e) {
      debugPrint('showOngoing: $e');
    }
  }

  static Future<void> clearCallNotifications() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('clearCall');
    } catch (_) {}
  }

  static Future<void> bringToForeground() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('bringToForeground');
    } catch (_) {}
  }
}

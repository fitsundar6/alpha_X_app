import 'package:flutter/services.dart';

/// Service responsible for rest timer audio attention beeps and completion alerts.
/// Uses Flutter's SystemSound framework to respect native phone volume and notification settings,
/// avoiding annoying loops while providing crisp audio feedback.
class RestTimerSoundService {
  // Test hook callbacks for deterministic automated verification
  static void Function(int second)? testBeepCallback;
  static void Function()? testCompletionCallback;

  static void resetTestHooks() {
    testBeepCallback = null;
    testCompletionCallback = null;
  }

  /// Play short countdown attention beep (5, 4, 3, 2, 1)
  static void playCountdownBeep(int secondRemaining) {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    testBeepCallback?.call(secondRemaining);
  }

  /// Play distinct rest completion alert sound when timer reaches 0
  static void playCompletionSound() {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
    testCompletionCallback?.call();
  }
}

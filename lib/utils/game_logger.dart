import 'package:flutter/foundation.dart';

/// Centralized logging utility with different log levels
/// Provides better debugging capabilities and production-ready logging
class GameLogger {
  static const String _tag = 'ClubBlackout';
  
  static bool get isDebugMode => kDebugMode;

  /// Log informational messages
  static void info(String message, {String? context}) {
    if (isDebugMode) {
      final contextStr = context != null ? '[$context] ' : '';
      debugPrint('ℹ️ $_tag: $contextStr$message');
    }
  }

  /// Log warning messages
  static void warning(String message, {String? context, Object? error}) {
    final contextStr = context != null ? '[$context] ' : '';
    final errorStr = error != null ? '\nError: $error' : '';
    debugPrint('⚠️ $_tag: $contextStr$message$errorStr');
  }

  /// Log error messages with optional stack trace
  static void error(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final contextStr = context != null ? '[$context] ' : '';
    final errorStr = error != null ? '\nError: $error' : '';
    final stackStr = stackTrace != null ? '\nStack trace:\n$stackTrace' : '';
    debugPrint('❌ $_tag: $contextStr$message$errorStr$stackStr');
  }

  /// Log debug messages (only in debug mode)
  static void debug(String message, {String? context}) {
    if (isDebugMode) {
      final contextStr = context != null ? '[$context] ' : '';
      debugPrint('🐛 $_tag: $contextStr$message');
    }
  }

  /// Log game events (gameplay-specific logging)
  static void gameEvent(String event, {Map<String, dynamic>? data}) {
    if (isDebugMode) {
      final dataStr = data != null ? '\nData: $data' : '';
      debugPrint('🎮 $_tag [GameEvent]: $event$dataStr');
    }
  }

  /// Log ability resolutions
  static void ability(String abilityName, {
    required String source,
    List<String>? targets,
    bool? success,
  }) {
    if (isDebugMode) {
      final targetStr = targets != null ? ' → ${targets.join(', ')}' : '';
      final successStr = success != null ? ' [${success ? '✓' : '✗'}]' : '';
      debugPrint('⚡ $_tag [Ability]: $abilityName from $source$targetStr$successStr');
    }
  }

  /// Log state transitions
  static void stateTransition(String from, String to, {String? reason}) {
    if (isDebugMode) {
      final reasonStr = reason != null ? ' ($reason)' : '';
      debugPrint('🔄 $_tag [State]: $from → $to$reasonStr');
    }
  }

  /// Log performance metrics
  static void performance(String operation, Duration duration) {
    if (isDebugMode) {
      debugPrint('⏱️ $_tag [Performance]: $operation took ${duration.inMilliseconds}ms');
    }
  }
}

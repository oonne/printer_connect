import 'dart:developer' as developer;

import 'package:printer_connect/src/printer_connect.g.dart';

class UniversalLogger {
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _cyan = '\x1B[36m';
  static const String _gray = '\x1B[37m';
  static const String _magenta = '\x1B[35m';

  BleLogLevel _currentLogLevel = BleLogLevel.warning;

  UniversalLogger._();

  static final UniversalLogger instance = UniversalLogger._();

  BleLogLevel get currentLogLevel => _currentLogLevel;

  void setLogLevel(BleLogLevel level) {
    _currentLogLevel = level;
  }

  bool _allows(BleLogLevel level) {
    const levels = [
      BleLogLevel.verbose,
      BleLogLevel.debug,
      BleLogLevel.info,
      BleLogLevel.warning,
      BleLogLevel.error,
      BleLogLevel.none,
    ];
    return levels.indexOf(level) <= levels.indexOf(_currentLogLevel);
  }

  String _withTimestamp(String message) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    return '[$timestamp] $message';
  }

  void logError(String message, [String? name, dynamic error, StackTrace? stackTrace, bool withTimestamp = true]) {
    if (!_allows(BleLogLevel.error)) return;
    final msg = withTimestamp ? _withTimestamp(message) : message;
    final coloredMsg = '$_red$msg$_reset';
    developer.log(
      coloredMsg,
      name: name ?? 'UniversalBle',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void logWarning(String message, [String? name, bool withTimestamp = true]) {
    if (!_allows(BleLogLevel.warning)) return;
    final msg = withTimestamp ? _withTimestamp(message) : message;
    final coloredMsg = '$_yellow$msg$_reset';
    developer.log(coloredMsg, name: name ?? 'UniversalBle');
  }

  void logInfo(String message, [String? name, bool withTimestamp = true]) {
    if (!_allows(BleLogLevel.info)) return;
    final msg = withTimestamp ? _withTimestamp(message) : message;
    final coloredMsg = '$_green$msg$_reset';
    developer.log(coloredMsg, name: name ?? 'UniversalBle');
  }

  void logDebug(String message, [String? name, bool withTimestamp = true]) {
    if (!_allows(BleLogLevel.debug)) return;
    final msg = withTimestamp ? _withTimestamp(message) : message;
    final coloredMsg = '$_cyan$msg$_reset';
    developer.log(coloredMsg, name: name ?? 'UniversalBle');
  }

  void logVerbose(String message, [String? name, bool withTimestamp = true]) {
    if (!_allows(BleLogLevel.verbose)) return;
    final msg = withTimestamp ? _withTimestamp(message) : message;
    final coloredMsg = '$_gray$msg$_reset';
    developer.log(coloredMsg, name: name ?? 'UniversalBle');
  }

  void logWtf(String message, [String? name, dynamic error, StackTrace? stackTrace, bool withTimestamp = true]) {
    if (!_allows(BleLogLevel.verbose)) return;
    final msg = withTimestamp ? _withTimestamp(message) : message;
    final coloredMsg = '$_magenta$msg$_reset';
    developer.log(
      coloredMsg,
      name: name ?? 'UniversalBle',
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void logE(String message, [String? name, dynamic error, StackTrace? stackTrace, bool withTimestamp = true]) {
    instance.logError(message, name, error, stackTrace, withTimestamp);
  }

  static void logW(String message, [String? name, bool withTimestamp = true]) {
    instance.logWarning(message, name, withTimestamp);
  }

  static void logI(String message, [String? name, bool withTimestamp = true]) {
    instance.logInfo(message, name, withTimestamp);
  }

  static void logD(String message, [String? name, bool withTimestamp = true]) {
    instance.logDebug(message, name, withTimestamp);
  }

  static void logV(String message, [String? name, bool withTimestamp = true]) {
    instance.logVerbose(message, name, withTimestamp);
  }

  static void logF(String message, [String? name, dynamic error, StackTrace? stackTrace, bool withTimestamp = true]) {
    instance.logWtf(message, name, error, stackTrace, withTimestamp);
  }
}

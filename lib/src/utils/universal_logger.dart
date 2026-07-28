import 'dart:developer' as developer;

import 'package:printer_connect/src/printer_connect.g.dart';

class UniversalLogger {
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
      BleLogLevel.wtf,
      BleLogLevel.none,
    ];
    return levels.indexOf(level) >= levels.indexOf(_currentLogLevel);
  }

  String _withTimestamp(String message) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    return '[$timestamp] $message';
  }

  void logError(String message, [String? name, dynamic error, StackTrace? stackTrace]) {
    if (!_allows(BleLogLevel.error)) return;
    final msg = _withTimestamp(message);
    developer.log(
      msg,
      name: name ?? 'UniversalBle',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void logWarning(String message, [String? name]) {
    if (!_allows(BleLogLevel.warning)) return;
    final msg = _withTimestamp(message);
    developer.log(msg, name: name ?? 'UniversalBle');
  }

  void logInfo(String message, [String? name]) {
    if (!_allows(BleLogLevel.info)) return;
    final msg = _withTimestamp(message);
    developer.log(msg, name: name ?? 'UniversalBle');
  }

  void logDebug(String message, [String? name]) {
    if (!_allows(BleLogLevel.debug)) return;
    final msg = _withTimestamp(message);
    developer.log(msg, name: name ?? 'UniversalBle');
  }

  void logVerbose(String message, [String? name]) {
    if (!_allows(BleLogLevel.verbose)) return;
    final msg = _withTimestamp(message);
    developer.log(msg, name: name ?? 'UniversalBle');
  }
}

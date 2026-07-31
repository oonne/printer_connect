import 'dart:developer';

import 'package:printer_connect/src/printer_connect.g.dart';

/// 通用日志工具
///
/// 日志级别体系（按严重程度从低到高）：
/// - [BleLogLevel.none]：不输出任何日志
/// - [BleLogLevel.verbose]：输出所有级别日志
/// - [BleLogLevel.debug]：输出 debug 及以上级别
/// - [BleLogLevel.info]：输出 info 及以上级别
/// - [BleLogLevel.warning]：输出 warning 及以上级别
/// - [BleLogLevel.error]：仅输出 error 级别
///
/// 通过 [_allows] 方法比较当前日志级别与目标级别，
/// 只有目标级别 >= 当前设置级别时才会输出日志。
class UniversalLogger {
  static BleLogLevel _currentLogLevel = BleLogLevel.none;

  static BleLogLevel get currentLogLevel => _currentLogLevel;

  /// 设置当前日志级别
  static void setLogLevel(BleLogLevel logLevel) {
    _currentLogLevel = logLevel;
  }

  /// 输出 error 级别日志（红色）
  static void logError(String message, {bool withTimestamp = false}) {
    if (!_allows(BleLogLevel.error)) return;
    if (withTimestamp) {
      final ts = DateTime.now().toIso8601String();
      message = "[$ts] $message";
    }
    log('\x1B[31m$message\x1B[0m', name: 'PrinterConnect:ERROR');
  }

  /// 输出 warning 级别日志（黄色）
  static void logWarning(String message, {bool withTimestamp = false}) {
    if (!_allows(BleLogLevel.warning)) return;
    if (withTimestamp) {
      final ts = DateTime.now().toIso8601String();
      message = "[$ts] $message";
    }
    log('\x1B[33m$message\x1B[0m', name: 'PrinterConnect:WARN');
  }

  /// 输出 warning 级别日志的简写形式
  static void logW(String message, [String? name, bool withTimestamp = true]) {
    logWarning(message, withTimestamp: withTimestamp);
  }

  /// 输出 info 级别日志
  static void logInfo(String message, {bool withTimestamp = false}) {
    if (!_allows(BleLogLevel.info)) return;
    if (withTimestamp) {
      final ts = DateTime.now().toIso8601String();
      message = "[$ts] $message";
    }
    log(message.toString(), name: 'PrinterConnect:INFO');
  }

  /// 输出 debug 级别日志
  static void logDebug(String message, {bool withTimestamp = false}) {
    if (!_allows(BleLogLevel.debug)) return;
    if (withTimestamp) {
      final ts = DateTime.now().toIso8601String();
      message = "[$ts] $message";
    }
    log(message.toString(), name: 'PrinterConnect:DEBUG');
  }

  /// 输出 verbose 级别日志
  static void logVerbose(String message, {bool withTimestamp = false}) {
    if (!_allows(BleLogLevel.verbose)) return;
    if (withTimestamp) {
      final ts = DateTime.now().toIso8601String();
      message = "[$ts] $message";
    }
    log(message.toString(), name: 'PrinterConnect:VERBOSE');
  }

  /// 判断指定 [level] 是否应该输出日志
  ///
  /// 只有当 [level] 的索引 >= 当前日志级别的索引，且当前级别不为 none 时才允许输出。
  static bool _allows(BleLogLevel level) {
    return level.index <= _currentLogLevel.index &&
        _currentLogLevel != BleLogLevel.none;
  }
}
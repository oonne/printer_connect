import 'package:flutter/foundation.dart';

/// 蓝牙能力封装类
///
/// 提供各平台蓝牙功能支持情况的静态查询接口，
/// 包括系统 API、权限要求、蓝牙开关、已连接设备等。
class BleCapabilities {
  /// 是否需要运行时权限（Web、Windows、Linux 无需运行时权限）
  static bool requiresRuntimePermission =
      !_Platform.isWeb && !_Platform.isWindows && !_Platform.isLinux;

  /// 是否支持蓝牙开关 API（Web 和 Cupertino 平台不支持）
  static bool supportsBluetoothEnableApi =
      !_Platform.isWeb && !_Platform.isCupertino;

  /// 是否支持获取已连接设备 API
  static bool supportsConnectedDevicesApi = !_Platform.isWeb;

  /// 是否支持外围设备 API（Linux 不支持）
  static bool supportsPeripheralApi = !_Platform.isWeb && !_Platform.isLinux;

  /// 是否支持请求 MTU API
  static bool supportsRequestMtuApi = !_Platform.isWeb;

  /// 是否支持连接优先级 API（仅 Android）
  static bool supportsConnectionPriorityApi =
      !_Platform.isWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 是否支持连接参数更新事件上报（Android API 26+）
  static bool supportsConnectionParametersUpdates =
      !_Platform.isWeb && defaultTargetPlatform == TargetPlatform.android;
}

/// 平台检测辅助类
class _Platform {
  static bool isWeb = kIsWeb;
  static bool isIOS = !isWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool isMacos = !isWeb && defaultTargetPlatform == TargetPlatform.macOS;
  static bool isWindows =
      !isWeb && defaultTargetPlatform == TargetPlatform.windows;
  static bool isLinux = !isWeb && defaultTargetPlatform == TargetPlatform.linux;
  static bool get isCupertino => isIOS || isMacos;
}

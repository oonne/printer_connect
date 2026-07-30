import 'package:flutter/foundation.dart';

class BleCapabilities {
  static bool get supportsAllPairingKinds => _Platform.isAndroid;

  static bool get triggersConfirmOnlyPairing => _Platform.isIOS;

  static bool get hasSystemPairingApi =>
      !_Platform.isWeb &&
      (_Platform.isAndroid ||
          _Platform.isWindows ||
          _Platform.isLinux);

  static bool get requiresRuntimePermission =>
      _Platform.isAndroid || _Platform.isWeb;

  static bool get supportsBluetoothEnableApi => _Platform.isAndroid;

  static bool get supportsConnectedDevicesApi => !_Platform.isWeb;

  static bool get supportsPeripheralApi =>
      _Platform.isAndroid || _Platform.isIOS || _Platform.isMacOS;

  static bool get supportsRequestMtuApi => !_Platform.isWeb;

  static bool get supportsConnectionPriorityApi => _Platform.isAndroid;

  static bool get supportsConnectionParametersUpdates =>
      _Platform.isAndroid || _Platform.isIOS;
}

class _Platform {
  static bool get isWeb => kIsWeb;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
}
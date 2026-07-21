import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'printer_connect_platform_interface.dart';

/// An implementation of [PrinterConnectPlatform] that uses method channels.
class MethodChannelPrinterConnect extends PrinterConnectPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('printer_connect');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}

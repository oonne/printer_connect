import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'printer_connect_method_channel.dart';

abstract class PrinterConnectPlatform extends PlatformInterface {
  /// Constructs a PrinterConnectPlatform.
  PrinterConnectPlatform() : super(token: _token);

  static final Object _token = Object();

  static PrinterConnectPlatform _instance = MethodChannelPrinterConnect();

  /// The default instance of [PrinterConnectPlatform] to use.
  ///
  /// Defaults to [MethodChannelPrinterConnect].
  static PrinterConnectPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PrinterConnectPlatform] when
  /// they register themselves.
  static set instance(PrinterConnectPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}

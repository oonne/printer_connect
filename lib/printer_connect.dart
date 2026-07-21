
import 'printer_connect_platform_interface.dart';

class PrinterConnect {
  Future<String?> getPlatformVersion() {
    return PrinterConnectPlatform.instance.getPlatformVersion();
  }
}

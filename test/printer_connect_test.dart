import 'package:flutter_test/flutter_test.dart';
import 'package:printer_connect/printer_connect.dart';
import 'package:printer_connect/printer_connect_platform_interface.dart';
import 'package:printer_connect/printer_connect_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPrinterConnectPlatform
    with MockPlatformInterfaceMixin
    implements PrinterConnectPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final PrinterConnectPlatform initialPlatform = PrinterConnectPlatform.instance;

  test('$MethodChannelPrinterConnect is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPrinterConnect>());
  });

  test('getPlatformVersion', () async {
    PrinterConnect printerConnectPlugin = PrinterConnect();
    MockPrinterConnectPlatform fakePlatform = MockPrinterConnectPlatform();
    PrinterConnectPlatform.instance = fakePlatform;

    expect(await printerConnectPlugin.getPlatformVersion(), '42');
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:printer_connect/src/printer_connect.g.dart'
    show ConnectionPlatformConfig;
import 'package:printer_connect/printer_connect.dart';

class MockPrinterConnectPlatform extends PrinterConnectPlatform {
  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    return AvailabilityState.poweredOn;
  }

  @override
  Future<bool> enableBluetooth() async => true;

  @override
  Future<bool> disableBluetooth() async => true;

  @override
  Future<bool> hasPermissions({bool withAndroidFineLocation = false}) async =>
      true;

  @override
  Future<void> requestPermissions({bool withAndroidFineLocation = false}) async {}

  @override
  Future<void> startScan(
      {ScanFilter? scanFilter, PlatformConfig? platformConfig}) async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<bool> isScanning() async => false;

  @override
  Future<void> connect(String deviceId,
      {bool autoConnect = false,
      Duration? connectionTimeout,
      ConnectionPlatformConfig? platformConfig}) async {}

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<List<BleService>> discoverServices(
      String deviceId, bool withDescriptors) async => [];

  @override
  Future<void> setNotifiable(String deviceId, String service,
      String characteristic, BleInputProperty bleInputProperty) async {}

  @override
  Future<Uint8List> readValue(String deviceId, String service,
      String characteristic, {Duration? timeout}) async => Uint8List(0);

  @override
  Future<void> writeValue(String deviceId, String service,
      String characteristic, Uint8List value,
      BleOutputProperty bleOutputProperty) async {}

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async => expectedMtu;

  @override
  Future<int> readRssi(String deviceId) async => 0;

  @override
  Future<void> requestConnectionPriority(
      String deviceId, BleConnectionPriority priority) async {}

  @override
  Future<bool> isPaired(String deviceId) async => false;

  @override
  Future<bool> pair(String deviceId) async => false;

  @override
  Future<void> unpair(String deviceId) async {}

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async =>
      BleConnectionState.disconnected;

  @override
  Future<List<BleDevice>> getSystemDevices(
      List<String>? withServices) async => [];

  @override
  Future<void> setLogLevel(BleLogLevel logLevel) async {}

  @override
  bool receivesAdvertisements(String deviceId) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default instance is PigeonPrinterConnectPlatform', () {
    final platform = PrinterConnectPlatform.instance;
    expect(platform, isInstanceOf<PigeonPrinterConnectPlatform>());
  });

  test('getBluetoothAvailabilityState', () async {
    MockPrinterConnectPlatform fakePlatform = MockPrinterConnectPlatform();
    PrinterConnectPlatform.instance = fakePlatform;

    expect(await PrinterConnect.getBluetoothAvailabilityState(),
        AvailabilityState.poweredOn);
  });

  test('hasPermissions', () async {
    MockPrinterConnectPlatform fakePlatform = MockPrinterConnectPlatform();
    PrinterConnectPlatform.instance = fakePlatform;

    expect(await PrinterConnect.hasPermissions(), true);
  });

  test('isScanning', () async {
    MockPrinterConnectPlatform fakePlatform = MockPrinterConnectPlatform();
    PrinterConnectPlatform.instance = fakePlatform;

    expect(await PrinterConnect.isScanning(), false);
  });
}
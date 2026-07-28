import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_connect/printer_connect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PigeonPrinterConnectPlatform', () {
    test('is the default instance', () {
      expect(
        PrinterConnectPlatform.instance,
        isInstanceOf<PigeonPrinterConnectPlatform>(),
      );
    });

    test('can be replaced with a mock', () {
      final mockPlatform = MockPrinterConnectPlatform();
      PrinterConnectPlatform.instance = mockPlatform;

      expect(PrinterConnectPlatform.instance, isInstanceOf<MockPrinterConnectPlatform>());
    });
  });

  group('PrinterConnect static methods', () {
    late MockPrinterConnectPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockPrinterConnectPlatform();
      PrinterConnectPlatform.instance = mockPlatform;
    });

    test('getBluetoothAvailabilityState', () async {
      final result = await PrinterConnect.getBluetoothAvailabilityState();
      expect(result, AvailabilityState.poweredOn);
    });

    test('enableBluetooth', () async {
      final result = await PrinterConnect.enableBluetooth();
      expect(result, true);
    });

    test('disableBluetooth', () async {
      final result = await PrinterConnect.disableBluetooth();
      expect(result, true);
    });

    test('hasPermissions', () async {
      final result = await PrinterConnect.hasPermissions();
      expect(result, true);
    });

    test('isScanning', () async {
      final result = await PrinterConnect.isScanning();
      expect(result, false);
    });

    test('getConnectionState', () async {
      final result = await PrinterConnect.getConnectionState('test-device');
      expect(result, BleConnectionState.disconnected);
    });

    test('setLogLevel', () async {
      expect(() async {
        await PrinterConnect.setLogLevel(BleLogLevel.info);
      }, returnsNormally);
    });
  });
}

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
      {Duration? connectionTimeout,
      bool autoConnect = false,
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
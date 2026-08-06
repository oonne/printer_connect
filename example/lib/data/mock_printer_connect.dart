// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:printer_connect/printer_connect.dart';
import 'package:printer_connect/src/printer_connect.g.dart'
    show ConnectionPlatformConfig;

class MockPrinterConnect extends PrinterConnectPlatform {
  final _mockBleDevice = BleDevice(
    deviceId: 'MockDeviceId',
    name: 'MockDevice',
    rssi: 50,
    manufacturerDataList: [],
  );

  Uint8List _serviceValue = utf8.encode('Result');
  bool _isScanning = false;

  final BleService _mockService = BleService(
    uuid: '180',
    characteristics: [
      BleCharacteristic(
        uuid: '180A',
        properties: [
          CharacteristicProperty.read,
          CharacteristicProperty.write,
          CharacteristicProperty.notify,
        ],
        descriptors: [],
      ),
    ],
  );

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    _isScanning = true;
    updateScanResult(_mockBleDevice);
  }

  @override
  Future<void> stopScan() async {
    _isScanning = false;
  }

  @override
  Future<bool> isScanning() async {
    return _isScanning;
  }

  @override
  Future<void> connect(
    String deviceId, {
    Duration? connectionTimeout,
    bool autoConnect = false,
    ConnectionPlatformConfig? platformConfig,
  }) async {
    updateConnection(deviceId, true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    updateConnection(deviceId, false);
  }

  @override
  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors,
  ) async {
    return [_mockService];
  }

  @override
  Future<bool> enableBluetooth() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  @override
  Future<bool> disableBluetooth() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    return AvailabilityState.poweredOn;
  }

  @override
  Future<List<BleDevice>> getSystemDevices(List<String>? withServices) async {
    return [];
  }

  @override
  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _serviceValue;
  }

  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _serviceValue = value;
  }

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async {
    await Future.delayed(const Duration(seconds: 1));
    return 512;
  }

  @override
  Future<void> requestConnectionPriority(
    String deviceId,
    BleConnectionPriority priority,
  ) async {}

  @override
  Future<void> setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty,
  ) async {}

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async {
    return BleConnectionState.disconnected;
  }

  @override
  Future<bool> hasPermissions({bool withAndroidFineLocation = false}) async {
    return true;
  }

  @override
  Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {}

  @override
  Future<int> readRssi(String deviceId) async {
    return 50;
  }

  @override
  Future<void> setLogLevel(BleLogLevel logLevel) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

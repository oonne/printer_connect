import 'dart:typed_data';

import 'package:printer_connect/src/printer_connect.g.dart'
    hide BleConnectionParametersUpdated, ConnectionPlatformConfig;
import 'package:printer_connect/src/models/model_exports.dart';
import 'package:printer_connect/src/utils/exports.dart';
import 'package:printer_connect/src/interfaces/printer_connect_platform_interface.dart';

class PrinterConnect {
  PrinterConnect._();

  static final PrinterConnectPlatform _platform =
      PrinterConnectPlatform.instance;

  static final Map<String, BleCommandQueue> _queues = {};

  static Stream<BleDevice> get scanStream => _platform.scanStream;

  static Stream<AvailabilityState> get availabilityStream =>
      _platform.availabilityStream;

  static Stream<BleConnectionState> connectionStream(String deviceId) =>
      _platform.connectionStream(deviceId);

  static Stream<Uint8List> characteristicValueStream(
          String deviceId, String characteristicId) =>
      _platform.characteristicValueStream(deviceId, characteristicId);

  static Stream<bool> pairingStateStream(String deviceId) =>
      _platform.pairingStateStream(deviceId);

  static Future<bool> hasPermissions(
      {bool withAndroidFineLocation = false}) async {
    return _platform.hasPermissions(
        withAndroidFineLocation: withAndroidFineLocation);
  }

  static Future<void> requestPermissions(
      {bool withAndroidFineLocation = false}) async {
    return _platform.requestPermissions(
        withAndroidFineLocation: withAndroidFineLocation);
  }

  static Future<void> startScan(
      {ScanFilter? scanFilter, PlatformConfig? platformConfig}) async {
    return _platform.startScan(
        scanFilter: scanFilter, platformConfig: platformConfig);
  }

  static Future<void> stopScan() async {
    return _platform.stopScan();
  }

  static Future<bool> isScanning() async {
    return _platform.isScanning();
  }

  static Future<void> connect(String deviceId,
      {Duration? timeout,
      bool autoConnect = false,
      ConnectionPlatformConfig? platformConfig}) async {
    return _platform.connect(deviceId,
        connectionTimeout: timeout,
        autoConnect: autoConnect,
        platformConfig: platformConfig);
  }

  static Future<void> disconnect(String deviceId) async {
    return _platform.disconnect(deviceId);
  }

  static Future<List<BleService>> discoverServices(String deviceId,
      {bool withDescriptors = false, Duration? timeout, String? queueId}) async {
    return _getQueue(queueId, deviceId).queueCommand(
          () => _platform.discoverServices(deviceId, withDescriptors),
          deviceId: deviceId,
          timeout: timeout,
        );
  }

  static Future<Uint8List> read(
      String deviceId, String service, String characteristic,
      {Duration? timeout, String? queueId}) async {
    return _getQueue(queueId, deviceId).queueCommand(
          () => _platform.readValue(deviceId, service, characteristic,
              timeout: timeout),
          deviceId: deviceId,
          timeout: timeout,
        );
  }

  static Future<void> write(
      String deviceId, String service, String characteristic, Uint8List value,
      {bool withoutResponse = false, Duration? timeout, String? queueId}) async {
    final property =
        withoutResponse ? BleOutputProperty.writeWithoutResponse : BleOutputProperty.write;
    return _getQueue(queueId, deviceId).queueCommand(
          () => _platform.writeValue(
              deviceId, service, characteristic, value, property),
          deviceId: deviceId,
          timeout: timeout,
        );
  }

  static Future<void> subscribeNotifications(
      String deviceId, String service, String characteristic,
      {Duration? timeout, String? queueId}) async {
    return _getQueue(queueId, deviceId).queueCommand(
          () => _platform.setNotifiable(
              deviceId, service, characteristic, BleInputProperty.notification),
          deviceId: deviceId,
          timeout: timeout,
        );
  }

  static Future<void> subscribeIndications(
      String deviceId, String service, String characteristic,
      {Duration? timeout, String? queueId}) async {
    return _getQueue(queueId, deviceId).queueCommand(
          () => _platform.setNotifiable(
              deviceId, service, characteristic, BleInputProperty.indication),
          deviceId: deviceId,
          timeout: timeout,
        );
  }

  static Future<void> unsubscribe(
      String deviceId, String service, String characteristic,
      {Duration? timeout, String? queueId}) async {
    return _getQueue(queueId, deviceId).queueCommand(
          () => _platform.setNotifiable(
              deviceId, service, characteristic, BleInputProperty.disabled),
          deviceId: deviceId,
          timeout: timeout,
        );
  }

  static Future<int> requestMtu(String deviceId, int expectedMtu,
      {Duration? timeout, String? queueId}) async {
    return _getQueue(queueId, deviceId).queueCommand(
          () => _platform.requestMtu(deviceId, expectedMtu),
          deviceId: deviceId,
          timeout: timeout,
        );
  }

  static Future<int> readRssi(String deviceId,
      {Duration? timeout, String? queueId}) async {
    return _getQueue(queueId, deviceId).queueCommand(
          () => _platform.readRssi(deviceId),
          deviceId: deviceId,
          timeout: timeout,
        );
  }

  static Future<bool> pair(String deviceId,
      {BleCommand? pairingCommand, Duration? timeout, String? queueId}) async {
    return _getQueue(queueId, deviceId).queueCommand(
          () => _platform.pair(deviceId),
          deviceId: deviceId,
          timeout: timeout,
        );
  }

  static Future<bool> isPaired(String deviceId,
      {BleCommand? pairingCommand, Duration? timeout, String? queueId}) async {
    return _getQueue(queueId, deviceId).queueCommand(
          () => _platform.isPaired(deviceId),
          deviceId: deviceId,
          timeout: timeout,
        );
  }

  static Future<void> unpair(String deviceId) async {
    return _platform.unpair(deviceId);
  }

  static Future<BleConnectionState> getConnectionState(
      String deviceId) async {
    return _platform.getConnectionState(deviceId);
  }

  static Future<List<BleDevice>> getSystemDevices(
      {List<String>? withServices}) async {
    return _platform.getSystemDevices(withServices);
  }

  static Future<AvailabilityState> getBluetoothAvailabilityState(
      {String? queueId}) async {
    return _platform.getBluetoothAvailabilityState();
  }

  static Future<bool> enableBluetooth() async {
    return _platform.enableBluetooth();
  }

  static Future<bool> disableBluetooth() async {
    return _platform.disableBluetooth();
  }

  static Future<void> setLogLevel(BleLogLevel logLevel) async {
    return _platform.setLogLevel(logLevel);
  }

  static Future<void> requestConnectionPriority(
      String deviceId, BleConnectionPriority priority) async {
    return _platform.requestConnectionPriority(deviceId, priority);
  }

  static bool receivesAdvertisements(String deviceId) {
    return _platform.receivesAdvertisements(deviceId);
  }

  static void setQueueType(String? queueId, QueueType type) {
    if (queueId == null) return;
    _queues[queueId] = BleCommandQueue(queueType: type);
  }

  static BleCommandQueue _getQueue(String? queueId, String deviceId) {
    if (queueId != null && _queues.containsKey(queueId)) {
      return _queues[queueId]!;
    }
    return BleCommandQueue(queueType: QueueType.none);
  }
}
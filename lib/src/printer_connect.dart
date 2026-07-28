import 'dart:async';

import 'package:flutter/services.dart';
import 'package:printer_connect/src/printer_connect.g.dart'
    hide BleConnectionParametersUpdated, ConnectionPlatformConfig;
import 'package:printer_connect/src/models/model_exports.dart';
import 'package:printer_connect/src/utils/exports.dart';
import 'package:printer_connect/src/interfaces/printer_connect_platform_interface.dart';
import 'package:printer_connect/src/printer_connect_exceptions.dart'
    as exceptions;

class PrinterConnect {
  PrinterConnect._();

  static final PrinterConnectPlatform _platform =
      PrinterConnectPlatform.instance;

  static final Map<String, BleCommandQueue> _queues = {};
  static final Set<String> _connectedDevices = {};
  static final Set<String> _connectingDevices = {};
  static final Map<String, StreamSubscription<BleConnectionState>>
      _connectionSubscriptions = {};

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
    try {
      return await _platform.startScan(
          scanFilter: scanFilter, platformConfig: platformConfig);
    } on PlatformException catch (e) {
      throw exceptions.errorParser(e);
    }
  }

  static Future<void> stopScan() async {
    try {
      return await _platform.stopScan();
    } on PlatformException catch (e) {
      throw exceptions.errorParser(e);
    }
  }

  static Future<bool> isScanning() async {
    return _platform.isScanning();
  }

  static Future<void> connect(String deviceId,
      {Duration? timeout,
      bool autoConnect = false,
      ConnectionPlatformConfig? platformConfig}) async {
    if (_connectingDevices.contains(deviceId)) {
      throw StateError('Already connecting to $deviceId');
    }
    if (_connectedDevices.contains(deviceId)) {
      return;
    }
    _connectingDevices.add(deviceId);
    try {
      await _platform.connect(deviceId,
          connectionTimeout: timeout,
          autoConnect: autoConnect,
          platformConfig: platformConfig);
      _connectedDevices.add(deviceId);
      _setupConnectionTracking(deviceId);
    } on PlatformException catch (e) {
      throw exceptions.errorParser(e);
    } finally {
      _connectingDevices.remove(deviceId);
    }
  }

  static Future<void> disconnect(String deviceId) async {
    try {
      await _platform.disconnect(deviceId);
    } on PlatformException catch (e) {
      throw exceptions.errorParser(e);
    } finally {
      _connectedDevices.remove(deviceId);
      await _connectionSubscriptions[deviceId]?.cancel();
      _connectionSubscriptions.remove(deviceId);
    }
  }

  static void _setupConnectionTracking(String deviceId) {
    _connectionSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions[deviceId] =
        connectionStream(deviceId).listen((state) {
      if (state == BleConnectionState.disconnected) {
        _connectedDevices.remove(deviceId);
        _connectionSubscriptions[deviceId]?.cancel();
        _connectionSubscriptions.remove(deviceId);
      }
    });
  }

  static List<String> get connectedDevices => List.unmodifiable(_connectedDevices);

  static bool isDeviceConnected(String deviceId) => _connectedDevices.contains(deviceId);

  static bool isDeviceConnecting(String deviceId) => _connectingDevices.contains(deviceId);

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
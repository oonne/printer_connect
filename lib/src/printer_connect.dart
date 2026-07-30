import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:printer_connect/src/printer_connect.g.dart'
    hide BleConnectionParametersUpdated;
import 'package:printer_connect/src/models/model_exports.dart';
import 'package:printer_connect/src/utils/exports.dart';
import 'package:printer_connect/src/interfaces/printer_connect_platform_interface.dart';
import 'package:printer_connect/src/printer_connect_exceptions.dart'
    as exceptions;

class PrinterConnect {
  /// Get platform specific implementation.
  static PrinterConnectPlatform _platform = PrinterConnectPlatform.instance;

  static final BleCommandQueue _bleCommandQueue = BleCommandQueue();

  /// Set custom platform specific implementation (e.g. for testing).
  static void setInstance(PrinterConnectPlatform instance) =>
      _platform = instance;

  /// Set global timeout for all commands.
  /// Default timeout is 10 seconds.
  /// Set to null to disable.
  static set timeout(Duration? duration) {
    _bleCommandQueue.timeout = duration;
  }

  /// Set log level for both Dart and native implementations.
  /// Only effective in debug builds.
  static Future<void> setLogLevel(BleLogLevel logLevel) async {
    if (!kDebugMode) return;
    UniversalLogger.setLogLevel(logLevel);
    await _platform.setLogLevel(logLevel);
  }

  /// Set how commands will be executed. By default, all commands are executed in a global queue (`QueueType.global`),
  /// with each command waiting for the previous one to finish.
  ///
  /// [QueueType.global] will execute commands of all devices in a single queue.
  /// [QueueType.perDevice] will execute command of each device in separate queues.
  /// [QueueType.none] will execute all commands in parallel.
  static set queueType(QueueType queueType) {
    _bleCommandQueue.queueType = queueType;
    UniversalLogger.logInfo('Queue ${queueType.name}');
  }

  /// Scan Stream
  static Stream<BleDevice> get scanStream => _platform.scanStream;

  /// Bluetooth availability state stream
  static Stream<AvailabilityState> get availabilityStream =>
      _platform.availabilityStream;

  /// Connection stream of a device
  static Stream<bool> connectionStream(String deviceId) =>
      _platform.connectionStream(deviceId);

  /// Characteristic value stream
  static Stream<Uint8List> characteristicValueStream(
    String deviceId,
    String characteristicId,
  ) => _platform.characteristicValueStream(deviceId, characteristicId);

  /// Pairing state stream
  static Stream<bool> pairingStateStream(String deviceId) =>
      _platform.pairingStateStream(deviceId);

  /// Get Bluetooth availability state.
  /// To be notified of updates, set [onAvailabilityChange] listener.
  static Future<AvailabilityState> getBluetoothAvailabilityState({
    String? queueId,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.getBluetoothAvailabilityState(),
      queueId: queueId,
    );
  }

  /// Check if has permissions.
  /// [withAndroidFineLocation] is used to check fine location permission on Android 12+ (API 31+).
  /// On Android lower than 12, this method will check location permission regardless of the [withAndroidFineLocation] value.
  static Future<bool> hasPermissions({
    bool withAndroidFineLocation = false,
  }) async {
    return _platform.hasPermissions(
      withAndroidFineLocation: withAndroidFineLocation,
    );
  }

  /// Request permissions.
  /// if all permissions are already granted or granted by user, this method will succeed.
  /// it will throw exception if permissions are denied by user.
  /// [withAndroidFineLocation] is used to request fine location permission on Android 12+ (API 31+).
  /// on Android lower than 12, this method will request location permission regardless of the [withAndroidFineLocation] value.
  static Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {
    return _platform.requestPermissions(
      withAndroidFineLocation: withAndroidFineLocation,
    );
  }

  /// Start scan.
  /// Scan results will arrive in [onScanResult] listener.
  /// It might throw errors if Bluetooth is not available.
  static Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
    String? queueId,
  }) async {
    return await _bleCommandQueue.queueCommandWithoutTimeout(
      () => _platform.startScan(
        scanFilter: scanFilter,
        platformConfig: platformConfig,
      ),
      queueId: queueId,
    );
  }

  /// Stop scan.
  /// Set [onScanResult] listener to `null` if you don't need it anymore.
  /// It might throw errors if Bluetooth is not available.
  static Future<void> stopScan({String? queueId}) async {
    return await _bleCommandQueue.queueCommandWithoutTimeout(
      () => _platform.stopScan(),
      queueId: queueId,
    );
  }

  /// Check if currently scanning for devices.
  /// Returns `true` if scanning is active, `false` otherwise.
  static Future<bool> isScanning({String? queueId}) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.isScanning(),
      queueId: queueId,
    );
  }

  /// Connect to a device.
  /// It is advised to stop scanning before connecting.
  /// It throws error if device connection fails.
  /// Default connection timeout is 60 sec.
  ///
  /// [autoConnect] enables automatic reconnection when the device becomes available.
  /// Default value is `false`.
  ///
  /// Call [disconnect] to prevent auto-reconnect even while a device is disconnected.
  ///
  /// [platformConfig] sets platform specific connection options,
  /// e.g. [AppleConnectionOptions] to get notified of connection events
  /// while the app is suspended. Ignored on other platforms.
  ///
  /// Can throw `ConnectionException` or `PlatformException`.
  static Future<void> connect(
    String deviceId, {
    Duration? timeout,
    bool autoConnect = false,
    ConnectionPlatformConfig? platformConfig,
  }) async {
    timeout ??= const Duration(seconds: 60);
    Completer<bool> completer = _connectionEventCompleter(
      deviceId,
      timeout: timeout,
    );

    _platform
        .connect(
          deviceId,
          connectionTimeout: timeout,
          autoConnect: autoConnect,
          platformConfig: platformConfig,
        )
        .catchError((error) {
          if (completer.isCompleted) return;
          completer.completeError(exceptions.ConnectionException.fromError(error));
        });

    if (!await completer.future.timeout(timeout)) {
      throw exceptions.ConnectionException(
        "Failed to connect",
        code: 'connection_failed',
      );
    }
  }

  /// Disconnect from a device.
  /// Get notified of connection state changes in [onConnectionChange] listener.
  static Future<void> disconnect(
    String deviceId, {
    Duration? timeout,
    String? queueId,
  }) async {
    timeout ??= const Duration(seconds: 60);
    BleConnectionState? connectionState;
    try {
      connectionState = await _platform.getConnectionState(deviceId);
    } catch (e) {
      UniversalLogger.logError("Get connection state failed: $e");
    }
    try {
      Completer<bool> completer = _connectionEventCompleter(
        deviceId,
        timeout: timeout,
      );
      await _bleCommandQueue
          .queueCommand(
            () => _platform.disconnect(deviceId),
            timeout: timeout,
            deviceId: deviceId,
            queueId: queueId,
          )
          .catchError((error) {
            if (completer.isCompleted) return;
            completer.completeError(exceptions.ConnectionException.fromError(error));
          });
      if (connectionState == BleConnectionState.disconnected ||
          connectionState == BleConnectionState.disconnecting) {
        // Device was already disconnected, but we still called platform disconnect
        // to prevent auto-reconnect. Update connection state and return.
        _platform.updateConnection(deviceId, false);
        UniversalLogger.logInfo(
          "Device $deviceId already disconnected: $connectionState. Cleanup performed to prevent auto-reconnect.",
        );
        return;
      }
      if (await completer.future.timeout(timeout)) {
        UniversalLogger.logError(
          "Device $deviceId is still connected after disconnect attempt",
        );
      }
    } catch (e) {
      UniversalLogger.logError("Disconnect failed: $e");
    }
  }

  /// Discover services of a device.
  /// Set [withDescriptors] to `true` to discover characteristics with descriptors.
  static Future<List<BleService>> discoverServices(
    String deviceId, {
    bool withDescriptors = false,
    Duration? timeout,
    String? queueId,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.discoverServices(deviceId, withDescriptors),
      timeout: timeout,
      deviceId: deviceId,
      queueId: queueId,
    );
  }

  /// Set a characteristic notifiable.
  /// Updates will arrive in [onValueChange] listener and [characteristicValueStream]
  /// call [unsubscribe] to stop updates
  static Future<void> subscribeNotifications(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
    String? queueId,
  }) async {
    return _sendBleInputPropertyCommand(
      deviceId,
      service,
      characteristic,
      BleInputProperty.notification,
      timeout: timeout,
      queueId: queueId,
    );
  }

  /// Set a characteristic notifiable.
  /// Updates will arrive in [onValueChange] listener and [characteristicValueStream]
  /// call [unsubscribe] to stop updates
  static Future<void> subscribeIndications(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
    String? queueId,
  }) async {
    return _sendBleInputPropertyCommand(
      deviceId,
      service,
      characteristic,
      BleInputProperty.indication,
      timeout: timeout,
      queueId: queueId,
    );
  }

  /// Stop characteristic notifications/indication updates
  static Future<void> unsubscribe(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
    String? queueId,
  }) async {
    return _sendBleInputPropertyCommand(
      deviceId,
      service,
      characteristic,
      BleInputProperty.disabled,
      timeout: timeout,
      queueId: queueId,
    );
  }

  /// Read a characteristic value.
  /// On iOS this command will also trigger [onValueChange] listener.
  static Future<Uint8List> read(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
    String? queueId,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.readValue(
        deviceId,
        BleUuidParser.string(service),
        BleUuidParser.string(characteristic),
        timeout: timeout ?? _bleCommandQueue.timeout,
      ),
      timeout: timeout,
      deviceId: deviceId,
      queueId: queueId,
    );
  }

  /// Write a characteristic value.
  /// To write a characteristic value without response, set [withoutResponse] to `true`.
  static Future<void> write(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value, {
    bool withoutResponse = false,
    Duration? timeout,
    String? queueId,
  }) async {
    await _bleCommandQueue.queueCommand(
      () => _platform.writeValue(
        deviceId,
        BleUuidParser.string(service),
        BleUuidParser.string(characteristic),
        value,
        withoutResponse
            ? BleOutputProperty.withoutResponse
            : BleOutputProperty.withResponse,
      ),
      timeout: timeout,
      deviceId: deviceId,
      queueId: queueId,
    );
  }

  /// Requests an MTU (Maximum Transmission Unit) value for the connection.
  ///
  /// **⚠️ Note:** Requesting an MTU is a *best-effort* operation. On many platforms
  /// the final MTU is fully controlled by the OS and remote device. This method
  /// returns the current/negotiated MTU value, which may differ from `expectedMtu`.
  static Future<int> requestMtu(
    String deviceId,
    int expectedMtu, {
    Duration? timeout,
    String? queueId,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.requestMtu(deviceId, expectedMtu),
      timeout: timeout,
      deviceId: deviceId,
      queueId: queueId,
    );
  }

  /// Requests a connection parameter update for [deviceId].
  ///
  /// [priority] controls the BLE connection interval:
  /// - [BleConnectionPriority.balanced] - default OS behaviour (~30-50 ms interval).
  /// - [BleConnectionPriority.highPerformance] - low latency, higher power (~7.5-15 ms interval).
  /// - [BleConnectionPriority.lowPower] - power-optimised (~100-125 ms interval).
  static Future<void> requestConnectionPriority(
    String deviceId,
    BleConnectionPriority priority, {
    Duration? timeout,
    String? queueId,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.requestConnectionPriority(deviceId, priority),
      timeout: timeout,
      deviceId: deviceId,
      queueId: queueId,
    );
  }

  /// Read the RSSI value of a connected device.
  ///
  /// Returns the current RSSI value in dBm. This value indicates the signal strength
  /// between the device and the connected peripheral. Lower (more negative) values
  /// indicate weaker signal, while higher (less negative) values indicate stronger signal.
  static Future<int> readRssi(
    String deviceId, {
    Duration? timeout,
    String? queueId,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.readRssi(deviceId),
      timeout: timeout,
      deviceId: deviceId,
      queueId: queueId,
    );
  }

  /// Check if a device is paired.
  static Future<bool> isPaired(
    String deviceId, {
    Duration? timeout,
    String? queueId,
  }) async {
    if (BleCapabilities.hasSystemPairingApi) {
      return _bleCommandQueue.queueCommand(
        () => _platform.isPaired(deviceId),
        deviceId: deviceId,
        timeout: timeout,
        queueId: queueId,
      );
    }
    return false;
  }

  /// Pair a device.
  static Future<bool> pair(
    String deviceId, {
    Duration? timeout,
    String? queueId,
  }) async {
    if (BleCapabilities.hasSystemPairingApi) {
      final paired = await _bleCommandQueue.queueCommand(
        () => _platform.pair(deviceId),
        deviceId: deviceId,
        timeout: timeout,
        queueId: queueId,
      );
      if (!paired) {
        throw exceptions.PairingException(
          'Failed to pair device',
          code: 'pairing_failed',
        );
      }
      return paired;
    }
    // iOS doesn't support system pairing API.
    throw exceptions.PairingException(
      'Pairing is not supported on this platform',
      code: 'not_supported',
    );
  }

  /// Unpair a device.
  static Future<void> unpair(
    String deviceId, {
    String? queueId,
  }) async {
    return _bleCommandQueue.queueCommand(
      () => _platform.unpair(deviceId),
      queueId: queueId,
    );
  }

  /// Get connection state of a device.
  static Future<BleConnectionState> getConnectionState(
    String deviceId, {
    Duration? timeout,
    String? queueId,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.getConnectionState(deviceId),
      timeout: timeout,
      queueId: queueId,
    );
  }

  /// Get system connected devices.
  static Future<List<BleDevice>> getSystemDevices({
    List<String>? withServices,
    Duration? timeout,
    String? queueId,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.getSystemDevices(withServices?.toValidUUIDList()),
      timeout: timeout,
      queueId: queueId,
    );
  }

  /// Enable Bluetooth (Android only).
  static Future<bool> enableBluetooth({
    Duration? timeout,
    String? queueId,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.enableBluetooth(),
      timeout: timeout,
      queueId: queueId,
    );
  }

  /// Disable Bluetooth (Android only).
  static Future<bool> disableBluetooth({
    Duration? timeout,
    String? queueId,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.disableBluetooth(),
      timeout: timeout,
      queueId: queueId,
    );
  }

  /// Clear a queue.
  /// Use [BleCommandQueue.globalQueueId] to clear the global queue.
  /// To clear the queue of a specific device, use `deviceId` as [id].
  /// To clear a custom queue, pass the same `queueId` string used when enqueueing commands.
  /// If no [id] is provided, all queues will be cleared.
  static void clearQueue([String? id]) => _bleCommandQueue.clearQueue(id);

  /// Get updates of remaining items of a queue.
  static set onQueueUpdate(OnQueueUpdate? onQueueUpdate) =>
      _bleCommandQueue.onQueueUpdate = onQueueUpdate;

  /// Check if device receives advertisements.
  static bool receivesAdvertisements(String deviceId) {
    return _platform.receivesAdvertisements(deviceId);
  }

  // Private helper methods

  /// Creates a completer that will be completed when the connection state changes.
  static Completer<bool> _connectionEventCompleter(
    String deviceId, {
    Duration? timeout,
  }) {
    timeout ??= const Duration(seconds: 60);
    final target = deviceId.toLowerCase();
    StreamSubscription? connectionSubscription;
    Completer<bool> completer = Completer();

    void cancelSubscription() {
      connectionSubscription?.cancel();
      connectionSubscription = null;
    }

    void handleError(dynamic error) {
      cancelSubscription();
      if (completer.isCompleted) return;
      completer.completeError(exceptions.ConnectionException.fromError(error));
    }

    connectionSubscription = _platform
        .bleConnectionUpdateStreamController
        .stream
        .where((e) => e.deviceId == deviceId || e.deviceId.toLowerCase() == target)
        .listen(
          (e) {
            cancelSubscription();
            if (e.error != null) {
              handleError(e.error);
            } else {
              if (!completer.isCompleted) {
                completer.complete(e.isConnected);
              }
            }
          },
          onError: handleError,
          cancelOnError: true,
        );

    completer.future
        .timeout(timeout)
        .then((_) {
          cancelSubscription();
        })
        .catchError((_) {
          cancelSubscription();
        });

    return completer;
  }

  /// Sends a BLE input property command (notification/indication/unsubscribe).
  static Future<void> _sendBleInputPropertyCommand(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty, {
    Duration? timeout,
    String? queueId,
  }) async {
    return _bleCommandQueue.queueCommand(
      () => _platform.setNotifiable(
        deviceId,
        BleUuidParser.string(service),
        BleUuidParser.string(characteristic),
        bleInputProperty,
      ),
      timeout: timeout,
      deviceId: deviceId,
      queueId: queueId,
    );
  }
}

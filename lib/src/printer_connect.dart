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
  /// 获取平台特定的实现实例
  static PrinterConnectPlatform _platform = PrinterConnectPlatform.instance;

  static final BleCommandQueue _bleCommandQueue = BleCommandQueue();

  /// 设置自定义平台实现（例如用于测试）
  static void setInstance(PrinterConnectPlatform instance) =>
      _platform = instance;

  /// 设置所有命令的全局超时时间
  /// 默认超时为 10 秒
  /// 设为 null 则禁用超时
  static set timeout(Duration? duration) {
    _bleCommandQueue.timeout = duration;
  }

  /// 设置 Dart 端和原生端的日志级别
  /// 仅在 debug 构建中生效
  static Future<void> setLogLevel(BleLogLevel logLevel) async {
    if (!kDebugMode) return;
    UniversalLogger.setLogLevel(logLevel);
    await _platform.setLogLevel(logLevel);
  }

  /// 设置命令的执行方式。默认情况下，所有命令在全局队列中执行（[QueueType.global]），
  /// 每个命令等待前一个命令完成后再执行
  ///
  /// [QueueType.global] 所有设备的命令在单个队列中按顺序执行
  /// [QueueType.perDevice] 每个设备的命令在独立队列中按顺序执行
  /// [QueueType.none] 所有命令并行执行，不进行排队
  static set queueType(QueueType queueType) {
    _bleCommandQueue.queueType = queueType;
    UniversalLogger.logInfo('Queue ${queueType.name}');
  }

  /// 扫描结果流
  static Stream<BleDevice> get scanStream => _platform.scanStream;

  /// 蓝牙可用性状态流
  static Stream<AvailabilityState> get availabilityStream =>
      _platform.availabilityStream;

  /// 设备连接状态流
  static Stream<bool> connectionStream(String deviceId) =>
      _platform.connectionStream(deviceId);

  /// 特征值数据流
  static Stream<Uint8List> characteristicValueStream(
    String deviceId,
    String characteristicId,
  ) => _platform.characteristicValueStream(deviceId, characteristicId);

  /// 配对状态流
  static Stream<bool> pairingStateStream(String deviceId) =>
      _platform.pairingStateStream(deviceId);

  /// 获取蓝牙可用性状态
  /// 如需接收状态更新，请设置 [onAvailabilityChange] 监听器
  static Future<AvailabilityState> getBluetoothAvailabilityState({
    String? queueId,
  }) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.getBluetoothAvailabilityState(),
      queueId: queueId,
    );
  }

  /// 检查是否已获取权限
  /// [withAndroidFineLocation] 用于在 Android 12+（API 31+）上检查精确位置权限
  /// 在 Android 12 以下版本中，此方法将检查位置权限，不受 [withAndroidFineLocation] 影响
  static Future<bool> hasPermissions({
    bool withAndroidFineLocation = false,
  }) async {
    return _platform.hasPermissions(
      withAndroidFineLocation: withAndroidFineLocation,
    );
  }

  /// 请求权限
  /// 如果所有权限已被授予或用户授予，此方法将成功
  /// 如果权限被用户拒绝，将抛出异常
  /// [withAndroidFineLocation] 用于在 Android 12+（API 31+）上请求精确位置权限
  /// 在 Android 12 以下版本中，此方法将请求位置权限，不受 [withAndroidFineLocation] 影响
  static Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {
    return _platform.requestPermissions(
      withAndroidFineLocation: withAndroidFineLocation,
    );
  }

  /// 开始扫描蓝牙设备
  /// 扫描结果将通过 [onScanResult] 监听器返回
  /// 如果蓝牙不可用，可能会抛出错误
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

  /// 停止扫描
  /// 如果不再需要扫描结果，请将 [onScanResult] 监听器设为 `null`
  /// 如果蓝牙不可用，可能会抛出错误
  static Future<void> stopScan({String? queueId}) async {
    return await _bleCommandQueue.queueCommandWithoutTimeout(
      () => _platform.stopScan(),
      queueId: queueId,
    );
  }

  /// 检查是否正在扫描设备
  /// 正在扫描返回 `true`，否则返回 `false`
  static Future<bool> isScanning({String? queueId}) async {
    return await _bleCommandQueue.queueCommand(
      () => _platform.isScanning(),
      queueId: queueId,
    );
  }

  /// 连接到指定设备
  /// 建议在连接前停止扫描
  /// 如果设备连接失败，将抛出错误
  /// 默认连接超时为 60 秒
  ///
  /// [autoConnect] 启用自动重连，当设备变为可用时自动重连
  /// 默认值为 `false`
  ///
  /// 调用 [disconnect] 可阻止自动重连，即使设备已断开连接
  ///
  /// [platformConfig] 设置平台特定的连接选项，
  /// 例如 [AppleConnectionOptions] 用于在应用挂起时接收连接事件通知
  /// 其他平台忽略此参数
  ///
  /// 可能抛出 `ConnectionException` 或 `PlatformException`
  static Future<void> connect(
    String deviceId, {
    Duration? timeout,
    bool autoConnect = false,
    ConnectionPlatformConfig? platformConfig,
  }) async {
    timeout ??= const Duration(seconds: 60);
    // 创建事件等待机制：通过 _connectionEventCompleter 监听连接状态流，
    // 当平台层上报连接成功/失败事件时，completer.future 完成，
    // 从而实现异步等待连接结果的管理逻辑
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

  /// 断开与指定设备的连接
  /// 连接状态变更可通过 [onConnectionChange] 监听器接收通知
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
      // 创建事件等待机制：监听连接状态流以确认断开结果，
      // 同时处理已断开连接的场景（清理自动重连状态）
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
        // 设备已处于断开状态，但仍调用了平台层的 disconnect 以防止自动重连
        // 更新连接状态并返回
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

  /// 发现设备的 GATT 服务
  /// 将 [withDescriptors] 设为 `true` 可同时发现带描述符的特征
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

  /// 设置特征值为通知模式（Notification）
  /// 更新将通过 [onValueChange] 监听器和 [characteristicValueStream] 返回
  /// 调用 [unsubscribe] 停止接收更新
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

  /// 设置特征值为指示模式（Indication）
  /// 更新将通过 [onValueChange] 监听器和 [characteristicValueStream] 返回
  /// 调用 [unsubscribe] 停止接收更新
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

  /// 停止特征值的通知/指示更新
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

  /// 读取特征值
  /// 在 iOS 上，此命令还会触发 [onValueChange] 监听器
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

  /// 写入特征值
  /// 如需写入时不要求响应，将 [withoutResponse] 设为 `true`
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

  /// 请求连接的 MTU（最大传输单元）值
  ///
  /// **⚠️ 注意：** 请求 MTU 是一个*尽力而为*的操作。在许多平台上，
  /// 最终 MTU 完全由操作系统和远程设备控制。此方法返回当前/协商后的 MTU 值，
  /// 可能与 `expectedMtu` 不同
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

  /// 请求更新 [deviceId] 的连接参数
  ///
  /// [priority] 控制 BLE 连接间隔：
  /// - [BleConnectionPriority.balanced] - 操作系统默认行为（约 30-50 ms 间隔）
  /// - [BleConnectionPriority.highPerformance] - 低延迟，功耗较高（约 7.5-15 ms 间隔）
  /// - [BleConnectionPriority.lowPower] - 功耗优化（约 100-125 ms 间隔）
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

  /// 读取已连接设备的 RSSI（接收信号强度指示）值
  ///
  /// 返回当前 RSSI 值（单位：dBm）。该值表示设备与连接外设之间的信号强度。
  /// 较低（更负）的值表示信号较弱，较高（更正）的值表示信号较强
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

  /// 检查设备是否已配对
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

  /// 配对设备
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
    // iOS 不支持系统配对 API
    throw exceptions.PairingException(
      'Pairing is not supported on this platform',
      code: 'not_supported',
    );
  }

  /// 取消配对设备
  static Future<void> unpair(
    String deviceId, {
    Duration? timeout,
    String? queueId,
  }) async {
    return _bleCommandQueue.queueCommand(
      () => _platform.unpair(deviceId),
      deviceId: deviceId,
      timeout: timeout,
      queueId: queueId,
    );
  }

  /// 获取设备的连接状态
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

  /// 获取系统已连接的设备列表
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

  /// 启用蓝牙（仅 Android 平台）
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

  /// 禁用蓝牙（仅 Android 平台）
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

  /// 清空指定队列
  /// 使用 [BleCommandQueue.globalQueueId] 清空全局队列
  /// 要清空特定设备的队列，请使用 `deviceId` 作为 [id]
  /// 要清空自定义队列，请传入入队时使用的 `queueId` 字符串
  /// 如果未提供 [id]，则清空所有队列
  static void clearQueue([String? id]) => _bleCommandQueue.clearQueue(id);

  /// 获取队列中剩余任务的更新
  static set onQueueUpdate(OnQueueUpdate? onQueueUpdate) =>
      _bleCommandQueue.onQueueUpdate = onQueueUpdate;

  /// 检查设备是否仍在接收广播
  static bool receivesAdvertisements(String deviceId) {
    return _platform.receivesAdvertisements(deviceId);
  }

  // 私有辅助方法

  /// 创建一个 Completer，当连接状态发生变化时完成
  /// 这是一个事件等待机制：订阅平台层的连接更新流，
  /// 当指定设备的连接事件到达时完成 completer，
  /// 从而支持异步等待连接操作的结果
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
        // 大小写不敏感的设备ID匹配：支持 MAC 地址（Android/Windows/Linux）和 UUID（Apple）的不同大小写格式
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

  /// 发送 BLE 输入属性命令（通知/指示/取消订阅）
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

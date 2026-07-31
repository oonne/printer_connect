import 'package:printer_connect/printer_connect.dart';
import 'package:printer_connect/src/printer_connect.g.dart';

/// BleDevice 扩展方法
///
/// 为 BleDevice 提供便捷的设备操作方法，包括连接/断开、配对、
/// 服务发现、MTU 请求、状态流监听等。
extension BleDeviceExtension on BleDevice {
  /// 设备连接状态变化流（true 表示已连接）
  Stream<bool> get connectionStream =>
      PrinterConnect.connectionStream(deviceId);

  /// 设备配对状态变化流
  Stream<bool> get pairingStateStream =>
      PrinterConnect.pairingStateStream(deviceId);

  /// 是否已连接
  Future<bool> get isConnected async =>
      await PrinterConnect.getConnectionState(deviceId) ==
      BleConnectionState.connected;

  /// 连接设备
  ///
  /// [autoConnect] 是否自动连接（Android 特有）
  /// [timeout] 连接超时时间
  /// [platformConfig] 平台特定配置
  Future<void> connect({
    bool autoConnect = false,
    Duration? timeout,
    ConnectionPlatformConfig? platformConfig,
  }) =>
      PrinterConnect.connect(
        deviceId,
        autoConnect: autoConnect,
        timeout: timeout,
        platformConfig: platformConfig,
      );

  /// 断开设备连接
  Future<void> disconnect() => PrinterConnect.disconnect(deviceId);

  /// 请求 MTU（最大传输单元）
  ///
  /// [expectedMtu] 期望的 MTU 值
  Future<int> requestMtu(int expectedMtu, {String? queueId}) =>
      PrinterConnect.requestMtu(deviceId, expectedMtu);

  /// 检查设备是否已配对
  ///
  /// [timeout] 操作超时时间
  Future<bool> isPaired({
    Duration? timeout,
  }) {
    return PrinterConnect.isPaired(
      deviceId,
      timeout: timeout,
    );
  }

  /// 与设备配对
  ///
  /// [timeout] 操作超时时间
  Future<void> pair({
    Duration? timeout,
  }) {
    return PrinterConnect.pair(
      deviceId,
      timeout: timeout,
    );
  }

  /// 取消与设备的配对
  Future<void> unpair() => PrinterConnect.unpair(deviceId);

  /// 发现设备的所有服务
  ///
  /// 发现后会将服务缓存，以便后续使用。
  /// [timeout] 操作超时时间
  /// [withDescriptors] 是否同时获取描述符
  Future<List<BleService>> discoverServices({
    Duration? timeout,
    bool withDescriptors = false,
  }) async {
    List<BleService> servicesCache = await PrinterConnect.discoverServices(
      deviceId,
      withDescriptors: withDescriptors,
      timeout: timeout,
    );
    CacheHandler.instance.saveServices(deviceId, servicesCache);
    return servicesCache;
  }

  /// 获取指定服务
  ///
  /// 优先使用缓存的服务列表，如无缓存则自动发现。
  /// [service] 目标服务 UUID
  /// [preferCached] 是否优先使用缓存
  /// [timeout] 操作超时时间
  Future<BleService> getService(
    String service, {
    bool preferCached = true,
    Duration? timeout,
  }) async {
    List<BleService> discoveredServices = [];
    if (preferCached) {
      discoveredServices = CacheHandler.instance.getServices(deviceId) ?? [];
    }
    if (discoveredServices.isEmpty) {
      discoveredServices = await discoverServices(
        timeout: timeout,
      );
    }
    if (discoveredServices.isEmpty) {
      throw PrinterConnectException(
        'No services found',
        code: 'serviceNotFound',
      );
    }
    return discoveredServices.firstWhere(
      (s) => BleUuidParser.compareStrings(s.uuid, service),
      orElse: () => throw PrinterConnectException(
        'Service "$service" not available',
        code: 'serviceNotFound',
      ),
    );
  }

  /// 获取指定服务中的特征
  ///
  /// [characteristic] 目标特征 UUID
  /// [service] 目标服务 UUID
  /// [preferCached] 是否优先使用缓存
  /// [timeout] 操作超时时间
  Future<BleCharacteristic> getCharacteristic(
    String characteristic, {
    required String service,
    bool preferCached = true,
    Duration? timeout,
  }) async {
    BleService bluetoothService = await getService(
      service,
      preferCached: preferCached,
      timeout: timeout,
    );
    return bluetoothService.getCharacteristic(characteristic);
  }
}
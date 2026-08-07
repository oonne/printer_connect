import 'dart:async';
import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:printer_connect/src/printer_connect.g.dart'
    hide AndroidOptions, BleConnectionParametersUpdated, CharacteristicProperty;
import 'package:printer_connect/src/printer_connect.g.dart'
    as pigeon
    show
        AndroidOptions,
        AppleConnectionOptions,
        ConnectionPlatformConfig,
        BleConnectionParametersUpdated,
        CharacteristicProperty;
import 'package:printer_connect/src/models/model_exports.dart'
    hide BleConnectionParametersUpdated;
import 'package:printer_connect/src/models/ble_connection_parameters_updated.dart'
    show BleConnectionParametersUpdated;
import 'package:printer_connect/src/utils/cache_handler.dart';
import 'package:printer_connect/src/utils/ble_typedefs.dart';
import 'package:printer_connect/src/utils/universal_ble_stream_controller.dart';
import 'package:printer_connect/src/utils/universal_logger.dart';

/// 平台接口抽象类，定义了 BLE 操作的跨平台 API
///
/// 采用 Stream 架构实现事件驱动通信：
/// - 通过 [UniversalBleStreamController] 管理各类事件流（扫描、连接、特征值等）
/// - 同时提供传统的回调函数（[OnScanResult]、[OnConnectionChange] 等）作为兼容接口
/// - 子类（如 PigeonPrinterConnectPlatform）通过原生回调接收事件并分发到 Stream 和回调
abstract class PrinterConnectPlatform extends PlatformInterface {
  PrinterConnectPlatform() : super(token: _token);

  static final Object _token = Object();

  static PrinterConnectPlatform _instance = PigeonPrinterConnectPlatform();

  static PrinterConnectPlatform get instance => _instance;

  static set instance(PrinterConnectPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // 不要直接使用这些回调来推送更新，应通过 Stream 控制器统一分发
  OnScanResult? onScanResultUpdate;
  OnConnectionChange? onConnectionChange;
  OnValueChange? onValueChange;
  OnAvailabilityChange? onAvailabilityChange;
  OnConnectionParametersChange? onConnectionParametersChange;

  final Map<String, BleConnectionParametersUpdated>
  _lastConnectionParametersMap = {};

  // 以下为 Stream 控制器，用于管理异步事件流
  final _scanStreamController = UniversalBleStreamController<BleDevice>();
  final bleConnectionUpdateStreamController =
      UniversalBleStreamController<
        ({String deviceId, bool isConnected, String? error})
      >();
  final _valueStreamController =
      UniversalBleStreamController<
        ({String deviceId, String characteristicId, Uint8List value})
      >();

  /// 订阅时立即发送最新的蓝牙可用性状态
  late final _availabilityStreamController =
      UniversalBleStreamController<AvailabilityState>(
        initialEvent: getBluetoothAvailabilityState,
      );

  Stream<BleDevice> get scanStream => _scanStreamController.stream;

  Stream<AvailabilityState> get availabilityStream =>
      _availabilityStreamController.stream;

  /// 大小写不敏感的设备ID匹配说明：
  /// BLE 设备ID在不同平台上格式不同：Android/Windows/Linux 使用 MAC 地址，Apple 使用 UUID。
  /// 各平台报告的大小写也不一致：Android 返回大写 MAC，Windows/WinRT 返回小写 MAC。
  /// 因此我们采用以下策略：
  /// 1. 事件流过滤时同时匹配原始大小写和小写化后的 ID
  /// 2. 所有设备状态以小写化的规范化 ID 作为 Map 的键（见
  /// updateConnectionParameters / CacheHandler），确保同一设备的不同大小写报告不会产生重复条目
  /// 3. 输出的设备ID保持平台原始大小写，保证向后兼容
  /// 4. 快速路径：优先尝试精确匹配，仅在不匹配时再进行小写化比较
  Stream<bool> connectionStream(String deviceId) {
    final target = deviceId.toLowerCase();
    return bleConnectionUpdateStreamController.stream
        .where(
          (e) => e.deviceId == deviceId || e.deviceId.toLowerCase() == target,
        )
        .map((e) => e.isConnected);
  }

  Stream<Uint8List> characteristicValueStream(
    String deviceId,
    String characteristicId,
  ) {
    final target = deviceId.toLowerCase();
    characteristicId = BleUuidParser.string(characteristicId);
    return _valueStreamController.stream
        .where((e) {
          return (e.deviceId == deviceId ||
                  e.deviceId.toLowerCase() == target) &&
              e.characteristicId == characteristicId;
        })
        .map((e) => e.value);
  }

  /// 更新处理器：将事件推入 Stream 控制器，同时触发回调
  void updateScanResult(BleDevice bleDevice) {
    _scanStreamController.add(bleDevice);
    try {
      onScanResultUpdate?.call(bleDevice);
    } catch (_) {}
  }

  void updateConnection(String deviceId, bool isConnected, [String? error]) {
    bleConnectionUpdateStreamController.add((
      deviceId: deviceId,
      isConnected: isConnected,
      error: error,
    ));
    try {
      onConnectionChange?.call(deviceId, isConnected, error);
    } catch (_) {}
    if (!isConnected) {
      // 使用规范化（小写）ID清理设备状态，确保不会因大小写不同而遗漏缓存条目
      // （CacheHandler 内部已进行规范化处理）
      CacheHandler.instance.resetDeviceCache(deviceId);
      _lastConnectionParametersMap.remove(deviceId.toLowerCase());
    }
  }

  void updateCharacteristicValue(
    String deviceId,
    String characteristicId,
    Uint8List value,
    int? timestamp,
  ) {
    characteristicId = BleUuidParser.string(characteristicId);
    _valueStreamController.add((
      deviceId: deviceId,
      characteristicId: characteristicId,
      value: value,
    ));
    try {
      onValueChange?.call(deviceId, characteristicId, value, timestamp);
    } catch (_) {}
  }

  void updateAvailability(AvailabilityState state) {
    _availabilityStreamController.add(state);
    try {
      onAvailabilityChange?.call(state);
    } catch (_) {}
  }

  void updateConnectionParameters(BleConnectionParametersUpdated update) {
    // 使用规范化 ID 作为键（移除之前冗余的 last.deviceId == update.deviceId 检查，
    // 该检查会因大小写不匹配而导致同一设备的重复事件无法正确去重）
    final key = update.deviceId.toLowerCase();
    final last = _lastConnectionParametersMap[key];
    if (last != null &&
        last.interval == update.interval &&
        last.latency == update.latency &&
        last.supervisionTimeout == update.supervisionTimeout &&
        last.status == update.status) {
      return;
    }
    _lastConnectionParametersMap[key] = update;
    try {
      onConnectionParametersChange?.call(update);
    } catch (_) {}
  }

  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    return AvailabilityState.poweredOn;
  }

  Future<bool> enableBluetooth() async => true;

  Future<bool> hasPermissions({bool withAndroidFineLocation = false}) async {
    return true;
  }

  Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {}

  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  });

  Future<void> stopScan();

  Future<bool> isScanning();

  Future<void> connect(
    String deviceId, {
    Duration? connectionTimeout,
    bool autoConnect = false,
    ConnectionPlatformConfig? platformConfig,
  });

  Future<void> disconnect(String deviceId);

  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors,
  );

  Future<void> setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty,
  );

  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
  });

  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  );

  Future<int> requestMtu(String deviceId, int expectedMtu);

  Future<int> readRssi(String deviceId);

  Future<void> requestConnectionPriority(
    String deviceId,
    BleConnectionPriority priority,
  );

  Future<BleConnectionState> getConnectionState(String deviceId);

  Future<List<BleDevice>> getSystemDevices(List<String>? withServices);

  Future<void> setLogLevel(BleLogLevel logLevel) async =>
      UniversalLogger.setLogLevel(logLevel);

  bool receivesAdvertisements(String deviceId) => true;
}

/// Pigeon 桥接平台实现类
///
/// 基于 Pigeon（Flutter 官方推荐的跨平台通信代码生成工具）实现 Dart 与原生层的通信桥接：
/// - [_platformChannel]：Dart 调用原生方法的通道（platform channel）
/// - 实现 [UniversalBleCallbackChannel]：原生层回调 Dart 的通道（callback channel）
///
/// 工作流程：
/// 1. Dart 层方法调用（如 connect、discoverServices）→ 通过 _platformChannel 发送到原生
/// 2. 原生层执行操作后，通过回调通道（onScanResult、onConnectionChanged 等）返回结果
/// 3. 回调方法更新 Stream 控制器和传统回调，实现事件分发
class PigeonPrinterConnectPlatform extends PrinterConnectPlatform
    implements UniversalBleCallbackChannel {
  PigeonPrinterConnectPlatform() {
    _setupChannels();
  }

  late final UniversalBlePlatformChannel _platformChannel;

  void _setupChannels() {
    UniversalBleCallbackChannel.setUp(this);
    _platformChannel = UniversalBlePlatformChannel();
  }

  List<UniversalScanFilter> _convertScanFilters(ScanFilter? filter) {
    if (filter == null) return [];
    return [
      UniversalScanFilter(
        withServices: filter.withServices.toValidUUIDList(),
        withNamePrefix: filter.withNamePrefix,
        withManufacturerData: filter.withManufacturerData,
      ),
    ];
  }

  pigeon.AndroidOptions _convertAndroidOptions(PlatformConfig? config) {
    final androidConfig = config?.android;
    if (androidConfig == null) {
      // 默认扫描传统 BLE 4.x（legacy）广播，适配主流打印机
      return pigeon.AndroidOptions(legacy: true);
    }

    return pigeon.AndroidOptions(
      requestLocationPermission: androidConfig.requestLocationPermission,
      scanMode: androidConfig.scanMode,
      reportDelayMillis: androidConfig.reportDelayMillis,
      callbackType: androidConfig.callbackType,
      matchMode: androidConfig.matchMode,
      numOfMatches: androidConfig.numOfMatches,
      // 默认扫描传统 BLE 4.x（legacy）广播，适配主流打印机
      legacy: androidConfig.legacy ?? true,
    );
  }

  pigeon.ConnectionPlatformConfig _convertConnectionConfig(
    ConnectionPlatformConfig? config,
  ) {
    if (config == null) return pigeon.ConnectionPlatformConfig();
    final apple = config.apple;
    if (apple == null) return pigeon.ConnectionPlatformConfig();
    return pigeon.ConnectionPlatformConfig(
      apple: pigeon.AppleConnectionOptions(
        notifyOnConnection: apple.notifyOnConnection,
        notifyOnDisconnection: apple.notifyOnDisconnection,
        notifyOnNotification: apple.notifyOnNotification,
      ),
    );
  }

  @override
  void onAvailabilityChanged(AvailabilityState state) {
    updateAvailability(state);
  }

  @override
  void onScanResult(UniversalBleScanResult result) {
    final device = BleDevice(
      deviceId: result.deviceId,
      name: result.name,
      rssi: result.rssi,
      manufacturerDataList:
          result.manufacturerDataList
              ?.map(
                (m) => ManufacturerData(
                  m.companyIdentifier,
                  Uint8List.fromList(m.data),
                ),
              )
              .toList() ??
          [],
      services: (result.services ?? const [])
          .map(BleUuidParser.string)
          .toList(),
      serviceData: result.serviceData ?? const {},
      timestamp: result.timestamp,
    );
    updateScanResult(device);
  }

  @override
  void onValueChanged(
    String deviceId,
    String characteristicId,
    Uint8List value,
    int? timestamp,
  ) {
    updateCharacteristicValue(deviceId, characteristicId, value, timestamp);
  }

  @override
  void onConnectionChanged(String deviceId, bool connected, String? error) {
    updateConnection(deviceId, connected, error);
  }

  @override
  void onConnectionParametersUpdated(
    pigeon.BleConnectionParametersUpdated result,
  ) {
    updateConnectionParameters(
      BleConnectionParametersUpdated(
        deviceId: result.deviceId,
        interval: result.interval,
        latency: result.latency,
        supervisionTimeout: result.supervisionTimeout,
        status: result.status,
      ),
    );
  }

  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    return _platformChannel.getBluetoothAvailabilityState();
  }

  @override
  Future<bool> enableBluetooth() async {
    if (!BleCapabilities.supportsBluetoothEnableApi) {
      throw UnsupportedError(
        'enableBluetooth is not supported on this platform',
      );
    }
    // 直接透传原生层的返回值：Android 上该值反映用户在系统弹框中的选择
    // （允许 → true，拒绝 → false）。此前这里丢弃了返回值并恒为 true，
    // 导致用户拒绝开启时仍提示“蓝牙已开启: true”。
    return _platformChannel.enableBluetooth();
  }

  @override
  Future<bool> hasPermissions({bool withAndroidFineLocation = false}) async {
    return _platformChannel.hasPermissions(withAndroidFineLocation);
  }

  @override
  Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {
    await _platformChannel.requestPermissions(withAndroidFineLocation);
  }

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    final filters = _convertScanFilters(scanFilter);
    final androidOptions = _convertAndroidOptions(platformConfig);
    final config = UniversalScanConfig(android: androidOptions);
    await _platformChannel.startScan(
      filters.isNotEmpty ? filters.first : null,
      config,
    );
  }

  @override
  Future<void> stopScan() async {
    await _platformChannel.stopScan();
  }

  @override
  Future<bool> isScanning() async {
    return _platformChannel.isScanning();
  }

  @override
  Future<void> connect(
    String deviceId, {
    Duration? connectionTimeout,
    bool autoConnect = false,
    ConnectionPlatformConfig? platformConfig,
  }) async {
    final config = _convertConnectionConfig(platformConfig);
    await _platformChannel.connect(
      deviceId,
      autoConnect: autoConnect,
      platformConfig: config,
    );
  }

  @override
  Future<void> disconnect(String deviceId) async {
    await _platformChannel.disconnect(deviceId);
  }

  @override
  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors,
  ) async {
    final services = await _platformChannel.discoverServices(
      deviceId,
      withDescriptors,
    );
    return services.map((s) {
      final characteristics =
          s.characteristics
              ?.map(
                (c) => BleCharacteristic.withMetaData(
                  uuid: c.uuid,
                  properties: c.properties
                      .map((p) => _mapCharacteristicProperty(p))
                      .toList(),
                  descriptors: c.descriptors
                      .map((d) => BleDescriptor(uuid: d.uuid))
                      .toList(),
                  deviceId: deviceId,
                  serviceId: s.uuid,
                ),
              )
              .toList() ??
          [];
      final service = BleService(
        uuid: s.uuid,
        characteristics: characteristics,
      );
      return service;
    }).toList();
  }

  CharacteristicProperty _mapCharacteristicProperty(
    pigeon.CharacteristicProperty p,
  ) {
    final index = p.index;
    return CharacteristicProperty.values[index];
  }

  @override
  Future<void> setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty,
  ) async {
    await _platformChannel.setNotifiable(
      deviceId,
      service,
      characteristic,
      bleInputProperty,
    );
  }

  @override
  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
  }) async {
    return _platformChannel.readValue(deviceId, service, characteristic);
  }

  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {
    await _platformChannel.writeValue(
      deviceId,
      service,
      characteristic,
      value,
      bleOutputProperty,
    );
  }

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async {
    return _platformChannel.requestMtu(deviceId, expectedMtu);
  }

  @override
  Future<int> readRssi(String deviceId) async {
    return _platformChannel.readRssi(deviceId);
  }

  @override
  Future<void> requestConnectionPriority(
    String deviceId,
    BleConnectionPriority priority,
  ) async {
    await _platformChannel.requestConnectionPriority(deviceId, priority);
  }

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async {
    return _platformChannel.getConnectionState(deviceId);
  }

  @override
  Future<List<BleDevice>> getSystemDevices(List<String>? withServices) async {
    final devices = await _platformChannel.getSystemDevices(
      withServices ?? const [],
    );
    return devices
        .map(
          (d) => BleDevice(
            deviceId: d.deviceId,
            name: d.name,
            rssi: d.rssi,
            isSystemDevice: true,
            manufacturerDataList:
                d.manufacturerDataList
                    ?.map(
                      (m) => ManufacturerData(
                        m.companyIdentifier,
                        Uint8List.fromList(m.data),
                      ),
                    )
                    .toList() ??
                [],
            services: (d.services ?? const [])
                .map(BleUuidParser.string)
                .toList(),
            serviceData: d.serviceData ?? const {},
            timestamp: d.timestamp,
          ),
        )
        .toList();
  }

  @override
  Future<void> setLogLevel(BleLogLevel logLevel) async {
    await _platformChannel.setLogLevel(logLevel);
  }

  @override
  bool receivesAdvertisements(String deviceId) {
    return true;
  }
}

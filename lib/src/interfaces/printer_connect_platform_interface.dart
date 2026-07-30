import 'dart:async';
import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:printer_connect/src/printer_connect.g.dart'
    hide
        AndroidOptions,
        BleConnectionParametersUpdated,
        CharacteristicProperty;
import 'package:printer_connect/src/printer_connect.g.dart' as pigeon
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

abstract class PrinterConnectPlatform extends PlatformInterface {
  PrinterConnectPlatform() : super(token: _token);

  static final Object _token = Object();

  static PrinterConnectPlatform _instance = PigeonPrinterConnectPlatform();

  static PrinterConnectPlatform get instance => _instance;

  static set instance(PrinterConnectPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // Do not use these directly to push updates
  OnScanResult? onScanResultUpdate;
  OnConnectionChange? onConnectionChange;
  OnValueChange? onValueChange;
  OnAvailabilityChange? onAvailabilityChange;
  OnPairingStateChange? onPairingStateChange;
  OnConnectionParametersChange? onConnectionParametersChange;

  final Map<String, bool> _pairStateMap = {};
  final Map<String, BleConnectionParametersUpdated>
      _lastConnectionParametersMap = {};

  final _scanStreamController = UniversalBleStreamController<BleDevice>();
  final bleConnectionUpdateStreamController =
      UniversalBleStreamController<
          ({String deviceId, bool isConnected, String? error})
        >();
  final _valueStreamController =
      UniversalBleStreamController<
          ({String deviceId, String characteristicId, Uint8List value})
        >();
  final _pairStateStreamController =
      UniversalBleStreamController<({String deviceId, bool isPaired})>();

  /// Send latest availability state upon subscribing
  late final _availabilityStreamController =
      UniversalBleStreamController<AvailabilityState>(
        initialEvent: getBluetoothAvailabilityState,
      );

  Stream<BleDevice> get scanStream => _scanStreamController.stream;

  Stream<AvailabilityState> get availabilityStream =>
      _availabilityStreamController.stream;

  // A BLE device id is a case-insensitive identifier (a MAC on Android/Windows/Linux, a UUID on Apple), but
  // platforms report it in different cases — Android upper-cases MACs, Windows/WinRT lower-cases them
  // (`mac_address_to_str` emits lower-case hex). So we (a) match the event streams case-insensitively, and
  // (b) key all per-device state by a canonical lower-case id (see updatePairingState /
  // updateConnectionParameters / CacheHandler) so a device reported in two cases can't split across map
  // entries. Emitted device ids are left AS the platform reports them, so this is non-breaking for consumers.
  // Hot paths short-circuit on an exact match before lower-casing.
  Stream<bool> connectionStream(String deviceId) {
    final target = deviceId.toLowerCase();
    return bleConnectionUpdateStreamController.stream
        .where((e) => e.deviceId == deviceId || e.deviceId.toLowerCase() == target)
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
          return (e.deviceId == deviceId || e.deviceId.toLowerCase() == target) &&
              e.characteristicId == characteristicId;
        })
        .map((e) => e.value);
  }

  Stream<bool> pairingStateStream(String deviceId) {
    final target = deviceId.toLowerCase();
    return _pairStateStreamController.stream
        .where((e) => e.deviceId == deviceId || e.deviceId.toLowerCase() == target)
        .map((e) => e.isPaired);
  }

  /// Update Handlers
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
      // Clear per-device state by the canonical id so cleanup can't miss an entry stored under another case
      // (CacheHandler normalizes internally).
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

  void updatePairingState(String deviceId, bool isPaired) {
    // Key by the canonical id so the same device reported in another case doesn't create a second entry and
    // slip past this dedup. The emitted deviceId keeps the platform's case.
    final key = deviceId.toLowerCase();
    if (_pairStateMap[key] == isPaired) return;
    _pairStateMap[key] = isPaired;
    _pairStateStreamController.add((deviceId: deviceId, isPaired: isPaired));
    try {
      onPairingStateChange?.call(deviceId, isPaired);
    } catch (_) {}
  }

  void updateConnectionParameters(BleConnectionParametersUpdated update) {
    // Key by the canonical id (dropping the now-redundant last.deviceId == update.deviceId check, which would
    // itself have failed across cases and broken dedup for a device reported in two cases).
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

  Future<AvailabilityState> getBluetoothAvailabilityState();

  Future<bool> enableBluetooth();

  Future<bool> disableBluetooth();

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

  Future<bool> isPaired(String deviceId);

  Future<bool> pair(String deviceId);

  Future<void> unpair(String deviceId);

  Future<BleConnectionState> getConnectionState(String deviceId);

  Future<List<BleDevice>> getSystemDevices(List<String>? withServices);

  Future<void> setLogLevel(BleLogLevel logLevel) async =>
      UniversalLogger.setLogLevel(logLevel);

  bool receivesAdvertisements(String deviceId) => true;
}

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
        withServices: filter.withServices,
        withNamePrefix: filter.withNamePrefix,
        withManufacturerData: filter.withManufacturerData,
      ),
    ];
  }

  pigeon.AndroidOptions _convertAndroidOptions(PlatformConfig? config) {
    final androidConfig = config?.android;
    if (androidConfig == null) return pigeon.AndroidOptions();

    return pigeon.AndroidOptions(
      requestLocationPermission: androidConfig.requestLocationPermission,
      scanMode: androidConfig.scanMode,
      reportDelayMillis: androidConfig.reportDelayMillis,
      callbackType: androidConfig.callbackType,
      matchMode: androidConfig.matchMode,
      numOfMatches: androidConfig.numOfMatches,
      legacy: androidConfig.legacy,
    );
  }

  pigeon.ConnectionPlatformConfig _convertConnectionConfig(
      ConnectionPlatformConfig? config) {
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
  void onPairStateChange(String deviceId, bool isPaired, String? error) {
    updatePairingState(deviceId, isPaired);
  }

  @override
  void onScanResult(UniversalBleScanResult result) {
    final device = BleDevice(
      deviceId: result.deviceId,
      name: result.name,
      rssi: result.rssi,
      manufacturerDataList: result.manufacturerDataList
              ?.map((m) => ManufacturerData(
                    m.companyIdentifier,
                    Uint8List.fromList(m.data),
                  ))
              .toList() ??
          [],
      services: result.services ?? const [],
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
    updateCharacteristicValue(
        deviceId, characteristicId, value, timestamp);
  }

  @override
  void onConnectionChanged(String deviceId, bool connected, String? error) {
    updateConnection(deviceId, connected, error);
  }

  @override
  void onConnectionParametersUpdated(
      pigeon.BleConnectionParametersUpdated result) {
    updateConnectionParameters(BleConnectionParametersUpdated(
      deviceId: result.deviceId,
      interval: result.interval,
      latency: result.latency,
      supervisionTimeout: result.supervisionTimeout,
      status: result.status,
    ));
  }

  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    return _platformChannel.getBluetoothAvailabilityState();
  }

  @override
  Future<bool> enableBluetooth() async {
    try {
      await _platformChannel.enableBluetooth();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> disableBluetooth() async {
    try {
      await _platformChannel.disableBluetooth();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> hasPermissions({bool withAndroidFineLocation = false}) async {
    return _platformChannel.hasPermissions(withAndroidFineLocation);
  }

  @override
  Future<void> requestPermissions({bool withAndroidFineLocation = false}) async {
    await _platformChannel.requestPermissions(withAndroidFineLocation);
  }

  @override
  Future<void> startScan(
      {ScanFilter? scanFilter, PlatformConfig? platformConfig}) async {
    final filters = _convertScanFilters(scanFilter);
    final androidOptions = _convertAndroidOptions(platformConfig);
    final config = UniversalScanConfig(android: androidOptions);
    await _platformChannel.startScan(
        filters.isNotEmpty ? filters.first : null, config);
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
      String deviceId, bool withDescriptors) async {
    final cached = CacheHandler.instance.getServices(deviceId);
    if (cached != null) {
      return cached;
    }

    final services =
        await _platformChannel.discoverServices(deviceId, withDescriptors);
    final result = services.map((s) {
      final characteristics = s.characteristics
              ?.map((c) => BleCharacteristic.withMetaData(
                    uuid: c.uuid,
                    properties: c.properties
                        .map((p) => _mapCharacteristicProperty(p))
                        .toList(),
                    descriptors: c.descriptors
                        .map((d) => BleDescriptor(uuid: d.uuid))
                        .toList(),
                    deviceId: deviceId,
                    serviceId: s.uuid,
                  ))
              .toList() ??
          [];
      final service = BleService(uuid: s.uuid, characteristics: characteristics);
      return service;
    }).toList();
    CacheHandler.instance.saveServices(deviceId, result);
    return result;
  }

  CharacteristicProperty _mapCharacteristicProperty(
      pigeon.CharacteristicProperty p) {
    final index = p.index;
    return CharacteristicProperty.values[index];
  }

  @override
  Future<void> setNotifiable(String deviceId, String service,
      String characteristic, BleInputProperty bleInputProperty) async {
    await _platformChannel.setNotifiable(
        deviceId, service, characteristic, bleInputProperty);
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
        deviceId, service, characteristic, value, bleOutputProperty);
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
      String deviceId, BleConnectionPriority priority) async {
    await _platformChannel.requestConnectionPriority(deviceId, priority);
  }

  @override
  Future<bool> isPaired(String deviceId) async {
    return _platformChannel.isPaired(deviceId);
  }

  @override
  Future<bool> pair(String deviceId) async {
    try {
      await _platformChannel.pair(deviceId);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> unpair(String deviceId) async {
    await _platformChannel.unPair(deviceId);
  }

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async {
    try {
      final connectionState = await _platformChannel.getConnectionState(deviceId);
      return connectionState;
    } catch (e) {
      return BleConnectionState.disconnected;
    }
  }

  @override
  Future<List<BleDevice>> getSystemDevices(List<String>? withServices) async {
    final devices =
        await _platformChannel.getSystemDevices(withServices ?? const []);
    return devices
        .map((d) => BleDevice(
              deviceId: d.deviceId,
              name: d.name,
              rssi: d.rssi,
              manufacturerDataList: d.manufacturerDataList
                      ?.map((m) => ManufacturerData(
                            m.companyIdentifier,
                            Uint8List.fromList(m.data),
                          ))
                      .toList() ??
                  [],
              services: d.services ?? const [],
              timestamp: d.timestamp,
            ))
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

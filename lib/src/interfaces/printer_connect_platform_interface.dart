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
import 'package:printer_connect/src/models/model_exports.dart';
import 'package:printer_connect/src/utils/cache_handler.dart';
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

  final StreamController<BleDevice> _scanStreamController =
      StreamController<BleDevice>.broadcast();

  final StreamController<_ConnectionChangeEvent> _connectionStreamController =
      StreamController<_ConnectionChangeEvent>.broadcast();

  final StreamController<_ValueChangeEvent> _valueStreamController =
      StreamController<_ValueChangeEvent>.broadcast();

  final StreamController<_PairingStateEvent> _pairingStateStreamController =
      StreamController<_PairingStateEvent>.broadcast();

  final StreamController<AvailabilityState> _availabilityStreamController =
      StreamController<AvailabilityState>.broadcast();

  final StreamController<_ConnectionParametersEvent>
      _connectionParametersStreamController =
      StreamController<_ConnectionParametersEvent>.broadcast();

  final Map<String, pigeon.BleConnectionParametersUpdated> _lastParams = {};

  final Map<String, BleConnectionState> _connectionStateCache = {};

  Stream<BleDevice> get scanStream => _scanStreamController.stream;

  Stream<AvailabilityState> get availabilityStream =>
      _availabilityStreamController.stream;

  Stream<bool> connectionStream(String deviceId) {
    return _connectionStreamController.stream
        .where((event) => event.deviceId.toLowerCase() == deviceId.toLowerCase())
        .map((event) => event.isConnected);
  }

  Stream<Uint8List> characteristicValueStream(
      String deviceId, String characteristicId) {
    return _valueStreamController.stream
        .where((event) =>
            event.deviceId.toLowerCase() == deviceId.toLowerCase() &&
            event.characteristic == characteristicId)
        .map((event) => event.value);
  }

  Stream<bool> pairingStateStream(String deviceId) {
    return _pairingStateStreamController.stream
        .where((event) => event.deviceId.toLowerCase() == deviceId.toLowerCase())
        .map((event) => event.isPaired);
  }

  void updateScanResult(BleDevice device) {
    _scanStreamController.add(device);
  }

  void updateConnection(String deviceId, bool isConnected, [String? error]) {
    final state = isConnected
        ? BleConnectionState.connected
        : BleConnectionState.disconnected;
    _connectionStateCache[deviceId.toLowerCase()] = state;
    _connectionStreamController
        .add(_ConnectionChangeEvent(deviceId, isConnected));
    if (error != null) {
      UniversalLogger.logW(
          'Connection error for $deviceId: $error');
    }
  }

  void updateCharacteristicValue(
      String deviceId, String characteristic, Uint8List value,
      {int? timestamp, String? service}) {
    _valueStreamController.add(
        _ValueChangeEvent(deviceId, service ?? '', characteristic, value));
  }

  void updateAvailability(AvailabilityState state) {
    _availabilityStreamController.add(state);
  }

  void updatePairingState(String deviceId, bool isPaired) {
    _pairingStateStreamController
        .add(_PairingStateEvent(deviceId, isPaired));
  }

  void updateConnectionParameters(
      String deviceId, pigeon.BleConnectionParametersUpdated params) {
    final key = deviceId.toLowerCase();
    final last = _lastParams[key];
    if (last != null &&
        last.interval == params.interval &&
        last.latency == params.latency &&
        last.supervisionTimeout == params.supervisionTimeout &&
        last.status == params.status) {
      return;
    }
    _lastParams[key] = params;
    _connectionParametersStreamController
        .add(_ConnectionParametersEvent(deviceId, params));
  }

  Future<AvailabilityState> getBluetoothAvailabilityState();

  Future<bool> enableBluetooth();

  Future<bool> disableBluetooth();

  Future<bool> hasPermissions({bool withAndroidFineLocation});

  Future<void> requestPermissions({bool withAndroidFineLocation});

  Future<void> startScan(
      {ScanFilter? scanFilter, PlatformConfig? platformConfig});

  Future<void> stopScan();

  Future<bool> isScanning();

  Future<void> connect(String deviceId,
      {bool? autoConnect, ConnectionPlatformConfig? platformConfig});

  Future<void> disconnect(String deviceId);

  Future<List<BleService>> discoverServices(
      String deviceId, bool withDescriptors);

  Future<void> setNotifiable(String deviceId, String service,
      String characteristic, BleInputProperty bleInputProperty);

  Future<Uint8List> readValue(String deviceId, String service,
      String characteristic);

  Future<void> writeValue(String deviceId, String service,
      String characteristic, Uint8List value,
      BleOutputProperty bleOutputProperty);

  Future<int> requestMtu(String deviceId, int expectedMtu);

  Future<int> readRssi(String deviceId);

  Future<void> requestConnectionPriority(
      String deviceId, BleConnectionPriority priority);

  Future<bool> isPaired(String deviceId);

  Future<bool> pair(String deviceId);

  Future<void> unpair(String deviceId);

  BleConnectionState getConnectionState(String deviceId);

  Future<List<BleDevice>> getSystemDevices(List<String> withServices);

  Future<void> setLogLevel(BleLogLevel logLevel);

  bool receivesAdvertisements(String deviceId);
}

class _ConnectionChangeEvent {
  final String deviceId;
  final bool isConnected;
  _ConnectionChangeEvent(this.deviceId, this.isConnected);
}

class _ValueChangeEvent {
  final String deviceId;
  final String service;
  final String characteristic;
  final Uint8List value;
  _ValueChangeEvent(this.deviceId, this.service, this.characteristic, this.value);
}

class _PairingStateEvent {
  final String deviceId;
  final bool isPaired;
  _PairingStateEvent(this.deviceId, this.isPaired);
}

class _ConnectionParametersEvent {
  final String deviceId;
  final pigeon.BleConnectionParametersUpdated params;
  _ConnectionParametersEvent(this.deviceId, this.params);
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
        deviceId, characteristicId, value,
        timestamp: timestamp);
  }

  @override
  void onConnectionChanged(String deviceId, bool connected, String? error) {
    updateConnection(deviceId, connected, error);
  }

  @override
  void onConnectionParametersUpdated(
      pigeon.BleConnectionParametersUpdated result) {
    updateConnectionParameters(result.deviceId, result);
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
  Future<void> connect(String deviceId,
      {bool? autoConnect,
      ConnectionPlatformConfig? platformConfig}) async {
    final config = _convertConnectionConfig(platformConfig);
    await _platformChannel.connect(deviceId,
        autoConnect: autoConnect, platformConfig: config);
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
  Future<Uint8List> readValue(String deviceId, String service,
      String characteristic) async {
    return _platformChannel.readValue(deviceId, service, characteristic);
  }

  @override
  Future<void> writeValue(String deviceId, String service,
      String characteristic, Uint8List value,
      BleOutputProperty bleOutputProperty) async {
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
  BleConnectionState getConnectionState(String deviceId) {
    return _connectionStateCache[deviceId.toLowerCase()] ??
        BleConnectionState.disconnected;
  }

  @override
  Future<List<BleDevice>> getSystemDevices(List<String> withServices) async {
    final devices =
        await _platformChannel.getSystemDevices(withServices);
    return devices
        .map((d) => BleDevice(
              deviceId: d.deviceId,
              name: d.name,
              rssi: d.rssi,
            ))
        .toList();
  }

  @override
  Future<void> setLogLevel(BleLogLevel logLevel) async {
    await _platformChannel.setLogLevel(logLevel);
  }

  @override
  bool receivesAdvertisements(String deviceId) {
    return false;
  }
}
import 'dart:async';
import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:printer_connect/src/printer_connect.g.dart'
    hide
        AndroidOptions,
        AppleConnectionOptions,
        ConnectionPlatformConfig,
        BleConnectionParametersUpdated,
        CharacteristicProperty;
import 'package:printer_connect/src/printer_connect.g.dart' as pigeon
    show
        AndroidOptions,
        AppleConnectionOptions,
        ConnectionPlatformConfig,
        BleConnectionParametersUpdated;
import 'package:printer_connect/src/models/model_exports.dart';

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

  Stream<BleDevice> get scanStream => _scanStreamController.stream;

  Stream<AvailabilityState> get availabilityStream =>
      _availabilityStreamController.stream;

  Stream<BleConnectionState> connectionStream(String deviceId) {
    return _connectionStreamController.stream
        .where((event) => event.deviceId == deviceId)
        .map((event) => event.state);
  }

  Stream<Uint8List> characteristicValueStream(
      String deviceId, String characteristicId) {
    return _valueStreamController.stream
        .where((event) =>
            event.deviceId == deviceId &&
            event.characteristic == characteristicId)
        .map((event) => event.value);
  }

  Stream<bool> pairingStateStream(String deviceId) {
    return _pairingStateStreamController.stream
        .where((event) => event.deviceId == deviceId)
        .map((event) => event.isPaired);
  }

  void updateScanResult(BleDevice device) {
    _scanStreamController.add(device);
  }

  void updateConnection(String deviceId, BleConnectionState state) {
    _connectionStreamController
        .add(_ConnectionChangeEvent(deviceId, state));
  }

  void updateCharacteristicValue(
      String deviceId, String service, String characteristic, Uint8List value) {
    _valueStreamController
        .add(_ValueChangeEvent(deviceId, service, characteristic, value));
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
      {Duration? connectionTimeout,
      bool autoConnect,
      ConnectionPlatformConfig? platformConfig});

  Future<void> disconnect(String deviceId);

  Future<List<BleService>> discoverServices(
      String deviceId, bool withDescriptors);

  Future<void> setNotifiable(String deviceId, String service,
      String characteristic, BleInputProperty bleInputProperty);

  Future<Uint8List> readValue(String deviceId, String service,
      String characteristic, {Duration? timeout});

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

  Future<BleConnectionState> getConnectionState(String deviceId);

  Future<List<BleDevice>> getSystemDevices(List<String>? withServices);

  Future<void> setLogLevel(BleLogLevel logLevel);

  bool receivesAdvertisements(String deviceId);
}

class _ConnectionChangeEvent {
  final String deviceId;
  final BleConnectionState state;
  _ConnectionChangeEvent(this.deviceId, this.state);
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
        withManufacturerData: filter.withManufacturerData
            ?.map((m) => ManufacturerDataFilter(
                  companyId: m.companyId,
                  data: m.data.toList(),
                  mask: m.mask?.toList(),
                ))
            .toList(),
        withLocalName: filter.withNamePrefix,
      ),
    ];
  }

  pigeon.AndroidOptions _convertAndroidOptions(PlatformConfig? config) {
    final androidConfig = config?.android;
    if (androidConfig == null) return pigeon.AndroidOptions();
    return pigeon.AndroidOptions(
      scanMode: AndroidScanMode.values[androidConfig.scanMode],
      callbackType: AndroidScanCallbackType.values[androidConfig.callbackType],
      matchMode: AndroidScanMatchMode.values[androidConfig.matchMode],
      numOfMatches: AndroidScanNumOfMatches.values[androidConfig.numOfMatches],
    );
  }

  pigeon.ConnectionPlatformConfig _convertConnectionConfig(
      ConnectionPlatformConfig? config) {
    if (config == null) return pigeon.ConnectionPlatformConfig();
    final apple = config.apple;
    if (apple == null) return pigeon.ConnectionPlatformConfig();
    return pigeon.ConnectionPlatformConfig(
      apple: pigeon.AppleConnectionOptions(
        shouldRestoreState: apple.enableAutoReceiveData,
      ),
    );
  }

  @override
  void onAvailabilityChanged(AvailabilityState state) {
    updateAvailability(state);
  }

  @override
  void onPairStateChange(String peripheralId, bool isPaired) {
    updatePairingState(peripheralId, isPaired);
  }

  @override
  void onScanResult(UniversalBleScanResult result) {
    final device = BleDevice(
      deviceId: result.peripheralId,
      name: result.name ?? '',
      rssi: result.rssi,
      manufacturerDataList: result.manufacturerData
              ?.map((m) => ManufacturerData(
                    companyId: m.id,
                    data: Uint8List.fromList(m.data),
                  ))
              .toList() ??
          [],
      services: result.serviceUuids ?? const [],
    );
    updateScanResult(device);
  }

  @override
  void onValueChanged(
    String peripheralId,
    String serviceId,
    String characteristicId,
    List<int> value,
  ) {
    updateCharacteristicValue(
        peripheralId, serviceId, characteristicId, Uint8List.fromList(value));
  }

  @override
  void onConnectionChanged(String peripheralId, BleConnectionState state) {
    updateConnection(peripheralId, state);
  }

  @override
  void onConnectionParametersUpdated(
      pigeon.BleConnectionParametersUpdated result) {
    updateConnectionParameters('', result);
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
    return _platformChannel.hasPermissions();
  }

  @override
  Future<void> requestPermissions({bool withAndroidFineLocation = false}) async {
    await _platformChannel.requestPermissions();
  }

  @override
  Future<void> startScan(
      {ScanFilter? scanFilter, PlatformConfig? platformConfig}) async {
    final filters = _convertScanFilters(scanFilter);
    final androidOptions = _convertAndroidOptions(platformConfig);
    await _platformChannel.startScan(filters, androidOptions);
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
      {Duration? connectionTimeout,
      bool autoConnect = false,
      ConnectionPlatformConfig? platformConfig}) async {
    final config = _convertConnectionConfig(platformConfig);
    await _platformChannel.connect(deviceId, config);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    await _platformChannel.disconnect(deviceId);
  }

  @override
  Future<List<BleService>> discoverServices(
      String deviceId, bool withDescriptors) async {
    final services = await _platformChannel.discoverServices(deviceId);
    return services
        .map((s) => BleService(uuid: s.uuid))
        .toList();
  }

  @override
  Future<void> setNotifiable(String deviceId, String service,
      String characteristic, BleInputProperty bleInputProperty) async {
    await _platformChannel.setNotifiable(
        deviceId, service, characteristic, bleInputProperty);
  }

  @override
  Future<Uint8List> readValue(String deviceId, String service,
      String characteristic, {Duration? timeout}) async {
    final result =
        await _platformChannel.readValue(deviceId, service, characteristic);
    return result.value != null ? Uint8List.fromList(result.value!) : Uint8List(0);
  }

  @override
  Future<void> writeValue(String deviceId, String service,
      String characteristic, Uint8List value,
      BleOutputProperty bleOutputProperty) async {
    await _platformChannel.writeValue(
        deviceId, service, characteristic, value.toList(), bleOutputProperty);
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
    return _platformChannel.getConnectionState(deviceId);
  }

  @override
  Future<List<BleDevice>> getSystemDevices(List<String>? withServices) async {
    final devices = await _platformChannel.getSystemDevices();
    return devices
        .map((d) => BleDevice(
              deviceId: d.peripheralId,
              name: d.name ?? '',
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
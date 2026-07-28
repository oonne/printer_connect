import 'package:printer_connect/printer_connect.dart';

extension BleDeviceExtension on BleDevice {
  Stream<bool> get connectionStream =>
      PrinterConnect.connectionStream(deviceId);

  Stream<bool> get pairingStateStream =>
      PrinterConnect.pairingStateStream(deviceId);

  bool get isConnected =>
      PrinterConnect.getConnectionState(deviceId) ==
      BleConnectionState.connected;

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

  Future<void> disconnect() => PrinterConnect.disconnect(deviceId);

  Future<int> requestMtu(int expectedMtu, {String? queueId}) =>
      PrinterConnect.requestMtu(deviceId, expectedMtu);

  Future<bool> isPaired({
    Duration? timeout,
  }) {
    return PrinterConnect.isPaired(
      deviceId,
      timeout: timeout,
    );
  }

  Future<void> pair({
    Duration? timeout,
  }) {
    return PrinterConnect.pair(
      deviceId,
      timeout: timeout,
    );
  }

  Future<void> unpair() => PrinterConnect.unpair(deviceId);

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
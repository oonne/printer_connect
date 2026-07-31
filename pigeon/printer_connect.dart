import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/printer_connect.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/example/printer_connect/PrinterConnect.g.kt',
    swiftOut: 'ios/Classes/PrinterConnect.g.swift',
    kotlinOptions: KotlinOptions(package: 'com.example.printer_connect'),
    swiftOptions: SwiftOptions(),
  ),
)
class UniversalBleScanResult {
  final String deviceId;
  final String? name;
  final bool? isPaired;
  final int? rssi;
  final List<UniversalManufacturerData>? manufacturerDataList;
  final Map<String, Uint8List>? serviceData;
  final List<String>? services;
  final int? timestamp;

  UniversalBleScanResult({
    required this.name,
    required this.deviceId,
    required this.isPaired,
    required this.rssi,
    required this.manufacturerDataList,
    required this.serviceData,
    required this.services,
    required this.timestamp,
  });
}

enum BleLogLevel { none, error, warning, info, debug, verbose }

enum AvailabilityState {
  unknown,
  resetting,
  unsupported,
  unauthorized,
  poweredOff,
  poweredOn,
}

enum BleConnectionState { connected, disconnected, connecting, disconnecting }

enum BleInputProperty { disabled, notification, indication }

enum BleOutputProperty { withResponse, withoutResponse }

enum BleConnectionPriority { balanced, highPerformance, lowPower }

enum AndroidScanMode { balanced, lowLatency, lowPower, opportunistic }

enum AndroidScanCallbackType {
  allMatches,
  firstMatch,
  matchLost,
  allMatchesAutoBatch,
}

enum AndroidScanMatchMode { aggressive, sticky }

enum AndroidScanNumOfMatches { one, few, max }

enum CharacteristicProperty {
  broadcast,
  read,
  writeWithoutResponse,
  write,
  notify,
  indicate,
  authenticatedSignedWrites,
  extendedProperties,
}

class UniversalBleService {
  String uuid;
  List<UniversalBleCharacteristic>? characteristics;

  UniversalBleService(this.uuid, this.characteristics);
}

class UniversalBleCharacteristic {
  String uuid;
  List<CharacteristicProperty> properties;
  List<UniversalBleDescriptor> descriptors;

  UniversalBleCharacteristic(this.uuid, this.properties, this.descriptors);
}

class UniversalBleDescriptor {
  String uuid;

  UniversalBleDescriptor(this.uuid);
}

class BleConnectionParametersUpdated {
  final String deviceId;
  final int interval;
  final int latency;
  final int supervisionTimeout;
  final int status;

  BleConnectionParametersUpdated({
    required this.deviceId,
    required this.interval,
    required this.latency,
    required this.supervisionTimeout,
    required this.status,
  });
}

class AndroidOptions {
  bool? requestLocationPermission;
  AndroidScanMode? scanMode;
  int? reportDelayMillis;
  List<AndroidScanCallbackType>? callbackType;
  AndroidScanMatchMode? matchMode;
  AndroidScanNumOfMatches? numOfMatches;
  bool? legacy;

  AndroidOptions({
    this.requestLocationPermission,
    this.scanMode,
    this.reportDelayMillis,
    this.callbackType,
    this.matchMode,
    this.numOfMatches,
    this.legacy,
  });
}

class UniversalScanConfig {
  AndroidOptions? android;

  UniversalScanConfig(this.android);
}

class UniversalScanFilter {
  final List<String> withServices;
  final List<String> withNamePrefix;
  final List<ManufacturerDataFilter> withManufacturerData;

  UniversalScanFilter(
    this.withServices,
    this.withNamePrefix,
    this.withManufacturerData,
  );
}

class ManufacturerDataFilter {
  int companyIdentifier;
  Uint8List? payloadPrefix;
  Uint8List? payloadMask;

  ManufacturerDataFilter({
    required this.companyIdentifier,
    this.payloadPrefix,
    this.payloadMask,
  });
}

class UniversalManufacturerData {
  final int companyIdentifier;
  final Uint8List data;

  UniversalManufacturerData({
    required this.companyIdentifier,
    required this.data,
  });
}

class AppleConnectionOptions {
  bool? notifyOnConnection;
  bool? notifyOnDisconnection;
  bool? notifyOnNotification;

  AppleConnectionOptions({
    this.notifyOnConnection,
    this.notifyOnDisconnection,
    this.notifyOnNotification,
  });
}

class ConnectionPlatformConfig {
  AppleConnectionOptions? apple;

  ConnectionPlatformConfig({this.apple});
}

@HostApi()
abstract class UniversalBlePlatformChannel {
  @async
  AvailabilityState getBluetoothAvailabilityState();
  bool hasPermissions(bool withAndroidFineLocation);
  @async
  void requestPermissions(bool withAndroidFineLocation);
  @async
  bool enableBluetooth();
  @async
  bool disableBluetooth();
  void startScan(UniversalScanFilter? filter, UniversalScanConfig? config);
  void stopScan();
  bool isScanning();
  void connect(
    String deviceId, {
    bool? autoConnect,
    ConnectionPlatformConfig? platformConfig,
  });
  void disconnect(String deviceId);
  @async
  void setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty,
  );
  @async
  List<UniversalBleService> discoverServices(
    String deviceId,
    bool withDescriptors,
  );
  @async
  Uint8List readValue(String deviceId, String service, String characteristic);
  @async
  int requestMtu(String deviceId, int expectedMtu);
  @async
  void writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  );
  @async
  bool isPaired(String deviceId);
  @async
  bool pair(String deviceId);
  void unPair(String deviceId);
  @async
  List<UniversalBleScanResult> getSystemDevices(List<String> withServices);
  BleConnectionState getConnectionState(String deviceId);
  @async
  int readRssi(String deviceId);
  @async
  void requestConnectionPriority(
    String deviceId,
    BleConnectionPriority priority,
  );
  void setLogLevel(BleLogLevel logLevel);
}

@FlutterApi()
abstract class UniversalBleCallbackChannel {
  void onAvailabilityChanged(AvailabilityState state);
  void onPairStateChange(String deviceId, bool isPaired, String? error);
  void onScanResult(UniversalBleScanResult result);
  void onValueChanged(
    String deviceId,
    String characteristicId,
    Uint8List value,
    int? timestamp,
  );
  void onConnectionChanged(String deviceId, bool connected, String? error);
  void onConnectionParametersUpdated(BleConnectionParametersUpdated update);
}

void main() {
  Pigeon.runWithOptions(
    PigeonOptions(
      input: 'pigeon/printer_connect.dart',
      dartOut: 'lib/src/printer_connect.g.dart',
      kotlinOut:
          'android/src/main/kotlin/com/example/printer_connect/PrinterConnect.g.kt',
      swiftOut: 'ios/Classes/PrinterConnect.g.swift',
      kotlinOptions: KotlinOptions(package: 'com.example.printer_connect'),
      swiftOptions: SwiftOptions(),
    ),
  );
}

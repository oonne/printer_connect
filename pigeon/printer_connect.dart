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
enum BleLogLevel { verbose, debug, info, warning, error, wtf, none }

enum AvailabilityState {
  unknown,
  resetting,
  unsupported,
  unauthorized,
  poweredOff,
  poweredOn,
}

enum BleConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

enum BleInputProperty {
  disabled,
  notification,
  indication,
}

enum BleOutputProperty {
  none,
  write,
  writeWithoutResponse,
}

enum BleConnectionPriority {
  balanced,
  highPerformance,
  lowPower,
}

enum AndroidScanMode {
  lowPowered,
  balanced,
  lowLatency,
}

enum AndroidScanCallbackType {
  default_,
  firstMatch,
  lose,
  matched,
}

enum AndroidScanMatchMode {
  default_,
  sticky,
}

enum AndroidScanNumOfMatches {
  one,
  few,
  many,
}

enum CharacteristicProperty {
  read,
  write,
  writeWithoutResponse,
  notify,
  indicate,
  broadcast,
  extendedSbleProps,
  signedWrite,
}

class UniversalBleScanResult {
  UniversalBleScanResult({
    required this.peripheralId,
    this.name,
    required this.rssi,
    this.manufacturerData,
    this.serviceData,
    this.serviceUuids,
    this.txPowerLevel,
  });

  String peripheralId;
  String? name;
  int rssi;
  List<UniversalManufacturerData>? manufacturerData;
  List<int>? serviceData;
  List<String>? serviceUuids;
  int? txPowerLevel;
}

class UniversalManufacturerData {
  UniversalManufacturerData({required this.id, required this.data});

  int id;
  List<int> data;
}

class UniversalBleService {
  UniversalBleService({required this.uuid, required this.isPrimary});

  String uuid;
  bool isPrimary;
}

class UniversalBleCharacteristic {
  UniversalBleCharacteristic({
    required this.uuid,
    required this.properties,
    this.value,
  });

  String uuid;
  List<CharacteristicProperty> properties;
  List<int>? value;
}

class UniversalBleDescriptor {
  UniversalBleDescriptor({required this.uuid, this.value});

  String uuid;
  List<int>? value;
}

class AndroidOptions {
  AndroidOptions({
    this.scanMode,
    this.callbackType,
    this.matchMode,
    this.numOfMatches,
  });

  AndroidScanMode? scanMode;
  AndroidScanCallbackType? callbackType;
  AndroidScanMatchMode? matchMode;
  AndroidScanNumOfMatches? numOfMatches;
}

class UniversalScanConfig {
  UniversalScanConfig({this.scanFilters, this.androidOptions});

  List<UniversalScanFilter>? scanFilters;
  AndroidOptions? androidOptions;
}

class UniversalScanFilter {
  UniversalScanFilter({
    this.withServices,
    this.withManufacturerData,
    this.withLocalName,
    this.withLocalNamePrefix,
    this.withDeviceId,
    this.exclusionFilters,
  });

  List<String>? withServices;
  List<ManufacturerDataFilter>? withManufacturerData;
  String? withLocalName;
  List<String>? withLocalNamePrefix;
  List<String>? withDeviceId;
  List<UniversalScanFilter>? exclusionFilters;
}

class ManufacturerDataFilter {
  ManufacturerDataFilter({
    required this.companyId,
    this.data,
    this.mask,
  });

  int companyId;
  List<int>? data;
  List<int>? mask;
}

class AppleConnectionOptions {
  AppleConnectionOptions({
    this.shouldRestoreState,
    this.notifyOnConnection,
    this.notifyOnDisconnection,
    this.notifyOnNotification,
  });

  bool? shouldRestoreState;
  bool? notifyOnConnection;
  bool? notifyOnDisconnection;
  bool? notifyOnNotification;
}

class ConnectionPlatformConfig {
  ConnectionPlatformConfig({this.apple});

  AppleConnectionOptions? apple;
}

class BleConnectionParametersUpdated {
  BleConnectionParametersUpdated({
    required this.mtu,
    required this.deviceId,
    this.interval,
    this.latency,
    this.supervisionTimeout,
    this.status,
  });

  int mtu;
  String deviceId;
  int? interval;
  int? latency;
  int? supervisionTimeout;
  int? status;
}

@HostApi()
abstract class UniversalBlePlatformChannel {
  @async
  AvailabilityState getBluetoothAvailabilityState();
  @async
  bool hasPermissions();
  @async
  bool requestPermissions();
  @async
  void enableBluetooth();
  @async
  void disableBluetooth();
  @async
  void startScan(
    List<UniversalScanFilter> filters,
    AndroidOptions androidOptions,
  );
  @async
  void stopScan();
  @async
  bool isScanning();
  @async
  void connect(String peripheralId, ConnectionPlatformConfig config);
  @async
  void disconnect(String peripheralId);
  @async
  void setNotifiable(
    String peripheralId,
    String serviceId,
    String characteristicId,
    BleInputProperty value,
  );
  @async
  List<UniversalBleService> discoverServices(String peripheralId);
  @async
  UniversalBleCharacteristic readValue(
    String peripheralId,
    String serviceId,
    String characteristicId,
  );
  @async
  int requestMtu(String peripheralId, int mtu);
  @async
  void writeValue(
    String peripheralId,
    String serviceId,
    String characteristicId,
    List<int> value,
    BleOutputProperty bleOutputProperty,
  );
  @async
  bool isPaired(String peripheralId);
  @async
  void pair(String peripheralId);
  @async
  void unPair(String peripheralId);
  @async
  List<UniversalBleScanResult> getSystemDevices({List<String>? withServices});
  @async
  BleConnectionState getConnectionState(String peripheralId);
  @async
  int readRssi(String peripheralId);
  @async
  void requestConnectionPriority(
    String peripheralId,
    BleConnectionPriority priority,
  );
  @async
  void setLogLevel(BleLogLevel level);
}

@FlutterApi()
abstract class UniversalBleCallbackChannel {
  void onAvailabilityChanged(AvailabilityState state);
  void onPairStateChange(String peripheralId, bool isPaired);
  void onScanResult(UniversalBleScanResult result);
  void onValueChanged(
    String peripheralId,
    String serviceId,
    String characteristicId,
    List<int> value,
  );
  void onConnectionChanged(String peripheralId, BleConnectionState state);
  void onConnectionParametersUpdated(BleConnectionParametersUpdated result);
}

void main() {
  Pigeon.runWithOptions(PigeonOptions(
    input: 'pigeon/printer_connect.dart',
    dartOut: 'lib/src/printer_connect.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/example/printer_connect/PrinterConnect.g.kt',
    swiftOut: 'ios/Classes/PrinterConnect.g.swift',
    kotlinOptions: KotlinOptions(package: 'com.example.printer_connect'),
    swiftOptions: SwiftOptions(),
  ));
}
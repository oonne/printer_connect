# printer_connect

[![pub package](https://img.shields.io/badge/pub-0.0.1-blue.svg)](https://pub.dev/packages/printer_connect)

**printer_connect** is a cross-platform (Android/iOS) BLE (Bluetooth Low Energy) plugin for Flutter. It provides a comprehensive Client Mode (Central) API for scanning, connecting, and communicating with BLE devices such as Bluetooth printers.

> **Note:** This plugin only implements **Client Mode (Central)**. Peripheral Mode is not supported. Only Android and iOS platforms are supported.

---

## Features

- ✅ **Permission Management** — Check and request Bluetooth / location permissions
- ✅ **Device Scanning** — Start/stop BLE scanning with filters (services, manufacturer data, name prefix, exclusion filters)
- ✅ **Device Connection** — Connect, disconnect, and monitor connection state
- ✅ **Auto Reconnect** — Automatic reconnection when device becomes available
- ✅ **Service Discovery** — Discover GATT services and characteristics (with optional descriptors)
- ✅ **Data Read/Write** — Read characteristics, write data (with/without response)
- ✅ **Notifications & Indications** — Subscribe to characteristic value changes
- ✅ **MTU Negotiation** — Request and negotiate Maximum Transmission Unit
- ✅ **RSSI Reading** — Read signal strength from connected devices
- ✅ **Connection Priority** — Request connection priority (balanced/high-performance/low-power) (Android only)
- ✅ **Pairing Management** — Pair, unpair, and monitor pairing state
- ✅ **Bluetooth State** — Monitor Bluetooth availability and toggle (Android only)
- ✅ **Platform Config** — Platform-specific options (scan mode, connection options)
- ✅ **Command Queue** — Configurable command execution queue (global/per-device/none)
- ✅ **Extensions** — Convenience extensions on BleDevice, BleCharacteristic, BleService

---

## API Support Table (Client Mode)

| Category | Method | Android | iOS |
|----------|--------|:-------:|:---:|
| **Permissions** | `hasPermissions()` | ✔️ | ✔️ |
| | `requestPermissions()` | ✔️ | ✔️ |
| **Scanning** | `startScan()` | ✔️ | ✔️ |
| | `stopScan()` | ✔️ | ✔️ |
| | `isScanning()` | ✔️ | ✔️ |
| | `scanStream` | ✔️ | ✔️ |
| **Connection** | `connect()` | ✔️ | ✔️ |
| | `disconnect()` | ✔️ | ✔️ |
| | `getConnectionState()` | ✔️ | ✔️ |
| | `connectionStream()` | ✔️ | ✔️ |
| | `getSystemDevices()` | ✔️ | ✔️ |
| **Service Discovery** | `discoverServices()` | ✔️ | ✔️ |
| **Data I/O** | `read()` | ✔️ | ✔️ |
| | `write()` | ✔️ | ✔️ |
| | `subscribeNotifications()` | ✔️ | ✔️ |
| | `subscribeIndications()` | ✔️ | ✔️ |
| | `unsubscribe()` | ✔️ | ✔️ |
| | `characteristicValueStream()` | ✔️ | ✔️ |
| **MTU** | `requestMtu()` | ✔️ | ⏺ |
| **RSSI** | `readRssi()` | ✔️ | ✔️ |
| **Connection Priority** | `requestConnectionPriority()` | ✔️ | ❌ |
| **Pairing** | `pair()` | ✔️ | ❌ |
| | `isPaired()` | ✔️ | ❌ |
| | `unpair()` | ✔️ | ❌ |
| | `pairingStateStream()` | ✔️ | ⏺ |
| **Bluetooth State** | `getBluetoothAvailabilityState()` | ✔️ | ✔️ |
| | `availabilityStream` | ✔️ | ✔️ |
| | `enableBluetooth()` | ✔️ | ❌ |
| | `disableBluetooth()` | ✔️ | ❌ |
| **Other** | `setLogLevel()` | ✔️ | ✔️ |
| | `receivesAdvertisements()` | ✔️ | ✔️ |

**Legend:** ✔️ = Full support, ⏺ = Partial/system-managed, ❌ = Not supported

---

## Getting Started

### 1. Add Dependency

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  printer_connect: ^0.0.1
```

### 2. Android Setup

Add the following permissions and feature declarations to your **AndroidManifest.xml** (`android/app/src/main/AndroidManifest.xml`):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.your.company.your_app">

    <!-- Bluetooth permissions -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <!-- Required for BLE scanning -->
    <uses-feature android:name="android.hardware.bluetooth" android:required="true" />
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
</manifest>
```

**Android 12+ (API 31+)** requires runtime permission requests for `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`. The plugin handles this via `requestPermissions()`.

### 3. iOS Setup

Add the following usage description keys to your **Info.plist** (`ios/Runner/Info.plist`):

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to BLE devices.</string>
<key>NSBluetoothWhenInUseUsageDescription</key>
<string>This app uses Bluetooth to connect to BLE devices when the app is in use.</string>
```

The plugin requires iOS 13.0+.

---

## Usage Examples

### Import the Package

```dart
import 'package:printer_connect/printer_connect.dart';
```

### Check & Request Permissions

```dart
// Check if permissions are granted
bool hasPerm = await PrinterConnect.hasPermissions();
if (!hasPerm) {
  // Request permissions (handles Android/iOS automatically)
  await PrinterConnect.requestPermissions();
}

// On Android 12+, optionally request fine location permission
bool hasFinePerm = await PrinterConnect.hasPermissions(withAndroidFineLocation: true);
if (!hasFinePerm) {
  await PrinterConnect.requestPermissions(withAndroidFineLocation: true);
}
```

### Scan for Devices

```dart
// Listen to scan results
PrinterConnect.scanStream.listen((BleDevice device) {
  print('Discovered: ${device.name} - ${device.deviceId}');
});

// Start scanning with optional filter
await PrinterConnect.startScan(
  scanFilter: ScanFilter(
    withServices: ['180A'],          // Filter by service UUIDs
    withNamePrefix: ['MyPrinter'],   // Filter by device name prefix
    withManufacturerData: [           // Filter by manufacturer data
      ManufacturerDataFilter(
        companyIdentifier: 0x004C,    // Apple company ID
        payloadPrefix: Uint8List.fromList([0x01, 0x02]), // Expected payload prefix
      ),
    ],
    exclusionFilters: [               // Exclusion filters
      ExclusionFilter(
        services: ['1800'],
      ),
    ],
  ),
  // Optional platform config
  platformConfig: PlatformConfig(
    android: AndroidOptions(
      scanMode: AndroidScanMode.lowLatency,
      reportDelayMillis: 100,
    ),
  ),
);

// Stop scanning
await PrinterConnect.stopScan();

// Check if currently scanning
bool scanning = await PrinterConnect.isScanning();
```

### Connect to a Device

```dart
// Connect to a device by its ID
await PrinterConnect.connect(deviceId);

// Connect with auto-reconnect
await PrinterConnect.connect(
  deviceId,
  autoConnect: true,
  timeout: const Duration(seconds: 30),
);

// Connect with iOS background connection options
await PrinterConnect.connect(
  deviceId,
  platformConfig: ConnectionPlatformConfig(
    apple: AppleConnectionOptions(
      notifyOnConnection: true,
      notifyOnDisconnection: true,
      notifyOnNotification: true,
    ),
  ),
);

// Monitor connection state via stream
PrinterConnect.connectionStream(deviceId).listen((bool isConnected) {
  print('Connection state: ${isConnected ? "connected" : "disconnected"}');
});

// Get current connection state
BleConnectionState state = await PrinterConnect.getConnectionState(deviceId);
print('Connection state: $state');

// Disconnect
await PrinterConnect.disconnect(deviceId);
```

### Discover Services

```dart
// Discover services
List<BleService> services = await PrinterConnect.discoverServices(deviceId);
for (final service in services) {
  print('Service: ${service.uuid}');
  for (final char in service.characteristics) {
    print('  Characteristic: ${char.uuid}');
    for (final desc in char.descriptors) {
      print('    Descriptor: ${desc.uuid}');
    }
  }
}

// Or use extensions on BleDevice
final device = await PrinterConnect.scanStream.first;
final services = await device.discoverServices();
final service = await device.getService('180A');
final characteristic = await device.getCharacteristic('2A29', service: '180A');
```

### Read & Write Data

```dart
// Read a characteristic value
Uint8List value = await PrinterConnect.read(
  deviceId,
  serviceUuid,
  characteristicUuid,
);

// Write data (with response)
await PrinterConnect.write(
  deviceId,
  serviceUuid,
  characteristicUuid,
  Uint8List.fromList([0x01, 0x02, 0x03]),
);

// Write without response (fire-and-forget)
await PrinterConnect.write(
  deviceId,
  serviceUuid,
  characteristicUuid,
  Uint8List.fromList([0x01]),
  withoutResponse: true,
);

// Or use extensions on BleCharacteristic
final characteristic = await device.getCharacteristic('2A29', service: '180A');
Uint8List value = await characteristic.read();
await characteristic.write([0x01, 0x02, 0x03]);
```

### Subscribe to Notifications

```dart
// Listen to characteristic value changes
PrinterConnect.characteristicValueStream(deviceId, characteristicId)
    .listen((Uint8List data) {
  print('Received data: $data');
});

// Subscribe to notifications
await PrinterConnect.subscribeNotifications(
  deviceId,
  serviceUuid,
  characteristicUuid,
);

// Subscribe to indications
await PrinterConnect.subscribeIndications(
  deviceId,
  serviceUuid,
  characteristicUuid,
);

// Unsubscribe
await PrinterConnect.unsubscribe(
  deviceId,
  serviceUuid,
  characteristicUuid,
);

// Or use extensions on BleCharacteristic
final characteristic = await device.getCharacteristic('2A29', service: '180A');
await characteristic.notifications.subscribe();
await characteristic.indications.subscribe();
characteristic.onValueReceived.listen((data) {
  print('Received: $data');
});
await characteristic.unsubscribe();
```

### Request MTU

```dart
// Request a specific MTU (Maximum Transmission Unit)
int currentMtu = await PrinterConnect.requestMtu(deviceId, 517);
print('Current MTU: $currentMtu');
```

> **Note on MTU:** On iOS, MTU is managed by the system. The API call returns the current negotiated value (typically ~185–517 bytes). On Android, MTU can be requested (up to 517).

### Request Connection Priority (Android Only)

```dart
// Request connection priority for a device
await PrinterConnect.requestConnectionPriority(
  deviceId,
  BleConnectionPriority.highPerformance,  // or balanced, lowPower
);
```

> **Note:** This is only supported on Android. On iOS, connection parameters are managed by the system.

### Read RSSI (Signal Strength)

```dart
int rssi = await PrinterConnect.readRssi(deviceId);
print('RSSI: $rssi dBm');

// Or use extension on BleDevice
final device = await PrinterConnect.scanStream.first;
int? rssi = await device.readRssi;
```

### Pairing Management

```dart
// Check if device is paired (Android only)
bool paired = await PrinterConnect.isPaired(deviceId);

// Pair a device (triggers pairing dialog, Android only)
await PrinterConnect.pair(deviceId);

// Unpair (Android only)
await PrinterConnect.unpair(deviceId);

// Monitor pairing state
PrinterConnect.pairingStateStream(deviceId).listen((bool isPaired) {
  print('Pairing state: ${isPaired ? "paired" : "unpaired"}');
});

// Or use extensions on BleDevice
final device = await PrinterConnect.scanStream.first;
bool isPaired = await device.isPaired();
await device.pair();
await device.unpair();
```

> **Note on iOS:** iOS does not support programmatic pairing. Pairing is triggered automatically when reading/writing encrypted characteristics.

### Bluetooth State

```dart
// Check current Bluetooth state
AvailabilityState state = await PrinterConnect.getBluetoothAvailabilityState();
print('Bluetooth state: $state');

// Listen for Bluetooth state changes
PrinterConnect.availabilityStream.listen((AvailabilityState state) {
  print('Bluetooth changed: $state');
});

// Enable/disable Bluetooth (Android only)
await PrinterConnect.enableBluetooth();
await PrinterConnect.disableBluetooth();
```

### Command Queue Management

```dart
// Set command queue type (default is global)
PrinterConnect.queueType = QueueType.perDevice;  // or none, global

// Set global timeout for all commands
PrinterConnect.timeout = const Duration(seconds: 10);

// Clear a specific device queue
PrinterConnect.clearQueue(deviceId);

// Clear global queue
PrinterConnect.clearQueue(BleCommandQueue.globalQueueId);

// Listen for queue updates
PrinterConnect.onQueueUpdate = (String id, int remainingItems) {
  print('Queue $id: $remainingItems items remaining');
};
```

### Logging

```dart
// Set log level (only effective in debug builds)
await PrinterConnect.setLogLevel(BleLogLevel.debug);
```

### Get System Connected Devices

```dart
// Get all system-connected BLE devices
List<BleDevice> devices = await PrinterConnect.getSystemDevices();

// Get system-connected devices with specific services
List<BleDevice> devices = await PrinterConnect.getSystemDevices(
  withServices: ['180A'],
);
```

### Check Advertisements

```dart
// Check if a device receives advertisements
bool hasAds = PrinterConnect.receivesAdvertisements(deviceId);
```

### Complete Example

```dart
import 'dart:typed_data';
import 'package:printer_connect/printer_connect.dart';

Future<void> main() async {
  // 1. Check & request permissions
  bool hasPerm = await PrinterConnect.hasPermissions();
  if (!hasPerm) {
    await PrinterConnect.requestPermissions();
  }

  // 2. Scan for devices
  PrinterConnect.scanStream.listen((BleDevice device) {
    print('Found: ${device.name} (${device.deviceId})');
  });
  await PrinterConnect.startScan(
    scanFilter: ScanFilter(withServices: ['180A']),
  );

  // Wait for a device...
  await Future.delayed(const Duration(seconds: 5));
  await PrinterConnect.stopScan();

  // 3. Connect to a device (use a discovered device ID)
  // await PrinterConnect.connect(deviceId);

  // 4. Discover services
  // final services = await PrinterConnect.discoverServices(deviceId);

  // 5. Read/write data
  // final value = await PrinterConnect.read(deviceId, serviceUuid, charUuid);
  // await PrinterConnect.write(deviceId, serviceUuid, charUuid, Uint8List.fromList([0x01]));

  // 6. Disconnect
  // await PrinterConnect.disconnect(deviceId);
}
```

---

## Extensions

The plugin provides convenient extensions on the model classes for a more object-oriented API.

### BleDeviceExtension

```dart
final device = await PrinterConnect.scanStream.first;

// Connection
await device.connect(autoConnect: true);
await device.disconnect();
bool isConnected = await device.isConnected;
BleConnectionState state = await device.connectionState;
Stream<bool> connStream = device.connectionStream;

// Services
final services = await device.discoverServices();
final service = await device.getService('180A');
final characteristic = await device.getCharacteristic('2A29', service: '180A');

// Pairing
bool paired = await device.isPaired();
await device.pair();
await device.unpair();
Stream<bool> pairStream = device.pairingStateStream;

// MTU & RSSI
int mtu = await device.requestMtu(517);
int? rssi = await device.readRssi;
bool hasAds = device.receivesAdvertisements;
```

### BleCharacteristicExtension

```dart
// First get a device and characteristic
final device = await PrinterConnect.scanStream.first;
final characteristic = await device.getCharacteristic('2A29', service: '180A');

// Read & Write
Uint8List value = await characteristic.read();
await characteristic.write([0x01, 0x02]);
await characteristic.write([0x01], withResponse: false);

// Notifications & Indications
final notif = characteristic.notifications;
if (notif.isSupported) {
  await notif.subscribe();
  notif.listen((data) {
    print('Notification: $data');
  });
}
await characteristic.unsubscribe();

// Value stream
characteristic.onValueReceived.listen((data) {
  print('Value: $data');
});
```

### BleServiceExtension

```dart
final service = await device.getService('180A');

// Get characteristic by UUID
final char = service.getCharacteristic('2A29');
```

---

## Platform Differences

| Feature | Android | iOS |
|---------|---------|-----|
| Programmatic Bluetooth on/off | ✔️ Supported | ❌ Must use system settings |
| Connection priority request | ✔️ Supported | ❌ System-managed |
| Unpair device | ✔️ Supported | ❌ System-managed |
| Auto-reconnect | ✔️ Supported | ✔️ Supported |
| MTU request | ✔️ Can request actively | ⏺ System auto-negotiates |
| Pairing trigger | System API | Encrypted characteristic read/write triggers pairing |
| Manufacturer data filter | ✔️ Supported | ✔️ Supported |
| Background notifications | N/A | ✔️ Via AppleConnectionOptions |

### Android vs iOS Notes

- **Android 12+ (API 31+):** Requires runtime permission requests for `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`. The plugin's `requestPermissions()` method handles this.
- **iOS Background Bluetooth:** Add `UIBackgroundModes` with `bluetooth-central` to your Info.plist if you need background BLE operations.
- **iOS Pairing:** Pairing on iOS is triggered automatically when reading/writing encrypted characteristics.
- **Android MTU:** On Android 14+, the first GATT client drives MTU to 517; subsequent MTU requests are ignored.
- **Android Connection Priority:** `requestConnectionPriority()` allows requesting different connection priorities to balance latency and power consumption.

---

## Models & Enums

### ScanFilter

```dart
ScanFilter(
  withServices: ['180A'],
  withNamePrefix: ['MyPrinter'],
  withManufacturerData: [
    ManufacturerDataFilter(
      companyIdentifier: 0x004C,
      payloadPrefix: Uint8List.fromList([0x01]),
      payloadMask: Uint8List.fromList([0xFF]),
    ),
  ],
  exclusionFilters: [
    ExclusionFilter(
      services: ['1800'],
      manufacturerDataFilter: [
        ManufacturerDataFilter(companyIdentifier: 0x0006),
      ],
      namePrefix: 'Ignore',
    ),
  ],
)
```

### PlatformConfig

```dart
PlatformConfig(
  android: AndroidOptions(
    requestLocationPermission: true,
    scanMode: AndroidScanMode.lowLatency,
    reportDelayMillis: 100,
    callbackType: [AndroidScanCallbackType.allMatches],
    matchMode: AndroidScanMatchMode.aggressive,
    numOfMatches: AndroidScanNumOfMatches.one,
    legacy: false,
  ),
)
```

### ConnectionPlatformConfig

```dart
ConnectionPlatformConfig(
  apple: AppleConnectionOptions(
    notifyOnConnection: true,
    notifyOnDisconnection: true,
    notifyOnNotification: true,
  ),
)
```

### Enums

| Enum | Values |
|------|--------|
| `AvailabilityState` | `unknown`, `resetting`, `unsupported`, `unauthorized`, `poweredOff`, `poweredOn` |
| `BleConnectionState` | `connected`, `disconnected`, `connecting`, `disconnecting` |
| `BleInputProperty` | `disabled`, `notification`, `indication` |
| `BleOutputProperty` | `withResponse`, `withoutResponse` |
| `BleConnectionPriority` | `balanced`, `highPerformance`, `lowPower` |
| `AndroidScanMode` | `balanced`, `lowLatency`, `lowPower`, `opportunistic` |
| `AndroidScanCallbackType` | `allMatches`, `firstMatch`, `matchLost`, `allMatchesAutoBatch` |
| `AndroidScanMatchMode` | `aggressive`, `sticky` |
| `AndroidScanNumOfMatches` | `one`, `few`, `max` |
| `CharacteristicProperty` | `broadcast`, `read`, `writeWithoutResponse`, `write`, `notify`, `indicate`, `authenticatedSignedWrites`, `extendedProperties` |
| `BleLogLevel` | `none`, `error`, `warning`, `info`, `debug`, `verbose` |
| `QueueType` | `global`, `perDevice`, `none` |

---

## Exceptions

The plugin provides typed exceptions for different error scenarios:

| Exception | Description |
|-----------|-------------|
| `PrinterConnectException` | Base exception class |
| `ConnectionException` | Connection-related errors |
| `PairingException` | Pairing-related errors |
| `WriteException` | Write operation errors |
| `ReadException` | Read operation errors |
| `ScanException` | Scan operation errors |
| `DiscoverServicesException` | Service discovery errors |
| `SetNotifyException` | Notification/indication errors |
| `MtuException` | MTU negotiation errors |
| `DeviceNotFoundException` | Device not found errors |
| `OperationNotSupportedException` | Unsupported operation errors |

---

## Requirements

- **Flutter:** >= 3.3.0
- **Dart:** >= 3.11.5
- **Android:** minSdkVersion with Bluetooth support
- **iOS:** >= 13.0

---

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

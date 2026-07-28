# printer_connect

[![pub package](https://img.shields.io/badge/pub-0.0.1-blue.svg)](https://pub.dev/packages/printer_connect)

**printer_connect** is a cross-platform (Android/iOS) BLE (Bluetooth Low Energy) plugin for Flutter. It provides a comprehensive Client Mode (Central) API for scanning, connecting, and communicating with BLE devices such as Bluetooth printers.

> **Note:** This plugin only implements **Client Mode (Central)**. Peripheral Mode is not supported.

---

## Features

- ✅ **Permission Management** — Check and request Bluetooth / location permissions
- ✅ **Device Scanning** — Start/stop BLE scanning with filters (services, manufacturer data, name prefix)
- ✅ **Device Connection** — Connect, disconnect, and monitor connection state
- ✅ **Service Discovery** — Discover GATT services and characteristics
- ✅ **Data Read/Write** — Read characteristics, write data (with/without response)
- ✅ **Notifications & Indications** — Subscribe to characteristic value changes
- ✅ **MTU Negotiation** — Request and negotiate Maximum Transmission Unit
- ✅ **RSSI Reading** — Read signal strength from connected devices
- ✅ **Pairing Management** — Pair, unpair, and monitor pairing state
- ✅ **Bluetooth State** — Monitor Bluetooth availability and toggle (Android only)
- ✅ **Platform Config** — Platform-specific options (scan mode, connection options)

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
| **Pairing** | `pair()` | ✔️ | ✔️ |
| | `isPaired()` | ✔️ | ✔️ |
| | `unpair()` | ✔️ | ❌ |
| | `pairingStateStream()` | ✔️ | ⏺ |
| **Bluetooth State** | `getBluetoothAvailabilityState()` | ✔️ | ✔️ |
| | `availabilityStream` | ✔️ | ✔️ |
| | `enableBluetooth()` | ✔️ | ❌ |
| | `disableBluetooth()` | ✔️ | ❌ |

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
```

### Scan for Devices

```dart
import 'package:printer_connect/printer_connect.dart';

// Listen to scan results
PrinterConnect.scanStream.listen((BleDevice device) {
  print('Discovered: ${device.name} - ${device.id}');
});

// Start scanning with optional filter
await PrinterConnect.startScan(
  scanFilter: ScanFilter(
    withServices: ['180A'],       // Filter by service UUIDs
    withNamePrefix: 'MyPrinter',  // Filter by device name prefix
  ),
);

// Stop scanning
await PrinterConnect.stopScan();
```

### Connect to a Device

```dart
// Connect to a device by its ID
await PrinterConnect.connect(deviceId);

// Monitor connection state
PrinterConnect.connectionStream(deviceId).listen((bool isConnected) {
  print('Connection state: ${isConnected ? "connected" : "disconnected"}');
});

// Disconnect
await PrinterConnect.disconnect(deviceId);
```

### Discover Services

```dart
List<BleService> services = await PrinterConnect.discoverServices(deviceId);
for (final service in services) {
  print('Service: ${service.uuid}');
  for (final char in service.characteristics) {
    print('  Characteristic: ${char.uuid}');
  }
}
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
```

### Request MTU

```dart
// Request a specific MTU (Maximum Transmission Unit)
int currentMtu = await PrinterConnect.requestMtu(deviceId, 517);
print('Current MTU: $currentMtu');
```

> **Note on MTU:** On iOS/macOS, MTU is managed by the system. The API call returns the current negotiated value (typically ~185–517 bytes). On Android, MTU can be requested (up to 517).

### Read RSSI (Signal Strength)

```dart
int rssi = await PrinterConnect.readRssi(deviceId);
print('RSSI: $rssi dBm');
```

### Pairing Management

```dart
// Pair a device (triggers pairing dialog)
await PrinterConnect.pair(deviceId);

// Check if device is paired
bool? paired = await PrinterConnect.isPaired(deviceId);

// Unpair (Android only)
await PrinterConnect.unpair(deviceId);

// Monitor pairing state
PrinterConnect.pairingStateStream(deviceId).listen((bool isPaired) {
  print('Pairing state: ${isPaired ? "paired" : "unpaired"}');
});
```

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
    print('Found: ${device.name} (${device.id})');
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

## Platform Differences

| Feature | Android | iOS |
|---------|---------|-----|
| Programmatic Bluetooth on/off | ✔️ Supported | ❌ Must use system settings |
| Connection priority request | ✔️ Supported | ❌ System-managed |
| Unpair device | ✔️ Supported | ❌ System-managed |
| Auto-reconnect | ✔️ Supported | ✔️ Supported |
| MTU request | ✔️ Can request actively | ⏺ System auto-negotiates |
| Pairing trigger | System API | Encrypted characteristic read/write triggers pairing |

### Android vs iOS Notes

- **Android 12+ (API 31+):** Requires runtime permission requests for `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`. The plugin's `requestPermissions()` method handles this.
- **iOS Background Bluetooth:** Add `UIBackgroundModes` with `bluetooth-central` to your Info.plist if you need background BLE operations.
- **iOS Pairing:** Pairing on iOS is triggered automatically when reading/writing encrypted characteristics. Use `pair()` with a `BleCommand` specifying the encryption characteristic.
- **Android MTU:** On Android 14+, the first GATT client drives MTU to 517; subsequent MTU requests are ignored.

---

## Requirements

- **Flutter:** >= 3.3.0
- **Dart:** >= 3.11.5
- **Android:** minSdkVersion with Bluetooth support
- **iOS:** >= 13.0

---

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

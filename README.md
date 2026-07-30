# Printer Connect

[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](https://github.com/oonne/printer_connect)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.3.0-blue.svg?logo=flutter)](https://flutter.dev)

A cross-platform (Android/iOS) Bluetooth Low Energy (BLE) client plugin for Flutter, based on [universal_ble](https://github.com/Navideck/universal_ble).

This is a trimmed version of the `universal_ble` package, supporting only:
- **Platforms**: Android and iOS only (macOS, Windows, Linux, and Web are removed)
- **Mode**: Client Mode only (Peripheral Mode is removed)

## Features

- [Scanning](#scanning)
- [Connecting](#connecting)
- [Discovering Services](#discovering-services)
- [Reading & Writing data](#reading--writing-data)
- [Pairing](#pairing)
- [Bluetooth Availability](#bluetooth-availability)
- [Requesting MTU](#requesting-mtu)
- [Reading RSSI](#reading-rssi)
- [Requesting Connection Priority (Android only)](#requesting-connection-priority)
- [Command Queue](#command-queue)
- [Timeout](#timeout)
- [Error Handling](#error-handling)
- [UUID Format Agnostic](#uuid-format-agnostic)
- [Platform-specific setup](#platform-specific-setup)

## API Support

### Client Mode (`PrinterConnect`)

|                               | Android | iOS |
| :---------------------------- | :-----: | :-: |
| startScan/stopScan            |   ✔️    | ✔️  |
| connect/disconnect            |   ✔️    | ✔️  |
| autoConnect                   |   ✔️    | ✔️  |
| getSystemDevices              |   ✔️    | ✔️  |
| discoverServices              |   ✔️    | ✔️  |
| read                          |   ✔️    | ✔️  |
| write                         |   ✔️    | ✔️  |
| subscriptions                 |   ✔️    | ✔️  |
| pair                          |   ✔️    | ⏺️  |
| unpair                        |   ✔️    | ❌  |
| isPaired                      |   ✔️    | ✔️  |
| pairingStateStream            |   ✔️    | ⏺️  |
| getBluetoothAvailabilityState |   ✔️    | ✔️  |
| enable/disable Bluetooth      |   ✔️    | ❌  |
| availabilityStream            |   ✔️    | ✔️  |
| requestMtu                    |   ✔️    | ✔️  |
| requestConnectionPriority     |   ✔️    | ❌  |
| onConnectionParametersChange  |   ✔️    | ❌  |
| readRssi                      |   ✔️    | ✔️  |
| requestPermissions            |   ✔️    | ✔️  |

⏺️ = Partial support (see notes below)

## Getting Started

Add `printer_connect` in your `pubspec.yaml`:

```yaml
dependencies:
  printer_connect:
    git:
      url: https://github.com/oonne/printer_connect.git
```

and import it wherever you want to use it:

```dart
import 'dart:typed_data';
import 'package:printer_connect/printer_connect.dart';
```

> **Important**: Before using BLE features, make sure to check the [Permissions](#permissions) section to see what setup is needed for your target platform (Android or iOS).

### Scanning

The very first thing you need to do before being able to connect to a device is to discover it by calling `startScan()`:

```dart
// Get scan updates from stream
PrinterConnect.scanStream.listen((BleDevice bleDevice) {
  // e.g. Use BleDevice ID to connect
});

// Perform a scan
PrinterConnect.startScan();

// Or optionally add a scan filter
PrinterConnect.startScan(
  scanFilter: ScanFilter(
    withServices: ["SERVICE_UUID"],
    withManufacturerData: [ManufacturerDataFilter(companyIdentifier: 0x004c)],
    withNamePrefix: ["NAME_PREFIX"],
  )
);

// Stop scanning
PrinterConnect.stopScan();

// Check if scanning
PrinterConnect.isScanning();
```

Before initiating a scan, ensure that Bluetooth is available:

```dart
AvailabilityState state = await PrinterConnect.getBluetoothAvailabilityState();
// Start scan only if Bluetooth is powered on
if (state == AvailabilityState.poweredOn) {
  PrinterConnect.startScan();
}

// Listen to bluetooth availability changes using stream
PrinterConnect.availabilityStream.listen((state) {
  if (state == AvailabilityState.poweredOn) {
    PrinterConnect.startScan();
  }
});
```

See the [Bluetooth Availability](#bluetooth-availability) section for more.

#### System Devices

Already connected devices, connected either through previous sessions, other apps or through system settings, won't show up as scan results. You can get those using `getSystemDevices()`.

```dart
// Get already connected devices.
// You can set `withServices` to narrow down the results.
// On `Apple`, `withServices` is required to get any connected devices. If not passed, several [18XX] generic services will be set by default.
List<BleDevice> devices = await PrinterConnect.getSystemDevices(withServices: []);
```

For each such device the `isSystemDevice` property will be `true`.

You still need to explicitly [connect](#connecting) to them before being able to use them.

#### Scan Filter

You can optionally set a filter when scanning. A filter can have multiple conditions (services, manufacturerData, namePrefix) and all conditions are in `OR` relation, returning results that match any of the given conditions.

##### With Services

When setting this parameter, the scan results will only include devices that advertise any of the specified services.

```dart
List<String> withServices;
```

##### With ManufacturerData

Use the `withManufacturerData` parameter to filter devices by manufacturer data. When you pass a list of `ManufacturerDataFilter` objects to this parameter, the scan results will only include devices that contain any of the specified manufacturer data.

You can filter manufacturer data by company identifier, payload prefix, or payload mask.

```dart
List<ManufacturerDataFilter> withManufacturerData = [ManufacturerDataFilter(
            companyIdentifier: 0x004c,
            payloadPrefix: Uint8List.fromList([0x001D,0x001A]),
            payloadMask: Uint8List.fromList([1,0,1,1]))
          ];
```

##### With namePrefix

Use the `withNamePrefix` parameter to filter devices by names (case sensitive). When you pass a list of names, the scan results will only include devices that have this name or start with the provided parameter.

```dart
List<String> withNamePrefix;
```

##### Exclusion Filter

Use exclusion filters to exclude specific devices from scan results:

```dart
exclusionFilters: [
    ExclusionFilter(
      namePrefix: 'EXCLUDED_NAME',
      services: ['EXCLUDED_SERVICE_UUID'],
      manufacturerDataFilter: [ManufacturerDataFilter(companyIdentifier: 0x004c)],
    ),
]
```

### Connecting

#### Connect

Connects to the BLE device. This method initiates a connection to the Bluetooth device.

```dart
await bleDevice.connect();
```

#### Disconnect

Disconnects from the BLE device. This method terminates the connection to the Bluetooth device.

```dart
await bleDevice.disconnect();
```

#### Connection Stream

```dart
bleDevice.connectionStream.listen((isConnected) {
  debugPrint('Is device connected?: $isConnected');
});
```

#### IsConnected

```dart
bool isConnected = await bleDevice.isConnected;
```

#### Connection state

```dart
// Can be connected, disconnected, connecting or disconnecting
BleConnectionState connectionState = await bleDevice.connectionState;
```

#### Auto-connect

You can enable automatic reconnection by setting the `autoConnect` parameter to `true`. When enabled, the system will automatically attempt to reconnect to the device when it becomes available again.

```dart
await bleDevice.connect(autoConnect: true);
```

#### Background connection events (iOS)

By default, a suspended app does not get woken for connection events. Set `AppleConnectionOptions` to have the system alert the user and relaunch your app into the background when a connection event occurs while the app is suspended — e.g. to keep reacting to a previously paired peripheral (auto-reconnect) during a workout while the phone is locked. Requires the `bluetooth-central` background mode on iOS.

Note: the system may show an alert to the user for these events, and `notifyOnNotification` fires per characteristic notification, so enable only what you need.

```dart
await bleDevice.connect(
  autoConnect: true,
  platformConfig: ConnectionPlatformConfig(
    apple: AppleConnectionOptions(
      notifyOnConnection: true,
      notifyOnDisconnection: true,
      notifyOnNotification: true,
    ),
  ),
);
```

### Discovering Services

After establishing a connection, services need to be discovered. This method will discover all services and their characteristics.

If you don't call this method then it will be automatically called when you try to get any service or characteristic.

#### DiscoverServices

Discovers the services offered by the device. Returns a `Future<List<BleService>>`. After discovery services are cached and each call of this method updates the cache.

```dart
List<BleService> services = await bleDevice.discoverServices();
for (var service in services) {
  debugPrint('Service UUID: ${service.uuid}');
}
```

#### GetService

Retrieves a specific service. Returns a `Future<BleService>`.

- `service`: The UUID of the service.
- `preferCached`: If `true` (default), cached services are used. If cache is empty, `discoverServices()` will be called.

```dart
BleService service = await bleDevice.getService('180a');
```

#### GetCharacteristic

Retrieves a specific characteristic from a service. Returns a `Future<BleCharacteristic>`.

- `service`: The UUID of the service.
- `characteristic`: The UUID of the characteristic.
- `preferCached`: If `true` (default), cached services are used. If cache is empty, `discoverServices()` will be called.

```dart
BleCharacteristic characteristic = await bleDevice.getCharacteristic('180a','2a56');
```

Or retrieve from `BleService`:

```dart
BleCharacteristic characteristic = await service.getCharacteristic('2a56');
```

## Reading & Writing data

You need to first [discover services](#discovering-services) before you are able to read and write to characteristics.

```dart
Uint8List value = await characteristic.read();
```

```dart
await characteristic.write([0x01, 0x02, 0x03]);

await characteristic.write([0x01, 0x02, 0x03], withResponse: false);
```

## Subscriptions

Get `BleCharacteristic` using `bleDevice.getCharacteristic`

### OnValueReceived

A stream of `Uint8List` that emits values received from the characteristic. Listen to this stream to receive updates whenever the characteristic's value changes.

```dart
characteristic.onValueReceived.listen((value) {
  debugPrint('Received value: ${value.toString()}');
});
```

### Notifications

Subscribe to notifications for this characteristic. Throws an exception if the characteristic does not support notifications.

```dart
await characteristic.notifications.subscribe();
```

### Indications

Subscribe to indications for this characteristic. Throws an exception if the characteristic does not support indications.

```dart
await characteristic.indications.subscribe();
```

### Unsubscribe

Unsubscribe from notifications and indications of this characteristic.

```dart
await characteristic.unsubscribe();
```

### Pairing

#### Trigger pairing

##### Pair on Android

```dart
await bleDevice.pair();
```

##### Pair on iOS

For iOS, pairing support depends on the device. Pairing is triggered automatically by the OS when you try to read/write from/to an encrypted characteristic. The `pair()` method will only trigger pairing if the device has an encrypted read characteristic.

After pairing you can check the pairing status.

#### Pairing status

##### Check pairing state

```dart
// Check current pairing state
bool isPaired = await bleDevice.isPaired();
```

#### Pairing state changes

```dart
// Get pairing state updates using stream
bleDevice.pairingStateStream.listen((bool paired) {
  // Handle pairing state change
});
```

#### Unpair

```dart
bleDevice.unpair();
```

### Bluetooth Availability

```dart
// Get current Bluetooth availability state
AvailabilityState availabilityState = await PrinterConnect.getBluetoothAvailabilityState(); // e.g. poweredOff or poweredOn

// Receive Bluetooth availability changes via stream
PrinterConnect.availabilityStream.listen((state) {
  // Handle the new Bluetooth availability state
});

// Enable Bluetooth programmatically (Android only)
await PrinterConnect.enableBluetooth();

// Disable Bluetooth programmatically (Android only)
await PrinterConnect.disableBluetooth();
```

### Requesting MTU

```dart
int mtu = await bleDevice.requestMtu(256);
```

> ⚠️ Note: Requesting an MTU is a _best-effort_ operation.
> On many platforms the final MTU is fully controlled by the OS and remote device.

#### Platform Limitations

MTU negotiation is largely platform- and stack-managed, and often cannot be explicitly controlled by applications:

- **iOS**: MTU is fully OS-managed; apps cannot request or set it. Historically ~185 bytes, but modern devices may negotiate larger MTUs (≈247–517) automatically.

- **Android**:
  - **Android ≤ 13**: Apps may request MTU once per connection (up to 517). If never requested, the default MTU is 23.
  - **Android 14+**: The first Bluetooth client effectively drives MTU negotiation to 517 (or the link's maximum); subsequent MTU requests are ignored.

#### Best Practices

When developing cross-platform BLE applications and devices:

- Always design for the default ATT MTU (23 bytes)
- Treat MTU requests as opportunistic, not guaranteed
- Dynamically adapt packet sizes based on the negotiated MTU
- Implement application-level fragmentation for larger payloads
- Take advantage of higher MTUs when available, without depending on them

### Requesting Connection Priority

On Android, you can request a connection parameter update to tune the BLE connection interval. This can yield a 3–7× throughput improvement for data-intensive transfers.

```dart
// Before starting high-throughput data transfer:
await PrinterConnect.requestConnectionPriority(
  deviceId,
  BleConnectionPriority.highPerformance,
);
```

> **Note:** Only supported on Android. On iOS this throws `PrinterConnectException` with code `notSupported`.
> Call this after connecting and after `requestMtu()`, before beginning data transfer.

The OS may later change connection parameters without your app requesting it (e.g. for power saving), which can reduce throughput. On Android API 26+, you can listen to connection parameter changes by subscribing to the platform-level `onConnectionParametersChange` callback through the custom platform implementation.

> **Note:** Re-requesting high priority on every update can fight the OS power manager — debounce in app code. Requires Android API 26+.

### Reading RSSI

Read the signal strength (RSSI) of a connected device.

```dart
int rssi = await bleDevice.readRssi();
```

> ⚠️ Note: The device must be connected before reading RSSI.

#### Platform Limitations

- **Android / iOS**: Fully supported.

## Command Queue

By default, all commands are executed in a global queue (`QueueType.global`), with each command waiting for the previous one to finish. While this method is slower it is the safest to avoid command exceptions and therefore is the default.

If you want to parallelize commands between multiple devices, you can set:

```dart
// Create a separate queue for each device.
PrinterConnect.queueType = QueueType.perDevice;
```

You can have separate queues by passing an optional `queueId`. Commands with the same `queueId` are serialized together, but run in parallel with both `QueueType.perDevice` and `QueueType.global`:

```dart
PrinterConnect.write(deviceId, service, char, value1, queueId: '1');
PrinterConnect.write(deviceId, service, char, value2, queueId: '2');
```

You can also completely disable the queue and batch all commands, even for the same device, by using:

```dart
// Disable queue
PrinterConnect.queueType = QueueType.none;
```

Keep in mind that some platforms (e.g. Android) may not handle well devices that fail to process consecutive commands without a minimum interval. Therefore, it is not advised to set `queueType` to `none`.

You can get queue updates by setting:

```dart
// Get queue state updates
PrinterConnect.onQueueUpdate = (String id, int remainingItems) {
  debugPrint("Queue: $id Remaining: $remainingItems");
};
```

To clear a queue:

```dart
// Clear global queue
PrinterConnect.clearQueue(BleCommandQueue.globalQueueId);

// Clear a per-device queue (when queueType is perDevice)
PrinterConnect.clearQueue(deviceId);

// Clear a custom queue (same string passed as queueId to read/write/etc.)
PrinterConnect.clearQueue('customQueueId');

// Clear all queues
PrinterConnect.clearQueue();
```

## Timeout

By default, all commands have a global timeout of 10 seconds.

```dart
// Change timeout
PrinterConnect.timeout = const Duration(seconds: 10);

// Disable timeout
PrinterConnect.timeout = null;
```

You can also specify the `timeout` parameter when sending a command. This will override the global timeout.

## Error Handling

Printer Connect provides a unified and type-safe error handling system across platforms. All errors are represented using the `PrinterConnectException` base class with typed error codes.

### Exception Types

- **`PrinterConnectException`**: Base exception class for all BLE errors
- **`ConnectionException`**: Thrown for connection-related errors
- **`PairingException`**: Thrown for pairing-related errors
- **`WriteException`**: Thrown for write-related errors
- **`ReadException`**: Thrown for read-related errors
- **`ScanException`**: Thrown for scan-related errors
- **`DiscoverServicesException`**: Thrown for service discovery errors
- **`SetNotifyException`**: Thrown for notification/indication errors
- **`MtuException`**: Thrown for MTU-related errors
- **`DeviceNotFoundException`**: Thrown when a device/service/characteristic is not found
- **`OperationNotSupportedException`**: Thrown when an operation is not supported on the current platform

### Error Codes

All errors are categorized using string error codes, which include codes for:

- Connection errors (timeout, failed, rejected, etc.)
- Pairing errors (failed, cancelled, not allowed, etc.)
- Operation errors (not supported, timeout, cancelled, etc.)
- Permission errors (not allowed, unauthorized, access denied, etc.)
- Device errors (not found, disconnected, etc.)
- Service/Characteristic errors (not found, invalid UUID, etc.)
- And many more...

### Usage

```dart
try {
  await bleDevice.connect();
} on ConnectionException catch (e) {
  // Handle connection-specific errors
  switch (e.code) {
    case 'connectionTimeout':
      // Handle timeout
      break;
    case 'connectionFailed':
      // Handle connection failure
      break;
    case 'deviceDisconnected':
      // Handle disconnection
      break;
    default:
      // Handle other connection errors
  }
} on PrinterConnectException catch (e) {
  // Handle other BLE errors
  print('Error code: ${e.code}, Message: ${e.message}');
}
```

The error parser automatically converts platform-specific error formats (strings, numeric codes, PlatformExceptions) into the typed exception classes, ensuring consistent error handling across platforms.

## UUID Format Agnostic

Printer Connect is agnostic to the UUID format of services and characteristics regardless of the platform the app runs on. When passing a UUID, you can pass it in any format (long/short) or character case (upper/lower case) you want. Printer Connect will take care of necessary conversions, across all platforms, so that you don't need to worry about underlying platform differences.

For consistency, all characteristic and service UUIDs will be returned in **lowercase 128-bit format**, across all platforms, e.g. `0000180a-0000-1000-8000-00805f9b34fb`.

### Utility Methods

If you need to convert any UUIDs in your app you can use the following methods.

- `BleUuidParser.string()` converts a string to a 128-bit UUID formatted string:

```dart
BleUuidParser.string("180A"); // "0000180a-0000-1000-8000-00805f9b34fb"

BleUuidParser.string("0000180A-0000-1000-8000-00805F9B34FB"); // "0000180a-0000-1000-8000-00805f9b34fb"
```

- `BleUuidParser.number()` converts a number to a 128-bit UUID formatted string:

```dart
BleUuidParser.number(0x180A); // "0000180a-0000-1000-8000-00805f9b34fb"
```

- `BleUuidParser.compareStrings()` compares two differently formatted UUIDs:

```dart
BleUuidParser.compareStrings("180a","0000180A-0000-1000-8000-00805F9B34FB"); // true
```

## Platform-specific setup

You need to perform the following setups:

### Android

#### Manifest Permissions

Add the following permissions to your AndroidManifest.xml file:

```xml
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
```

If your app uses iBeacons or BLUETOOTH_SCAN to determine location, change the last 2 permissions to:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
```

#### Android Location Permission

The `withAndroidFineLocation` parameter in `requestPermissions()` controls location permission requests on Android:

- **Android 12+ (API 31+)**:
  - `withAndroidFineLocation: true` → Requests `ACCESS_FINE_LOCATION` permission
  - `withAndroidFineLocation: false` → Only requests Bluetooth permissions (no location permission)
- **Android 11 and below**:
  - Location permission is always requested if declared in your manifest (required for BLE scanning)
  - The `withAndroidFineLocation` parameter is ignored

#### Android scan options

By default, BLE 5 extended advertisements are scanned (API 26+, unchanged from prior releases). Set `legacy: true` for legacy BLE 4.x devices (e.g. ESP32).

```dart
PrinterConnect.startScan(
  platformConfig: PlatformConfig(
    android: AndroidOptions(
      legacy: true, // omit for extended BLE 5 (default)
      scanMode: AndroidScanMode.lowLatency,
      callbackType: [AndroidScanCallbackType.allMatches],
      requestLocationPermission: false,
    ),
  ),
);
```

#### Background Scanning (ForegroundTask)

Printer Connect supports BLE scanning from background services (e.g., using `flutter_foreground_task` or similar packages) on Android. When running in a background context without an Activity:

- **If permissions are already granted**: Scanning works normally
- **If permissions are not granted**: An error is thrown with the message "Permissions not granted and activity is not available to request them"

**Best Practice**: Request permissions while your app is in the foreground before starting any background BLE operations:

```dart
// Request permissions in foreground (e.g., during app setup)
await PrinterConnect.requestPermissions();

// Later, in your ForegroundTask, scanning will work if permissions were granted
await PrinterConnect.startScan();
```

### iOS

For Bluetooth usage, add the following key to your app's `Info.plist`:

- `NSBluetoothAlwaysUsageDescription`: message shown when the app requests Bluetooth access.

Example:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to scan, connect, and communicate with nearby devices.</string>
```

Use clear, user-facing text that explains why Bluetooth is needed in your app.

#### iOS background state restoration

On iOS, when your app declares the `bluetooth-central` background mode and Bluetooth permission is already granted, the central manager is created at launch with a `CBCentralManagerOptionRestoreIdentifierKey`, so CoreBluetooth can [relaunch your app](https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules) in the background when a connected peripheral has activity, and hand the live connection back to the plugin. If permission has not been granted yet, creation is deferred until a central BLE API (such as `startScan()` or `connect()`) is called.

To opt in, declare the `Uses Bluetooth LE accessories` background mode. After enabling it, in `Info.plist` you should have:

```xml
<key>UIBackgroundModes</key>
<array>
  ...
  <string>bluetooth-central</string>
  ...
</array>
```

Notes:

- Without the `bluetooth-central` background mode, `CBCentralManager` is created lazily on the first central BLE API call and state restoration is disabled.
- On relaunch, the plugin re-adopts the restored peripherals and emits `onConnectionChanged` for any that are still connected, so your Dart code can resume where it left off.

### Manually Requesting Permissions

**Calling `requestPermissions()` is optional.** Permissions are automatically requested when calling `startScan()`. However, you can manually call `requestPermissions()` if you want to:

- Request permissions before scanning (e.g., to handle permission errors separately)
- Ensure permissions are granted before other operations like `connect()`, `read()`, `write()`, etc., which don't automatically request permissions

The `requestPermissions()` method:

- Returns successfully if all permissions are already granted or accepted by the user
- Throws a `PrinterConnectException` if permissions are denied by the user

```dart
// Optional: Manually request permissions
await PrinterConnect.requestPermissions(
  withAndroidFineLocation: false,
);
```

> **Note**: When calling `startScan()`, permissions are automatically requested. To configure location permission requests during scanning, use `requestLocationPermission` on `AndroidOptions` (see [Android scan options](#android-scan-options)):

```dart
PrinterConnect.startScan(
  platformConfig: PlatformConfig(
    android: AndroidOptions(
      requestLocationPermission: false,
    ),
  ),
);
```

## Customizing Platform Implementation

```dart
// Create a class that extends PrinterConnectPlatform
class PrinterConnectMock extends PrinterConnectPlatform {
  // Implement all commands
}

PrinterConnect.setInstance(PrinterConnectMock());
```

## Logging

Configure logging to help debug BLE operations

### Usage

Set the log level during app initialization, default level is `none`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable verbose logging to see all BLE operations
  await PrinterConnect.setLogLevel(BleLogLevel.verbose);
  runApp(MyApp());
}
```

## Resetting State on Hot Restart

During Flutter hot restart in debug mode, the app state is reset but native Bluetooth connections and scan operations may persist. This can lead to connection issues or stale state.

<details> 
<summary>Use the following helper function to properly clean up BLE state before your app restarts.</summary>

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Reset BLE state before app initialization
  await resetBleState();
  runApp(MyApp());
}

/// Resets BLE state by stopping scans and disconnecting all devices.
/// Make sure you have Bluetooth permissions before calling this function.
Future<void> resetBleState() async {
  // Check Bluetooth availability
  AvailabilityState availabilityState =
      await PrinterConnect.getBluetoothAvailabilityState();

  // Skip if Bluetooth is not powered on
  if (availabilityState != AvailabilityState.poweredOn) {
    debugPrint('Reset: Bluetooth is not powered on');
    return;
  }

  // Stop scanning
  if (await PrinterConnect.isScanning()) {
    debugPrint('Reset: Stopping scan');
    await PrinterConnect.stopScan();
  }

  // Disconnect all connected devices
  // On Apple platforms, you must specify services to discover connected devices
  List<BleDevice> connectedDevices =
      await PrinterConnect.getSystemDevices(withServices: []);

  for (var device in connectedDevices) {
    debugPrint('Reset: Disconnecting device: ${device.deviceId}');
    await PrinterConnect.disconnect(device.deviceId);
  }

  debugPrint('Reset: Done');
}
```

</details>

## Example app

This repo includes an [example app](example/) demonstrating basic scanning and device communication workflows.
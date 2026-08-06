# Printer Connect

[![pub package](https://img.shields.io/pub/v/printer_connect?label=printer_connect&color=blue)](https://pub.dev/packages/printer_connect)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](https://github.com/oonne/printer_connect)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.16.0-blue.svg?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.1.3-blue.svg?logo=dart)](https://dart.dev)
[![pub points](https://img.shields.io/pub/points/printer_connect?color=2E7D32)](https://pub.dev/packages/printer_connect/score)
[![GitHub stars](https://img.shields.io/github/stars/oonne/printer_connect?style=social)](https://github.com/oonne/printer_connect)

用于连接打印机。

## 功能

- [扫描](#扫描)
- [连接](#连接)
- [发现服务](#发现服务)
- [读取与写入数据](#读取与写入数据)
- [配对](#配对)
- [蓝牙可用性](#蓝牙可用性)
- [请求 MTU](#请求-mtu)
- [读取 RSSI](#读取-rssi)
- [请求连接优先级（仅限 Android）](#请求连接优先级)
- [命令队列](#命令队列)
- [超时](#超时)
- [错误处理](#错误处理)
- [UUID 格式无关性](#uuid-格式无关性)
- [平台特定设置](#平台特定设置)

## API 

| 功能 | 方法 | Android | iOS |
| :--- | :--- | :---: | :---: |
| [扫描](#扫描) | startScan/stopScan | ✔️ | ✔️ |
| [连接/断开](#连接) | connect/disconnect | ✔️ | ✔️ |
| [自动重连](#自动连接) | autoConnect | ✔️ | ✔️ |
| [系统设备](#系统设备) | getSystemDevices | ✔️ | ✔️ |
| [发现服务](#发现服务) | discoverServices | ✔️ | ✔️ |
| [读取数据](#读取与写入数据) | read | ✔️ | ✔️ |
| [写入数据](#读取与写入数据) | write | ✔️ | ✔️ |
| [订阅通知/指示](#订阅) | subscriptions | ✔️ | ✔️ |
| [触发配对](#触发配对) | pair | ✔️ | ⏺ |
| [取消配对](#取消配对) | unpair | ✔️ | ❌ |
| [检查配对状态](#检查配对状态) | isPaired | ✔️ | ✔️ |
| [配对状态流](#配对状态变化) | pairingStateStream | ✔️ | ⏺ |
| [获取蓝牙状态](#蓝牙可用性) | getBluetoothAvailabilityState | ✔️ | ✔️ |
| [启用/禁用蓝牙](#蓝牙可用性) | enable/disable Bluetooth | ✔️ | ❌ |
| [蓝牙状态流](#蓝牙可用性) | availabilityStream | ✔️ | ✔️ |
| [请求MTU](#请求-mtu) | requestMtu | ✔️ | ✔️ |
| [请求连接优先级](#请求连接优先级) | requestConnectionPriority | ✔️ | ❌ |
| [连接参数变化回调](#请求连接优先级) | onConnectionParametersChange | ✔️ | ❌ |
| [读取信号强度](#读取-rssi) | readRssi | ✔️ | ✔️ |
| [请求权限](#手动请求权限) | requestPermissions | ✔️ | ✔️ |

⏺ = 部分支持（见下方说明）

## 快速开始

在你的 `pubspec.yaml` 中添加 `printer_connect`：

```yaml
dependencies:
  printer_connect:
    git:
      url: https://github.com/oonne/printer_connect.git
```

然后在你想使用它的地方导入：

```dart
import 'dart:typed_data';
import 'package:printer_connect/printer_connect.dart';
```

> **重要**：在使用 BLE 功能之前，请务必查看[权限](#权限)部分，了解目标平台（Android 或 iOS）需要进行哪些设置。

### 扫描

在能够连接设备之前，你需要做的第一件事就是通过调用 `startScan()` 来发现它：

```dart
// 从流中获取扫描更新
PrinterConnect.scanStream.listen((BleDevice bleDevice) {
  // 例如：使用 BleDevice ID 进行连接
});

// 执行扫描
PrinterConnect.startScan();

// 或者可选地添加扫描过滤器
PrinterConnect.startScan(
  scanFilter: ScanFilter(
    withServices: ["SERVICE_UUID"],
    withManufacturerData: [ManufacturerDataFilter(companyIdentifier: 0x004c)],
    withNamePrefix: ["NAME_PREFIX"],
  )
);

// 停止扫描
PrinterConnect.stopScan();

// 检查是否正在扫描
PrinterConnect.isScanning();
```

> **提示**：在 Android 上，`startScan()` 默认扫描传统 BLE 4.x 广播（`legacy: true`），适配主流打印机。如需扫描 BLE 5 扩展广播，请通过 `PlatformConfig(android: AndroidOptions(legacy: false))` 显式设置。

在启动扫描之前，请确保蓝牙可用：

```dart
AvailabilityState state = await PrinterConnect.getBluetoothAvailabilityState();
// 仅在蓝牙已开机时才开始扫描
if (state == AvailabilityState.poweredOn) {
  PrinterConnect.startScan();
}

// 使用流监听蓝牙可用性变化
PrinterConnect.availabilityStream.listen((state) {
  if (state == AvailabilityState.poweredOn) {
    PrinterConnect.startScan();
  }
});
```

更多信息请参见[蓝牙可用性](#蓝牙可用性)部分。

#### 系统设备

已连接的设备（无论是通过之前的会话、其他应用还是通过系统设置连接的）不会作为扫描结果显示。你可以使用 `getSystemDevices()` 获取它们。

```dart
// 获取已连接的设备。
// 你可以设置 `withServices` 来缩小结果范围。
// 在 `Apple` 平台上，获取任何已连接设备都需要 `withServices`。如果未传递，将默认设置几个 [18XX] 通用服务。
List<BleDevice> devices = await PrinterConnect.getSystemDevices(withServices: []);
```

对于每个这样的设备，`isSystemDevice` 属性将为 `true`。

在能够使用它们之前，你仍然需要显式地[连接](#连接)它们。

#### 扫描过滤器

你可以在扫描时可选地设置过滤器。过滤器可以有多个条件（服务、制造商数据、名称前缀），所有条件之间是 `OR` 关系，返回匹配任何给定条件的结果。

##### 按服务过滤

设置此参数后，扫描结果将仅包含广播了任何指定服务的设备。

```dart
List<String> withServices;
```

##### 按制造商数据过滤

使用 `withManufacturerData` 参数按制造商数据过滤设备。当你向此参数传递一个 `ManufacturerDataFilter` 对象列表时，扫描结果将仅包含包含任何指定制造商数据的设备。

你可以通过公司标识符、载荷前缀或载荷掩码来过滤制造商数据。

```dart
List<ManufacturerDataFilter> withManufacturerData = [ManufacturerDataFilter(
            companyIdentifier: 0x004c,
            payloadPrefix: Uint8List.fromList([0x001D,0x001A]),
            payloadMask: Uint8List.fromList([1,0,1,1]))
          ];
```

##### 按名称前缀过滤

使用 `withNamePrefix` 参数按名称过滤设备（区分大小写）。当你传递一个名称列表时，扫描结果将仅包含具有该名称或以提供的参数开头的设备。

```dart
List<String> withNamePrefix;
```

##### 排除过滤器

使用排除过滤器从扫描结果中排除特定设备：

```dart
exclusionFilters: [
    ExclusionFilter(
      namePrefix: 'EXCLUDED_NAME',
      services: ['EXCLUDED_SERVICE_UUID'],
      manufacturerDataFilter: [ManufacturerDataFilter(companyIdentifier: 0x004c)],
    ),
]
```

### 连接

#### 连接

连接到 BLE 设备。此方法启动与蓝牙设备的连接。

```dart
await bleDevice.connect();
```

#### 断开连接

断开与 BLE 设备的连接。此方法终止与蓝牙设备的连接。

```dart
await bleDevice.disconnect();
```

#### 连接流

```dart
bleDevice.connectionStream.listen((isConnected) {
  debugPrint('设备已连接吗？ $isConnected');
});
```

#### IsConnected

```dart
bool isConnected = await bleDevice.isConnected;
```

#### 连接状态

```dart
// 可以是 connected, disconnected, connecting 或 disconnecting
BleConnectionState connectionState = await bleDevice.connectionState;
```

#### 自动连接

通过将 `autoConnect` 参数设置为 `true`，你可以启用自动重连。启用后，当设备再次可用时，系统将自动尝试重新连接。

```dart
await bleDevice.connect(autoConnect: true);
```

#### 后台连接事件（iOS）

默认情况下，挂起的应用不会因连接事件而被唤醒。设置 `AppleConnectionOptions` 可在应用挂起时发生连接事件时，让系统提醒用户并将你的应用重新启动到后台——例如，在手机锁屏时进行锻炼期间，保持对先前配对外设的反应（自动重连）。在 iOS 上需要 `bluetooth-central` 后台模式。

注意：系统可能会为这些事件向用户显示提醒，并且 `notifyOnNotification` 会针对每个特征通知触发，因此请仅启用你需要的功能。

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

### 发现服务

建立连接后，需要发现服务。此方法将发现所有服务及其特征。

如果你不调用此方法，那么当你尝试获取任何服务或特征时，它将被自动调用。

#### DiscoverServices

发现设备提供的服务。返回一个 `Future<List<BleService>>`。发现服务后会缓存，每次调用此方法都会更新缓存。

```dart
List<BleService> services = await bleDevice.discoverServices();
for (var service in services) {
  debugPrint('Service UUID: ${service.uuid}');
}
```

#### GetService

检索特定服务。返回一个 `Future<BleService>`。

- `service`：服务的 UUID。
- `preferCached`：如果为 `true`（默认值），则使用缓存的服务。如果缓存为空，将调用 `discoverServices()`。

```dart
BleService service = await bleDevice.getService('180a');
```

#### GetCharacteristic

从服务中检索特定特征。返回一个 `Future<BleCharacteristic>`。

- `service`：服务的 UUID。
- `characteristic`：特征的 UUID。
- `preferCached`：如果为 `true`（默认值），则使用缓存的服务。如果缓存为空，将调用 `discoverServices()`。

```dart
BleCharacteristic characteristic = await bleDevice.getCharacteristic('180a','2a56');
```

或从 `BleService` 中检索：

```dart
BleCharacteristic characteristic = await service.getCharacteristic('2a56');
```

## 读取与写入数据

在能够读取和写入特征之前，你需要先[发现服务](#发现服务)。

```dart
Uint8List value = await characteristic.read();
```

```dart
await characteristic.write([0x01, 0x02, 0x03]);

await characteristic.write([0x01, 0x02, 0x03], withResponse: false);
```

## 订阅

使用 `bleDevice.getCharacteristic` 获取 `BleCharacteristic`

### OnValueReceived

一个 `Uint8List` 流，发出从特征接收的值。监听此流以在特征值更改时接收更新。

```dart
characteristic.onValueReceived.listen((value) {
  debugPrint('接收到的值: ${value.toString()}');
});
```

### 通知

订阅此特征的通知。如果特征不支持通知，则抛出异常。

```dart
await characteristic.notifications.subscribe();
```

### 指示

订阅此特征的指示。如果特征不支持指示，则抛出异常。

```dart
await characteristic.indications.subscribe();
```

### 取消订阅

取消订阅此特征的通知和指示。

```dart
await characteristic.unsubscribe();
```

### 配对

#### 触发配对

##### 在 Android 上配对

```dart
await bleDevice.pair();
```

##### 在 iOS 上配对

对于 iOS，配对支持取决于设备。当你尝试从加密特征读取/写入时，操作系统会自动触发配对。`pair()` 方法仅在设备具有加密读取特征时才会触发配对。

配对后，你可以检查配对状态。

#### 配对状态

##### 检查配对状态

```dart
// 检查当前配对状态
bool isPaired = await bleDevice.isPaired();
```

#### 配对状态变化

```dart
// 使用流获取配对状态更新
bleDevice.pairingStateStream.listen((bool paired) {
  // 处理配对状态变化
});
```

#### 取消配对

```dart
bleDevice.unpair();
```

### 蓝牙可用性

```dart
// 获取当前蓝牙可用性状态
AvailabilityState availabilityState = await PrinterConnect.getBluetoothAvailabilityState(); // 例如：poweredOff 或 poweredOn

// 通过流接收蓝牙可用性变化
PrinterConnect.availabilityStream.listen((state) {
  // 处理新的蓝牙可用性状态
});

// 以编程方式启用蓝牙（仅限 Android）
await PrinterConnect.enableBluetooth();

// 以编程方式禁用蓝牙（仅限 Android）
await PrinterConnect.disableBluetooth();
```

### 请求 MTU

```dart
int mtu = await bleDevice.requestMtu(256);
```

> ⚠️ 注意：请求 MTU 是一个 _尽力而为_ 的操作。
> 在许多平台上，最终 MTU 完全由操作系统和远程设备控制。

#### 平台限制

MTU 协商在很大程度上由平台和协议栈管理，应用程序通常无法显式控制：

- **iOS**：MTU 完全由操作系统管理；应用程序无法请求或设置它。历史上约为 185 字节，但现代设备可能会自动协商更大的 MTU（约 247–517）。

- **Android**：
  - **Android ≤ 13**：应用程序每次连接可以请求一次 MTU（最多 517）。如果从未请求，默认 MTU 为 23。
  - **Android 14+**：第一个蓝牙客户端有效地将 MTU 协商驱动到 517（或链路的最大值）；后续的 MTU 请求将被忽略。

#### 最佳实践

在开发跨平台 BLE 应用和设备时：

- 始终为默认 ATT MTU（23 字节）进行设计
- 将 MTU 请求视为机会性的，而非保证的
- 根据协商的 MTU 动态调整数据包大小
- 为更大的有效载荷实现应用层分片
- 在可用时利用更高的 MTU，但不要依赖它们

### 请求连接优先级

在 Android 上，你可以请求更新连接参数以调整 BLE 连接间隔。这可以为数据密集型传输带来 3–7 倍的吞吐量提升。

```dart
// 在开始高吞吐量数据传输之前：
await PrinterConnect.requestConnectionPriority(
  deviceId,
  BleConnectionPriority.highPerformance,
);
```

> **注意：** 仅在 Android 上支持。在 iOS 上，这会抛出代码为 `notSupported` 的 `PrinterConnectException`。
> 在连接之后和 `requestMtu()` 之后，在开始数据传输之前调用此方法。

操作系统可能会在你的应用未请求的情况下更改连接参数（例如，为了省电），这可能会降低吞吐量。在 Android API 26+ 上，你可以通过自定义平台实现订阅平台级别的 `onConnectionParametersChange` 回调来监听连接参数变化。

> **注意：** 在每次更新时重新请求高优先级可能会与操作系统的电源管理器发生冲突——在应用代码中进行防抖处理。需要 Android API 26+。

### 读取 RSSI

读取已连接设备的信号强度（RSSI）。

```dart
int rssi = await bleDevice.readRssi();
```

> ⚠️ 注意：在读取 RSSI 之前，设备必须已连接。

## 错误处理

Printer Connect 提供了跨平台统一且类型安全的错误处理系统。所有错误都使用带有类型化错误代码的 `PrinterConnectException` 基类表示。

### 异常类型

- **`PrinterConnectException`**：所有 BLE 错误的基异常类
- **`ConnectionException`**：针对连接相关错误抛出
- **`PairingException`**：针对配对相关错误抛出
- **`WriteException`**：针对写入相关错误抛出
- **`ReadException`**：针对读取相关错误抛出
- **`ScanException`**：针对扫描相关错误抛出
- **`DiscoverServicesException`**：针对服务发现错误抛出
- **`SetNotifyException`**：针对通知/指示错误抛出
- **`MtuException`**：针对 MTU 相关错误抛出
- **`DeviceNotFoundException`**：在未找到设备/服务/特征时抛出
- **`OperationNotSupportedException`**：在当前平台不支持操作时抛出

### 错误代码

所有错误都使用字符串错误代码进行分类，包括：

- 连接错误（超时、失败、被拒绝等）
- 配对错误（失败、取消、不允许等）
- 操作错误（不支持、超时、取消等）
- 权限错误（不允许、未授权、访问被拒绝等）
- 设备错误（未找到、已断开连接等）
- 服务/特征错误（未找到、无效的 UUID 等）
- 以及更多...

### 用法

```dart
try {
  await bleDevice.connect();
} on ConnectionException catch (e) {
  // 处理连接特定的错误
  switch (e.code) {
    case 'connectionTimeout':
      // 处理超时
      break;
    case 'connectionFailed':
      // 处理连接失败
      break;
    case 'deviceDisconnected':
      // 处理断开连接
      break;
    default:
      // 处理其他连接错误
  }
} on PrinterConnectException catch (e) {
  // 处理其他 BLE 错误
  print('Error code: ${e.code}, Message: ${e.message}');
}
```

错误解析器会自动将平台特定的错误格式（字符串、数字代码、PlatformExceptions）转换为类型化的异常类，确保跨平台的错误处理一致性。

## UUID 格式无关性

Printer Connect 与服务和特征的 UUID 格式无关，无论应用运行在哪个平台上。传递 UUID 时，你可以以任何格式（长/短）或字符大小写（大写/小写）传递。Printer Connect 将处理所有平台上必要的转换，因此你无需担心底层平台的差异。

为了保持一致性，所有特征和服务的 UUID 将在所有平台上以**小写 128 位格式**返回，例如 `0000180a-0000-1000-8000-00805f9b34fb`。

### 实用方法

如果你需要在应用中转换任何 UUID，可以使用以下方法。

- `BleUuidParser.string()` 将字符串转换为 128 位 UUID 格式的字符串：

```dart
BleUuidParser.string("180A"); // "0000180a-0000-1000-8000-00805f9b34fb"

BleUuidParser.string("0000180A-0000-1000-8000-00805F9B34FB"); // "0000180a-0000-1000-8000-00805f9b34fb"
```

- `BleUuidParser.number()` 将数字转换为 128 位 UUID 格式的字符串：

```dart
BleUuidParser.number(0x180A); // "0000180a-0000-1000-8000-00805f9b34fb"
```

- `BleUuidParser.compareStrings()` 比较两个格式不同的 UUID：

```dart
BleUuidParser.compareStrings("180a","0000180A-0000-1000-8000-00805F9B34FB"); // true
```

## 平台特定设置

你需要执行以下设置：

### Android

#### Manifest 权限

在你的 AndroidManifest.xml 文件中添加以下权限。

```xml
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
```

- 这 5 条权限覆盖了完整的蓝牙打印机使用流程（扫描 → 连接 → 读写 → 配对 → MTU/RSSI/连接优先级），在 Android 6.0（API 23）到最新版本上所有功能正常。`maxSdkVersion` 和 `neverForLocation` 会让权限按 Android 版本自动生效，无需手动区分。
- 权限必须由宿主 App（而不是插件自身的 manifest）声明**，以便正确参与 manifest 合并并避免与其他插件冲突。

#### Android 位置权限

`requestPermissions()` 中的 `withAndroidFineLocation` 参数控制 Android 上的位置权限请求：

- **Android 12+ (API 31+)**：
  - `withAndroidFineLocation: true` → 请求 `ACCESS_FINE_LOCATION` 权限
  - `withAndroidFineLocation: false` → 仅请求蓝牙权限（无位置权限）
- **Android 11 及以下**：
  - 如果在 manifest 中声明了位置权限，则始终请求位置权限（BLE 扫描必需）
  - `withAndroidFineLocation` 参数将被忽略

#### 后台扫描（ForegroundTask）

Printer Connect 支持在 Android 上从后台服务（例如使用 `flutter_foreground_task` 或类似包）进行 BLE 扫描。在没有 Activity 的后台上下文中运行时：

- **如果已授予权限**：扫描正常工作
- **如果未授予权限**：抛出错误，消息为"权限未授予且活动不可用以请求它们"

**最佳实践**：在启动任何后台 BLE 操作之前，在应用处于前台时请求权限：

```dart
// 在前台请求权限（例如，在应用设置期间）
await PrinterConnect.requestPermissions();

// 稍后，在你的 ForegroundTask 中，如果已授予权限，扫描将正常工作
await PrinterConnect.startScan();
```

### iOS

对于蓝牙使用，请将以下键添加到应用的 `Info.plist` 中：

- `NSBluetoothAlwaysUsageDescription`：应用请求蓝牙访问时显示的消息。

示例：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to scan, connect, and communicate with nearby devices.</string>
```

使用清晰、面向用户的文本来解释你的应用为什么需要蓝牙。

#### iOS 后台状态恢复

在 iOS 上，当你的应用声明了 `bluetooth-central` 后台模式并且已授予蓝牙权限时，中央管理器会在启动时使用 `CBCentralManagerOptionRestoreIdentifierKey` 创建，因此 CoreBluetooth 可以[在后台重新启动你的应用](https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules)，当连接的外设活动时，并将活动连接交还给插件。如果尚未授予权限，创建将延迟到调用中央 BLE API（如 `startScan()` 或 `connect()`）时。

要选择加入，请声明 `Uses Bluetooth LE accessories` 后台模式。启用后，在 `Info.plist` 中你应该有：

```xml
<key>UIBackgroundModes</key>
<array>
  ...
  <string>bluetooth-central</string>
  ...
</array>
```

注意：

- 没有 `bluetooth-central` 后台模式，`CBCentralManager` 会在第一次中央 BLE API 调用时懒加载创建，并且状态恢复被禁用。
- 重新启动后，插件会重新采用恢复的外设，并为任何仍在连接的外设发出 `onConnectionChanged`，因此你的 Dart 代码可以从中断处恢复。

### 手动请求权限

**调用 `requestPermissions()` 是可选的。** 在调用 `startScan()` 时会自动请求权限。但是，如果你想手动调用 `requestPermissions()`，可以：

- 在扫描之前请求权限（例如，单独处理权限错误）
- 确保在其他操作（如 `connect()`、`read()`、`write()` 等）之前授予权限，这些操作不会自动请求权限

`requestPermissions()` 方法：

- 如果所有权限已经授予或被用户接受，则成功返回
- 如果权限被用户拒绝，则抛出 `PrinterConnectException`

```dart
// 可选：手动请求权限
await PrinterConnect.requestPermissions(
  withAndroidFineLocation: false,
);
```

> **注意**：调用 `startScan()` 时，会自动请求权限。要在扫描期间配置位置权限请求，请在 `AndroidOptions` 上使用 `requestLocationPermission`：

```dart
PrinterConnect.startScan(
  platformConfig: PlatformConfig(
    android: AndroidOptions(
      requestLocationPermission: false,
    ),
  ),
);
```

## 日志记录

配置日志记录以帮助调试 BLE 操作

### 用法

在应用初始化期间设置日志级别，默认级别为 `none`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 启用详细日志以查看所有 BLE 操作
  await PrinterConnect.setLogLevel(BleLogLevel.verbose);
  runApp(MyApp());
}
```

## 在热重启时重置状态

在调试模式下进行 Flutter 热重启期间，应用状态会重置，但原生蓝牙连接和扫描操作可能会持续存在。这可能导致连接问题或陈旧状态。

<details> 
<summary>使用以下辅助函数在应用重启前正确清理 BLE 状态。</summary>

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 在应用初始化之前重置 BLE 状态
  await resetBleState();
  runApp(MyApp());
}

/// 通过停止扫描并断开所有设备来重置 BLE 状态。
/// 调用此函数前请确保你已拥有蓝牙权限。
Future<void> resetBleState() async {
  // 检查蓝牙可用性
  AvailabilityState availabilityState =
      await PrinterConnect.getBluetoothAvailabilityState();

  // 如果蓝牙未开机，则跳过
  if (availabilityState != AvailabilityState.poweredOn) {
    debugPrint('Reset: 蓝牙未开机');
    return;
  }

  // 停止扫描
  if (await PrinterConnect.isScanning()) {
    debugPrint('Reset: 正在停止扫描');
    await PrinterConnect.stopScan();
  }

  // 断开所有已连接的设备
  // 在 Apple 平台上，你必须指定服务才能发现已连接的设备
  List<BleDevice> connectedDevices =
      await PrinterConnect.getSystemDevices(withServices: []);

  for (var device in connectedDevices) {
    debugPrint('Reset: 正在断开设备: ${device.deviceId}');
    await PrinterConnect.disconnect(device.deviceId);
  }

  debugPrint('Reset: 完成');
}
```

</details>

## 示例应用

此仓库包含一个[示例应用](example/)，演示了基本的扫描和设备通信工作流程。

测试应用使用方式: 先通过 flutter devices 获取到设备ID，然后运行以下命令:
```
cd example
flutter run -d <device_id>
```

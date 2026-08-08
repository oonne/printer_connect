# Printer Connect

[![pub package](https://img.shields.io/pub/v/printer_connect?label=printer_connect&color=blue)](https://pub.dev/packages/printer_connect)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](https://github.com/oonne/printer_connect)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.16.0-blue.svg?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.1.3-blue.svg?logo=dart)](https://dart.dev)
[![pub points](https://img.shields.io/pub/points/printer_connect?color=2E7D32)](https://pub.dev/packages/printer_connect/score)
[![GitHub stars](https://img.shields.io/github/stars/oonne/printer_connect?style=social)](https://github.com/oonne/printer_connect)

连接打印机。

## 快速开始

安装插件:

```
flutter pub add printer_connect
```

在需要使用它的地方导入：

```dart
import 'dart:typed_data';
import 'package:printer_connect/printer_connect.dart';
```

### Android

在你的 AndroidManifest.xml 文件中添加以下权限。

```xml
  <!-- 蓝牙权限 -->
  <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
  <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
      android:usesPermissionFlags="neverForLocation" />
  <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
  <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />

  <!-- 硬件特性声明 -->
  <uses-feature android:name="android.hardware.bluetooth" android:required="true" />
  <uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
```

#### Android 位置权限

`requestPermissions()` 中的 `withAndroidFineLocation` 参数控制 Android 上的位置权限请求：

- **Android 12+ (API 31+)**：
  - `withAndroidFineLocation: true` → 请求 `ACCESS_FINE_LOCATION` 权限
  - `withAndroidFineLocation: false` → 仅请求蓝牙权限（无位置权限）
- **Android 11 及以下**：
  - 如果在 manifest 中声明了位置权限，则始终请求位置权限（BLE 扫描必需）
  - `withAndroidFineLocation` 参数将被忽略

### iOS

对于蓝牙使用，请将以下键添加到应用的 `Info.plist` 中：

- `NSBluetoothAlwaysUsageDescription`：应用请求蓝牙访问时显示的消息。

示例：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app requires Bluetooth access to discover, connect, and print to your printer.</string>
```

使用清晰、面向用户的文本来解释你的应用为什么需要蓝牙。

### 自动权限与蓝牙状态检查

**`startScan()` 和 `connect()` 会自动执行前置检查**，无需手动处理：

1. **权限检查**：自动检查并请求蓝牙相关权限
   - 如果权限已授予，直接继续
   - 如果权限未授予，自动调用 `requestPermissions()` 请求权限
   - 如果用户拒绝权限，抛出 `PrinterConnectException('permission_request_failed')` 或 `PrinterConnectException('permissions_not_granted')`
2. **蓝牙状态检查**：自动检查蓝牙是否已开启
   - **Android**：如果蓝牙未开启，自动调用 `enableBluetooth()` 尝试开启
   - **iOS/macOS**：如果蓝牙未开启，直接抛出 `PrinterConnectException('bluetooth_not_enabled')`
   - 如果 `enableBluetooth()` 返回 `false`（用户拒绝），抛出同样的异常

```dart
// startScan 和 connect 已内置上述检查，直接调用即可：
await PrinterConnect.startScan();
await Printer.connect(deviceId);
```

## API

### 一、基础API

| 功能                          | 方法                            | Android | iOS |
| :---------------------------- | :------------------------------ | :-----: | :-: |
| [扫描](bluetooth_api.md#扫描)                 | startScan/stopScan              |   ✔️    | ✔️  |
| [系统设备](bluetooth_api.md#系统设备)         | getSystemDevices                |   ✔️    | ✔️  |
| [连接/断开](bluetooth_api.md#连接)            | connect/disconnect              |   ✔️    | ✔️  |
| [获取打印服务](bluetooth_api.md#获取打印服务) | PrinterServiceFinder.initDevice |   ✔️    | ✔️  |
| [写入数据](bluetooth_api.md#读取与写入数据)   | write                           |   ✔️    | ✔️  |
| [订阅通知](bluetooth_api.md#订阅)             | subscriptions                   |   ✔️    | ✔️  |

### 二、高级API

| 功能                                | 方法                          | Android | iOS |
| :---------------------------------- | :---------------------------- | :-----: | :-: |
| [获取蓝牙状态](bluetooth_api.md#蓝牙可用性)         | getBluetoothAvailabilityState |   ✔️    | ✔️  |
| [启用蓝牙](bluetooth_api.md#蓝牙可用性)             | enableBluetooth               |   ✔️    | ❌  |
| [蓝牙状态流](bluetooth_api.md#蓝牙可用性)           | availabilityStream            |   ✔️    | ✔️  |
| [发现服务](bluetooth_api.md#发现服务)               | discoverServices              |   ✔️    | ✔️  |
| [读取数据](bluetooth_api.md#读取与写入数据)         | read                          |   ✔️    | ✔️  |
| [请求MTU](bluetooth_api.md#请求-mtu)                | requestMtu                    |   ✔️    | ✔️  |
| [请求连接优先级](bluetooth_api.md#请求连接优先级)   | requestConnectionPriority     |   ✔️    | ❌  |
| [连接参数变化回调](bluetooth_api.md#请求连接优先级) | onConnectionParametersChange  |   ✔️    | ❌  |
| [读取信号强度](bluetooth_api.md#读取-rssi)          | readRssi                      |   ✔️    | ✔️  |
| [请求权限](bluetooth_api.md#手动请求权限)           | requestPermissions            |   ✔️    | ✔️  |

## 错误处理

Printer Connect 提供了跨平台统一且类型安全的错误处理系统。所有错误都使用带有类型化错误代码的 `PrinterConnectException` 基类表示。

### 异常类型

- **`PrinterConnectException`**：所有 BLE 错误的基异常类
- **`ConnectionException`**：针对连接相关错误抛出
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
- 操作错误（不支持、超时、取消等）
- 权限错误（不允许、未授权、访问被拒绝等）
- **自动检查错误**（`permission_request_failed`、`permissions_not_granted`、`bluetooth_not_enabled`）
- 设备错误（未找到、已断开连接等）
- 服务/特征错误（未找到、无效的 UUID 等）
- 以及更多...

### 用法

```dart
try {
  await PrinterConnect.startScan();
  // 或：await bleDevice.connect();
} on PrinterConnectException catch (e) {
  // 处理自动检查相关的错误
  switch (e.code) {
    case 'permission_request_failed':
      // 权限请求失败（用户拒绝或系统错误）
      break;
    case 'permissions_not_granted':
      // 权限未授予
      break;
    case 'bluetooth_not_enabled':
      // 蓝牙未开启（iOS/macOS 上需用户手动开启，Android 上 enableBluetooth 被拒绝）
      break;
    default:
      // 处理其他 BLE 错误
      print('Error code: ${e.code}, Message: ${e.message}');
  }
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

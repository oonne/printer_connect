# 蓝牙API

> 返回 [README](README.md)。

## 扫描

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
>
> **`startScan()` 会自动处理权限和蓝牙状态**（参见[自动权限与蓝牙状态检查](README.md#自动权限与蓝牙状态检查)），无需在调用前手动检查。如果需要在 UI 上显示蓝牙状态变化，可以使用 `availabilityStream`：

```dart
// 使用流监听蓝牙可用性变化
PrinterConnect.availabilityStream.listen((state) {
  // 处理蓝牙状态变化
});
```

更多信息请参见[蓝牙可用性](#蓝牙可用性)部分。

### 系统设备

已连接的设备（无论是通过之前的会话、其他应用还是通过系统设置连接的）不会作为扫描结果显示。你可以使用 `getSystemDevices()` 获取它们。

```dart
// 获取已连接的设备。
// 你可以设置 `withServices` 来缩小结果范围。
// 在 `Apple` 平台上，获取任何已连接设备都需要 `withServices`。如果未传递，将默认设置几个 [18XX] 通用服务。
List<BleDevice> devices = await PrinterConnect.getSystemDevices(withServices: []);
```

对于每个这样的设备，`isSystemDevice` 属性将为 `true`。
在能够使用它们之前，你仍然需要显式地[连接](#连接)它们。

### 扫描过滤器

你可以在扫描时可选地设置过滤器。过滤器可以有多个条件（服务、制造商数据、名称前缀），所有条件之间是 `OR` 关系，返回匹配任何给定条件的结果。

#### 按服务过滤

设置此参数后，扫描结果将仅包含广播了任何指定服务的设备。

```dart
List<String> withServices;
```

#### 按制造商数据过滤

使用 `withManufacturerData` 参数按制造商数据过滤设备。当你向此参数传递一个 `ManufacturerDataFilter` 对象列表时，扫描结果将仅包含包含任何指定制造商数据的设备。
你可以通过公司标识符、载荷前缀或载荷掩码来过滤制造商数据。

```dart
List<ManufacturerDataFilter> withManufacturerData = [ManufacturerDataFilter(
            companyIdentifier: 0x004c,
            payloadPrefix: Uint8List.fromList([0x001D,0x001A]),
            payloadMask: Uint8List.fromList([1,0,1,1]))
          ];
```

#### 按名称前缀过滤

使用 `withNamePrefix` 参数按名称过滤设备（区分大小写）。当你传递一个名称列表时，扫描结果将仅包含具有该名称或以提供的参数开头的设备。

```dart
List<String> withNamePrefix;
```

#### 排除过滤器

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

## 连接

### 连接

连接到 BLE 设备。插件提供两种连接方式：

1. **通过 `BleDevice` 实例连接**（已有设备对象时）：

```dart
await bleDevice.connect();
```

2. **通过设备 ID 连接**（已知 deviceId，无需先获取 `BleDevice` 对象）：

```dart
await PrinterConnect.connect(deviceId);
```

> **注意**：两种 `connect()` 都会自动执行权限和蓝牙状态前置检查（参见[自动权限与蓝牙状态检查](README.md#自动权限与蓝牙状态检查)）。

### 断开连接

断开与 BLE 设备的连接。此方法终止与蓝牙设备的连接。

```dart
await bleDevice.disconnect();
```

### 连接流

```dart
bleDevice.connectionStream.listen((isConnected) {
  debugPrint('设备已连接吗？ $isConnected');
});
```

### IsConnected

```dart
bool isConnected = await bleDevice.isConnected;
```

### 连接状态

```dart
// 可以是 connected, disconnected, connecting 或 disconnecting
BleConnectionState connectionState = await bleDevice.connectionState;
```

## 发现服务

建立连接后，需要发现服务。此方法将发现所有服务及其特征。
如果你不调用此方法，那么当你尝试获取任何服务或特征时，它将被自动调用。

### DiscoverServices

发现设备提供的服务。返回一个 `Future<List<BleService>>`。发现服务后会缓存，每次调用此方法都会更新缓存。

```dart
List<BleService> services = await bleDevice.discoverServices();
for (var service in services) {
  debugPrint('Service UUID: ${service.uuid}');
}
```

### GetService

检索特定服务。返回一个 `Future<BleService>`。

- `service`：服务的 UUID。
- `preferCached`：如果为 `true`（默认值），则使用缓存的服务。如果缓存为空，将调用 `discoverServices()`。

```dart
BleService service = await bleDevice.getService('180a');
```

### GetCharacteristic

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

## 获取打印服务

不同厂商的打印机使用不同的标准方式来获取可用的 service 和 characteristic。`PrinterServiceFinder.initDevice` 封装了这一过程：通过蓝牙名判断设备厂商，自动连接设备并按各厂商规则获取打印所需的 service 和 characteristic。同时返回该设备使用的标签指令类型 `labelCodeType`（`CPCL`或`TSPL`），在标签打印场景中可以选择对应的指令集。

### 用法

```dart
// 输入 deviceId 和 name，自动连接设备并获取打印所需的 service 和 characteristic
PrinterServiceInfo info = await PrinterServiceFinder.initDevice(
  deviceId: device.deviceId,
  name: device.name ?? '',
);

// 返回的对象包含 deviceId、name、service、characteristic、labelCodeType
print('deviceId: ${info.deviceId}');
print('name: ${info.name}');
print('service: ${info.service}');
print('characteristic: ${info.characteristic}');
print('labelCodeType: ${info.labelCodeType}'); // CPCL 或 TSPL

// 后续可直接使用返回的 service 和 characteristic 进行写入
await PrinterConnect.write(
  info.deviceId,
  info.service,
  info.characteristic,
  Uint8List.fromList([0x01, 0x02, 0x03]),
);
```

> **提示**：`initDevice` 内部会自动调用 `connect`（含权限和蓝牙状态检查），无需手动连接。每次调用都会重新连接设备并获取最新的 service 和 characteristic。

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

## 蓝牙可用性

```dart
// 获取当前蓝牙可用性状态
AvailabilityState availabilityState = await PrinterConnect.getBluetoothAvailabilityState(); // 例如：poweredOff 或 poweredOn
// 通过流接收蓝牙可用性变化
PrinterConnect.availabilityStream.listen((state) {
  // 处理新的蓝牙可用性状态
});
// 以编程方式启用蓝牙（仅限 Android）
// 注意：startScan() 和 connect() 在 Android 上会自动调用 enableBluetooth()
await PrinterConnect.enableBluetooth();
```

## 请求 MTU

```dart
int mtu = await bleDevice.requestMtu(256);
```

> ⚠️ 注意：请求 MTU 是一个 _尽力而为_ 的操作。
> 在许多平台上，最终 MTU 完全由操作系统和远程设备控制。

### 平台限制

MTU 协商在很大程度上由平台和协议栈管理，应用程序通常无法显式控制：

- **iOS**：MTU 完全由操作系统管理；应用程序无法请求或设置它。历史上约为 185 字节，但现代设备可能会自动协商更大的 MTU（约 247–517）。
- **Android**：
  - **Android ≤ 13**：应用程序每次连接可以请求一次 MTU（最多 517）。如果从未请求，默认 MTU 为 23。
  - **Android 14+**：第一个蓝牙客户端有效地将 MTU 协商驱动到 517（或链路的最大值）；后续的 MTU 请求将被忽略。

### 最佳实践

在开发跨平台 BLE 应用和设备时：

- 始终为默认 ATT MTU（23 字节）进行设计
- 将 MTU 请求视为机会性的，而非保证的
- 根据协商的 MTU 动态调整数据包大小
- 为更大的有效载荷实现应用层分片
- 在可用时利用更高的 MTU，但不要依赖它们

## 请求连接优先级

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
> 操作系统可能会在你的应用未请求的情况下更改连接参数（例如，为了省电），这可能会降低吞吐量。在 Android API 26+ 上，你可以通过自定义平台实现订阅平台级别的 `onConnectionParametersChange` 回调来监听连接参数变化。
> **注意：** 在每次更新时重新请求高优先级可能会与操作系统的电源管理器发生冲突——在应用代码中进行防抖处理。需要 Android API 26+。

## 读取 RSSI

读取已连接设备的信号强度（RSSI）。

```dart
int rssi = await bleDevice.readRssi();
```

> ⚠️ 注意：在读取 RSSI 之前，设备必须已连接。


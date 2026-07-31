import 'package:printer_connect/src/printer_connect.g.dart';

/// 平台特定的扫描配置
///
/// 如果某个参数被多个平台支持，则应放在高层 API 中而非平台特定选项中。
class PlatformConfig {
  /// Web 平台选项
  WebOptions? web;

  /// Android 平台选项
  AndroidOptions? android;

  PlatformConfig({this.web, this.android});
}

/// Web 平台扫描选项
///
/// [optionalServices] 是服务 UUID 列表，用于确保连接设备后可以访问指定服务，
/// 默认使用 scanFilter 中的服务列表。
/// [optionalManufacturerData] 是公司标识符列表，用于在 Web 对话框的广播结果中
/// 添加指定的厂商数据，默认使用 scanFilter 中的厂商数据。
/// 更多详情请参考 [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Bluetooth/requestDevice)。
/// 注意：仅当浏览器启用了实验性标志时才会获取广播数据。
class WebOptions {
  /// 可选服务 UUID 列表
  List<String> optionalServices;

  /// 可选厂商数据公司标识符列表
  List<int> optionalManufacturerData;

  WebOptions({
    this.optionalServices = const [],
    this.optionalManufacturerData = const [],
  });
}

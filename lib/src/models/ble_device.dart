import 'package:flutter/foundation.dart';
import 'package:printer_connect/printer_connect.dart';

/// BLE 设备信息封装类
///
/// 包含蓝牙设备的所有基础信息，如设备 ID、名称、信号强度、配对状态、
/// 可用服务列表、厂商数据、服务数据以及时间戳等。
class BleDevice {
  /// 设备唯一标识符
  String deviceId;

  /// 设备名称（已过滤不可打印字符）
  String? name;

  /// 原始设备名称（未过滤）
  String? rawName;

  /// 信号强度指示值（RSSI），单位 dBm
  int? rssi;

  /// 是否已配对
  bool? paired;

  /// 设备支持的服务 UUID 列表
  List<String> services;

  /// 是否为系统设备（Android 特有）
  bool? isSystemDevice;

  /// 厂商特定数据列表
  List<ManufacturerData> manufacturerDataList;

  /// 服务数据映射（键为服务 UUID，值为数据字节）
  Map<String, Uint8List> serviceData;

  /// 设备扫描时间戳（毫秒）
  int? timestamp;

  BleDevice({
    required this.deviceId,
    required String? name,
    this.rssi,
    this.paired,
    this.services = const [],
    this.isSystemDevice,
    this.manufacturerDataList = const [],
    Map<String, Uint8List>? serviceData,
    this.timestamp,
  }) : rawName = name,
       name = name?.replaceAll(RegExp(r'[^ -~]'), '').trim(),
       serviceData = _validateServiceData(serviceData ?? const {});

  /// 验证并规范化服务数据
  ///
  /// 将所有服务 UUID 转换为标准格式，并确保数据字节列表可修改。
  /// 空数据时返回空集合。
  static Map<String, Uint8List> _validateServiceData(
    Map<String, Uint8List> data,
  ) {
    if (data.isEmpty) return const {};
    return data.map(
      (key, value) => MapEntry(
        BleUuidParser.stringOrNull(key) ?? key,
        Uint8List.fromList(value),
      ),
    );
  }

  @Deprecated('Use manufacturerDataList instead')
  Uint8List? get manufacturerData {
    if (manufacturerDataList.isEmpty) return null;
    return manufacturerDataList.first.toUint8List();
  }

  Future<BleConnectionState> get connectionState async {
    return PrinterConnect.getConnectionState(deviceId);
  }

  Future<int?> get readRssi async {
    return PrinterConnect.readRssi(deviceId);
  }

  bool get receivesAdvertisements =>
      PrinterConnect.receivesAdvertisements(deviceId);

  DateTime? get timestampDateTime {
    final ts = timestamp;
    if (ts == null || ts == 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          name == other.name &&
          rawName == other.rawName &&
          rssi == other.rssi &&
          paired == other.paired &&
          _listEquals(services, other.services) &&
          isSystemDevice == other.isSystemDevice &&
          _listEquals(manufacturerDataList, other.manufacturerDataList) &&
          _mapEquals(serviceData, other.serviceData) &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
    deviceId,
    name,
    rawName,
    rssi,
    paired,
    services,
    isSystemDevice,
    manufacturerDataList,
    serviceData,
    timestamp,
  );

  bool _listEquals(List a, List b) {
    return listEquals(a, b);
  }

  bool _mapEquals(Map<String, Uint8List> a, Map<String, Uint8List> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final va = a[key]!;
      final vb = b[key]!;
      if (va.length != vb.length) return false;
      for (int i = 0; i < va.length; i++) {
        if (va[i] != vb[i]) return false;
      }
    }
    return true;
  }

  @override
  String toString() =>
      'BleDevice(deviceId: $deviceId, name: $name, rssi: $rssi, paired: $paired, services: ${services.length}, isSystemDevice: $isSystemDevice, manufacturerDataList: ${manufacturerDataList.length}, serviceData: ${serviceData.length}, timestamp: $timestamp)';
}

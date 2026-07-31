import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:printer_connect/src/printer_connect.g.dart';

/// BLE 设备厂商数据封装类
///
/// 解析和表示蓝牙广播中的厂商特定数据，包含公司 ID 和数据载荷。
/// 厂商数据以 16 位公司 ID 开头，后跟数据载荷。
class ManufacturerData {
  /// 公司标识符（16 位）
  final int companyId;

  /// 厂商数据载荷
  final Uint8List payload;

  ManufacturerData(this.companyId, this.payload);

  String get companyIdRadix16 => "0x0${companyId.toRadixString(16)}";

  String get payloadRadix16 =>
      "0x${payload.map((e) => e.toRadixString(16).toUpperCase().padLeft(2, '0')).join('')}";

  /// 从原始字节数据解析厂商数据
  ///
  /// 前两个字节为公司 ID（小端序），剩余字节为载荷数据。
  factory ManufacturerData.fromData(Uint8List data) {
    if (data.length < 2) {
      throw const FormatException("Invalid Manufacturer Data");
    }
    return ManufacturerData((data[0] + (data[1] << 8)), data.sublist(2));
  }

  /// 转换为字节列表（小端序公司 ID + 载荷）
  Uint8List toUint8List() {
    final byteData = ByteData(2);
    byteData.setInt16(0, companyId, Endian.host);
    return Uint8List.fromList(byteData.buffer.asUint8List() + payload.toList());
  }

  @override
  int get hashCode => companyId.hashCode ^ payload.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ManufacturerData) return false;
    return companyId == other.companyId && listEquals(payload, other.payload);
  }

  UniversalManufacturerData toUniversalManufacturerData() {
    return UniversalManufacturerData(
      companyIdentifier: companyId,
      data: payload,
    );
  }

  @override
  String toString() {
    return 'Manufacturer: $companyIdRadix16 - $payload';
  }
}

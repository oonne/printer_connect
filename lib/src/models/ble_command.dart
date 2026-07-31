import 'dart:typed_data';

/// BLE 命令封装类
///
/// 描述一个蓝牙操作命令，包括目标服务、特征和待写入数据。
/// 用于在队列化操作中表示一个完整的蓝牙指令。
class BleCommand {
  /// 目标服务 UUID
  final String service;

  /// 目标特征 UUID
  final String characteristic;

  /// 待写入的数据（可选，读操作时为 null）
  final Uint8List? writeValue;

  const BleCommand({
    required this.service,
    required this.characteristic,
    this.writeValue,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleCommand &&
          runtimeType == other.runtimeType &&
          service == other.service &&
          characteristic == other.characteristic &&
          _listEquals(writeValue, other.writeValue);

  @override
  int get hashCode => Object.hash(service, characteristic, writeValue);

  bool _listEquals(Uint8List? a, Uint8List? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'BleCommand(service: $service, characteristic: $characteristic, writeValue: ${writeValue?.length ?? 0} bytes)';
}
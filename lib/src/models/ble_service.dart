import 'ble_uuid_parser.dart';

/// BLE 服务封装类
///
/// 表示蓝牙设备提供的一个服务，包含服务 UUID 和该服务下的所有特征。
class BleService {
  /// 服务 UUID
  final String uuid;

  /// 该服务下的特征列表
  final List<BleCharacteristic> characteristics;

  BleService({required String uuid, this.characteristics = const []})
    : uuid = BleUuidParser.string(uuid);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleService &&
          runtimeType == other.runtimeType &&
          uuid == other.uuid &&
          _listEquals(characteristics, other.characteristics);

  @override
  int get hashCode => Object.hash(uuid, Object.hashAll(characteristics));

  bool _listEquals(List<BleCharacteristic> a, List<BleCharacteristic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'BleService(uuid: $uuid, characteristics: ${characteristics.length})';
}

/// BLE 特征封装类
///
/// 表示服务中的一个特征值，包含 UUID、属性列表、描述符列表和元数据。
class BleCharacteristic {
  /// 特征 UUID
  final String uuid;

  /// 特征属性列表（如可读、可写、通知等）
  final List<CharacteristicProperty> properties;

  /// 特征描述符列表
  final List<BleDescriptor> descriptors;

  /// 元数据，包含所属设备 ID 和服务 ID
  final ({String deviceId, String serviceId})? metaData;

  BleCharacteristic({
    required String uuid,
    this.properties = const [],
    this.descriptors = const [],
    this.metaData,
  }) : uuid = BleUuidParser.string(uuid);

  BleCharacteristic.withMetaData({
    required String uuid,
    this.properties = const [],
    this.descriptors = const [],
    required String deviceId,
    required String serviceId,
  }) : metaData = (
         deviceId: deviceId,
         serviceId: BleUuidParser.string(serviceId),
       ),
       uuid = BleUuidParser.string(uuid);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleCharacteristic &&
          runtimeType == other.runtimeType &&
          uuid == other.uuid &&
          _listEquals(properties, other.properties) &&
          _listEquals(descriptors, other.descriptors);

  @override
  int get hashCode => Object.hash(
      uuid, Object.hashAll(properties), Object.hashAll(descriptors));

  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'BleCharacteristic(uuid: $uuid, properties: ${properties.length}, descriptors: ${descriptors.length})';
}

/// BLE 描述符封装类
///
/// 描述符提供特征的附加信息，如特征的可读描述、值单位等。
class BleDescriptor {
  final String uuid;

  const BleDescriptor({required this.uuid});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleDescriptor &&
          runtimeType == other.runtimeType &&
          uuid == other.uuid;

  @override
  int get hashCode => uuid.hashCode;

  @override
  String toString() => 'BleDescriptor(uuid: $uuid)';
}

/// BLE 特征属性枚举
///
/// 定义了蓝牙特征值支持的各种操作属性。
enum CharacteristicProperty {
  /// 广播属性 - 特征值可通过广播方式发送
  broadcast,

  /// 读属性 - 特征值可读
  read,

  /// 无响应写属性 - 写入时不等待响应
  writeWithoutResponse,

  /// 写属性 - 特征值可写
  write,

  /// 通知属性 - 特征值变化时自动通知
  notify,

  /// 指示属性 - 特征值变化时指示（需要确认）
  indicate,

  /// 认证签名写属性 - 支持认证签名写入
  authenticatedSignedWrites,

  /// 扩展属性 - 支持扩展属性
  extendedProperties,
}

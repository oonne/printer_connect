import 'ble_uuid_parser.dart';

class BleService {
  final String uuid;
  final List<BleCharacteristic> characteristics;

  BleService({
    required String uuid,
    this.characteristics = const [],
  }) : uuid = BleUuidParser.string(uuid);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleService &&
          runtimeType == other.runtimeType &&
          uuid == other.uuid &&
          _listEquals(characteristics, other.characteristics);

  @override
  int get hashCode => Object.hash(uuid, characteristics);

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

class BleCharacteristic {
  final String uuid;
  final List<CharacteristicProperty> properties;
  final List<BleDescriptor> descriptors;
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
  })  : metaData = (deviceId: deviceId, serviceId: BleUuidParser.string(serviceId)),
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
  int get hashCode => Object.hash(uuid, properties, descriptors);

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

class BleDescriptor {
  final String uuid;

  const BleDescriptor({
    required this.uuid,
  });

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

CharacteristicProperty _propertyFromName(String name) {
  return CharacteristicProperty.values.byName(name);
}

CharacteristicProperty _parseCharacteristicProperty(String value) {
  return CharacteristicProperty.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown characteristic property: $value'),
  );
}

enum CharacteristicProperty {
  broadcast,
  read,
  writeWithoutResponse,
  write,
  notify,
  indicate,
  authenticatedSignedWrites,
  extendedProperties,
}
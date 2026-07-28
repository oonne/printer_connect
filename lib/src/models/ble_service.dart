class BleService {
  final String uuid;
  final List<BleCharacteristic> characteristics;

  const BleService({
    required this.uuid,
    this.characteristics = const [],
  });

  factory BleService.fromJson(Map<String, dynamic> json) {
    return BleService(
      uuid: json['uuid'] as String,
      characteristics: (json['characteristics'] as List<dynamic>?)
              ?.map((e) => BleCharacteristic.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'characteristics': characteristics.map((e) => e.toJson()).toList(),
    };
  }

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

  const BleCharacteristic({
    required this.uuid,
    this.properties = const [],
    this.descriptors = const [],
  });

  factory BleCharacteristic.fromJson(Map<String, dynamic> json) {
    return BleCharacteristic(
      uuid: json['uuid'] as String,
      properties: (json['properties'] as List<dynamic>?)
              ?.map((e) => _parseCharacteristicProperty(e as String))
              .toList() ??
          [],
      descriptors: (json['descriptors'] as List<dynamic>?)
              ?.map((e) => BleDescriptor.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'properties': properties.map((e) => e.name).toList(),
      'descriptors': descriptors.map((e) => e.toJson()).toList(),
    };
  }

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

  factory BleDescriptor.fromJson(Map<String, dynamic> json) {
    return BleDescriptor(
      uuid: json['uuid'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
    };
  }

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
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_connect/printer_connect.dart';

void main() {
  group('BleCharacteristic equality', () {
    test('equal when uuid and properties have equal content', () {
      final a = BleCharacteristic(
        uuid: '2a00',
        properties: [
          CharacteristicProperty.read,
          CharacteristicProperty.notify,
        ],
        descriptors: [],
      );
      final b = BleCharacteristic(
        uuid: '2a00',
        properties: [
          CharacteristicProperty.read,
          CharacteristicProperty.notify,
        ],
        descriptors: [],
      );

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when properties differ', () {
      final a = BleCharacteristic(
        uuid: '2a00',
        properties: [CharacteristicProperty.read],
        descriptors: [],
      );
      final b = BleCharacteristic(
        uuid: '2a00',
        properties: [CharacteristicProperty.write],
        descriptors: [],
      );

      expect(a == b, isFalse);
    });

    test('not equal when uuid differs', () {
      final a = BleCharacteristic(
        uuid: '2a00',
        properties: [CharacteristicProperty.read],
        descriptors: [],
      );
      final b = BleCharacteristic(
        uuid: '2a01',
        properties: [CharacteristicProperty.read],
        descriptors: [],
      );

      expect(a == b, isFalse);
    });

    test('usable as Set/Map key with equal-content instances', () {
      final a = BleCharacteristic(
        uuid: '2a00',
        properties: [
          CharacteristicProperty.read,
          CharacteristicProperty.notify,
        ],
        descriptors: [],
      );
      final b = BleCharacteristic(
        uuid: '2a00',
        properties: [
          CharacteristicProperty.read,
          CharacteristicProperty.notify,
        ],
        descriptors: [],
      );

      final set = {a};
      expect(set.contains(b), isTrue);

      final map = {a: true};
      expect(map.containsKey(b), isTrue);
    });
  });
}

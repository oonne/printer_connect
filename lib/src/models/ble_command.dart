import 'dart:typed_data';

class BleCommand {
  final String service;
  final String characteristic;
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
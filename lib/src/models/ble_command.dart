import 'dart:typed_data';

class BleCommand {
  final String service;
  final String characteristic;
  final Uint8List writeValue;

  const BleCommand({
    required this.service,
    required this.characteristic,
    required this.writeValue,
  });

  factory BleCommand.fromJson(Map<String, dynamic> json) {
    return BleCommand(
      service: json['service'] as String,
      characteristic: json['characteristic'] as String,
      writeValue: Uint8List.fromList((json['writeValue'] as List<dynamic>).cast<int>()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'service': service,
      'characteristic': characteristic,
      'writeValue': writeValue,
    };
  }

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

  bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'BleCommand(service: $service, characteristic: $characteristic, writeValue: ${writeValue.length} bytes)';
}
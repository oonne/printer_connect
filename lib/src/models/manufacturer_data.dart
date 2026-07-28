import 'dart:typed_data';

class ManufacturerData {
  final int companyId;
  final Uint8List payload;
  final Uint8List? mask;

  const ManufacturerData({
    required this.companyId,
    required this.payload,
    this.mask,
  });

  factory ManufacturerData.fromData(int companyId, Uint8List data,
      [Uint8List? mask]) {
    return ManufacturerData(
      companyId: companyId,
      payload: data,
      mask: mask,
    );
  }

  Uint8List toUint8List() => payload;

  Map<String, dynamic> toUniversalManufacturerData() {
    return {
      'companyId': companyId,
      'data': payload,
      'mask': mask,
    };
  }

  String get companyIdRadix16 => companyId.toRadixString(16).padLeft(4, '0').toUpperCase();

  String get payloadRadix16 =>
      payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManufacturerData &&
          runtimeType == other.runtimeType &&
          companyId == other.companyId &&
          _listEquals(payload, other.payload);

  @override
  int get hashCode => Object.hash(companyId, payload);

  bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'ManufacturerData(companyId: $companyId, payload: ${payload.length} bytes)';
}
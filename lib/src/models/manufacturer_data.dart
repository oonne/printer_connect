import 'dart:typed_data';

class ManufacturerData {
  final int companyId;
  final Uint8List data;
  final Uint8List? mask;

  const ManufacturerData({
    required this.companyId,
    required this.data,
    this.mask,
  });

  factory ManufacturerData.fromJson(Map<String, dynamic> json) {
    return ManufacturerData(
      companyId: json['companyId'] as int,
      data: Uint8List.fromList((json['data'] as List<dynamic>).cast<int>()),
      mask: json['mask'] != null
          ? Uint8List.fromList((json['mask'] as List<dynamic>).cast<int>())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyId': companyId,
      'data': data,
      'mask': mask,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManufacturerData &&
          runtimeType == other.runtimeType &&
          companyId == other.companyId &&
          _listEquals(data, other.data);

  @override
  int get hashCode => Object.hash(companyId, data);

  bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'ManufacturerData(companyId: $companyId, data: ${data.length} bytes)';
}
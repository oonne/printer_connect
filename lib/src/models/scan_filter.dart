import 'manufacturer_data.dart';

class ScanFilter {
  final List<String>? withServices;
  final List<ManufacturerData>? withManufacturerData;
  final String? withLocalName;
  final List<String>? withNamePrefix;
  final List<String>? withDeviceId;
  final List<ScanFilter>? exclusionFilters;

  const ScanFilter({
    this.withServices,
    this.withManufacturerData,
    this.withLocalName,
    this.withNamePrefix,
    this.withDeviceId,
    this.exclusionFilters,
  });

  factory ScanFilter.fromJson(Map<String, dynamic> json) {
    return ScanFilter(
      withServices: (json['withServices'] as List<dynamic>?)
          ?.cast<String>(),
      withManufacturerData: (json['withManufacturerData'] as List<dynamic>?)
          ?.map((e) => ManufacturerData.fromJson(e as Map<String, dynamic>))
          .toList(),
      withLocalName: json['withLocalName'] as String?,
      withNamePrefix: (json['withNamePrefix'] as List<dynamic>?)
          ?.cast<String>(),
      withDeviceId: (json['withDeviceId'] as List<dynamic>?)
          ?.cast<String>(),
      exclusionFilters: (json['exclusionFilters'] as List<dynamic>?)
          ?.map((e) => ScanFilter.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'withServices': withServices,
      'withManufacturerData': withManufacturerData?.map((e) => e.toJson()).toList(),
      'withLocalName': withLocalName,
      'withNamePrefix': withNamePrefix,
      'withDeviceId': withDeviceId,
      'exclusionFilters': exclusionFilters?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() =>
      'ScanFilter(withServices: ${withServices?.length ?? 0}, withManufacturerData: ${withManufacturerData?.length ?? 0}, withLocalName: $withLocalName, withNamePrefix: ${withNamePrefix?.length ?? 0}, withDeviceId: ${withDeviceId?.length ?? 0}, exclusionFilters: ${exclusionFilters?.length ?? 0})';
}

class ExclusionFilter {
  final List<String>? withServices;
  final List<String>? withNamePrefix;
  final List<ManufacturerData>? manufacturerDataFilter;

  const ExclusionFilter({
    this.withServices,
    this.withNamePrefix,
    this.manufacturerDataFilter,
  });

  factory ExclusionFilter.fromJson(Map<String, dynamic> json) {
    return ExclusionFilter(
      withServices: (json['withServices'] as List<dynamic>?)?.cast<String>(),
      withNamePrefix: (json['withNamePrefix'] as List<dynamic>?)?.cast<String>(),
      manufacturerDataFilter: (json['manufacturerDataFilter'] as List<dynamic>?)
          ?.map((e) => ManufacturerData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'withServices': withServices,
      'withNamePrefix': withNamePrefix,
      'manufacturerDataFilter': manufacturerDataFilter?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() =>
      'ExclusionFilter(withServices: ${withServices?.length ?? 0}, withNamePrefix: ${withNamePrefix?.length ?? 0}, manufacturerDataFilter: ${manufacturerDataFilter?.length ?? 0})';
}

import 'manufacturer_data.dart';

class ScanFilter {
  final List<String>? withServices;
  final List<ManufacturerData>? withManufacturerData;
  final String? withNamePrefix;
  final List<ExclusionFilter>? exclusionFilters;

  const ScanFilter({
    this.withServices,
    this.withManufacturerData,
    this.withNamePrefix,
    this.exclusionFilters,
  });

  factory ScanFilter.fromJson(Map<String, dynamic> json) {
    return ScanFilter(
      withServices: (json['withServices'] as List<dynamic>?)
          ?.cast<String>(),
      withManufacturerData: (json['withManufacturerData'] as List<dynamic>?)
          ?.map((e) => ManufacturerData.fromJson(e as Map<String, dynamic>))
          .toList(),
      withNamePrefix: json['withNamePrefix'] as String?,
      exclusionFilters: (json['exclusionFilters'] as List<dynamic>?)
          ?.map((e) => ExclusionFilter.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'withServices': withServices,
      'withManufacturerData': withManufacturerData?.map((e) => e.toJson()).toList(),
      'withNamePrefix': withNamePrefix,
      'exclusionFilters': exclusionFilters?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() =>
      'ScanFilter(withServices: $withServices, withManufacturerData: ${withManufacturerData?.length}, withNamePrefix: $withNamePrefix, exclusionFilters: ${exclusionFilters?.length})';
}

class ExclusionFilter {
  final List<String>? withServices;
  final String? withNamePrefix;

  const ExclusionFilter({
    this.withServices,
    this.withNamePrefix,
  });

  factory ExclusionFilter.fromJson(Map<String, dynamic> json) {
    return ExclusionFilter(
      withServices: (json['withServices'] as List<dynamic>?)?.cast<String>(),
      withNamePrefix: json['withNamePrefix'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'withServices': withServices,
      'withNamePrefix': withNamePrefix,
    };
  }

  @override
  String toString() =>
      'ExclusionFilter(withServices: $withServices, withNamePrefix: $withNamePrefix)';
}
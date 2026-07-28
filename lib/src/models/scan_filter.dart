import 'manufacturer_data.dart';

class ScanFilter {
  final List<String> withServices;
  final List<ManufacturerData>? withManufacturerData;
  final String? withLocalName;
  final List<String> withNamePrefix;
  final List<String>? withDeviceId;
  final List<ScanFilter>? exclusionFilters;

  const ScanFilter({
    this.withServices = const [],
    this.withManufacturerData,
    this.withLocalName,
    this.withNamePrefix = const [],
    this.withDeviceId,
    this.exclusionFilters,
  });

  bool get hasValidFilters =>
      withServices.isNotEmpty ||
      withManufacturerData != null ||
      withLocalName != null ||
      withNamePrefix.isNotEmpty ||
      withDeviceId != null ||
      exclusionFilters != null;

  @override
  String toString() =>
      'ScanFilter(withServices: ${withServices.length}, withManufacturerData: ${withManufacturerData?.length ?? 0}, withLocalName: $withLocalName, withNamePrefix: ${withNamePrefix.length}, withDeviceId: ${withDeviceId?.length ?? 0}, exclusionFilters: ${exclusionFilters?.length ?? 0})';
}

class ExclusionFilter {
  final List<String>? services;
  final List<String>? namePrefix;
  final List<ManufacturerData>? manufacturerDataFilter;

  const ExclusionFilter({
    this.services,
    this.namePrefix,
    this.manufacturerDataFilter,
  });

  @override
  String toString() =>
      'ExclusionFilter(services: ${services?.length ?? 0}, namePrefix: ${namePrefix?.length ?? 0}, manufacturerDataFilter: ${manufacturerDataFilter?.length ?? 0})';
}
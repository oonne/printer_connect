import 'package:printer_connect/src/printer_connect.g.dart';

/// 扫描过滤器配置类
///
/// 用于在扫描蓝牙设备时设置过滤条件，支持按服务 UUID、厂商数据、
/// 名称前缀等条件进行筛选，同时支持排除过滤器。
class ScanFilter {
  /// 包含指定服务 UUID 的设备
  List<String> withServices;

  /// 包含指定厂商数据的设备
  List<ManufacturerDataFilter> withManufacturerData;

  /// 名称以指定前缀开头的设备
  List<String> withNamePrefix;

  /// 排除过滤器列表（满足排除条件的设备将被过滤掉）
  List<ExclusionFilter> exclusionFilters;

  ScanFilter({
    this.withServices = const [],
    this.withManufacturerData = const [],
    this.withNamePrefix = const [],
    this.exclusionFilters = const [],
  });

  @override
  String toString() {
    return 'ScanFilter(withServices: $withServices, withManufacturerData: $withManufacturerData, withNamePrefix: $withNamePrefix, exclusionFilters: $exclusionFilters)';
  }
}

/// 排除过滤器
///
/// 定义从扫描结果中排除设备的条件，满足任一条件的设备将被过滤掉。
class ExclusionFilter {
  /// 要排除的服务 UUID 列表
  List<String> services;

  /// 要排除的厂商数据过滤器列表
  List<ManufacturerDataFilter> manufacturerDataFilter;

  /// 要排除的名称前缀
  String? namePrefix;

  ExclusionFilter({
    this.services = const [],
    this.manufacturerDataFilter = const [],
    this.namePrefix,
  });

  bool get hasValidFilters =>
      services.isNotEmpty ||
      manufacturerDataFilter.isNotEmpty ||
      (namePrefix?.isNotEmpty ?? false);
}

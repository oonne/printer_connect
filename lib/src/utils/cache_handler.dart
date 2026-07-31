import 'package:printer_connect/src/models/model_exports.dart';

/// 蓝牙设备服务缓存管理器
///
/// 管理已发现的蓝牙服务的内存缓存，避免重复发现服务时的性能开销。
class CacheHandler {
  CacheHandler._();

  static final CacheHandler instance = CacheHandler._();

  /// 内部缓存，存储每个设备已发现的服务列表
  final Map<String, List<BleService>> _servicesCache = {};

  /// 将设备 ID 转换为小写的规范化键
  ///
  /// 大小写不敏感的键控策略：不同平台上报的设备 ID 大小写不一致
  /// （如 Android 上报大写 MAC 地址），统一转为小写后作为缓存键，
  /// 确保在任一平台下保存和读取缓存都能正确匹配。
  static String _key(String deviceId) => deviceId.toLowerCase();

  /// 保存指定设备已发现的蓝牙服务到缓存
  ///
  /// 若 [services] 为 null，则清除该设备的缓存。
  void saveServices(String deviceId, List<BleService>? services) {
    if (services == null) {
      _servicesCache.remove(_key(deviceId));
    } else {
      _servicesCache[_key(deviceId)] = services;
    }
  }

  /// 获取指定设备的缓存蓝牙服务
  List<BleService>? getServices(String deviceId) => _servicesCache[_key(deviceId)];

  /// 重置指定设备的缓存，移除所有已存储的服务
  void resetDeviceCache(String deviceId) {
    _servicesCache.remove(_key(deviceId));
  }
}
import 'package:printer_connect/src/models/model_exports.dart';

class CacheHandler {
  CacheHandler._();

  static final CacheHandler instance = CacheHandler._();

  final Map<String, List<BleService>> _servicesCache = {};

  Future<void> saveServices(String deviceId, List<BleService> services) async {
    _servicesCache[deviceId.toLowerCase()] = List.unmodifiable(services);
  }

  List<BleService>? getServices(String deviceId) {
    return _servicesCache[deviceId.toLowerCase()];
  }

  void resetDeviceCache(String deviceId) {
    _servicesCache.remove(deviceId.toLowerCase());
  }

  void resetAllCache() {
    _servicesCache.clear();
  }

  bool hasCachedServices(String deviceId) {
    return _servicesCache.containsKey(deviceId.toLowerCase());
  }
}

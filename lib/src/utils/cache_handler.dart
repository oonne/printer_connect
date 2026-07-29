import 'package:printer_connect/src/models/model_exports.dart';

class CacheHandler {
  CacheHandler._();

  static final CacheHandler instance = CacheHandler._();

  final Map<String, List<BleService>> _servicesCache = {};

  void saveServices(String deviceId, List<BleService> services) {
    _servicesCache[deviceId.toLowerCase()] = List.unmodifiable(services);
  }

  List<BleService>? getServices(String deviceId) {
    return _servicesCache[deviceId.toLowerCase()];
  }

  void resetDeviceCache(String deviceId) {
    _servicesCache.remove(deviceId.toLowerCase());
  }

  
}

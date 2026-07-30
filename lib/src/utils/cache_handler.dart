import 'package:printer_connect/src/models/model_exports.dart';

/// Manages an in-memory cache for Bluetooth devices
class CacheHandler {
  CacheHandler._();

  static final CacheHandler instance = CacheHandler._();

  /// Internal cache to store discovered services for each device.
  final Map<String, List<BleService>> _servicesCache = {};

  // A device id is a case-insensitive identifier reported in different cases by different platforms (Android
  // upper-cases MACs). Key the cache by a canonical lower-case id so services saved
  // when subscribing with one case are still found/cleared when the platform reports another.
  static String _key(String deviceId) => deviceId.toLowerCase();

  /// Saves the discovered Bluetooth services for a specific device in the cache.
  void saveServices(String deviceId, List<BleService>? services) {
    if (services == null) {
      _servicesCache.remove(_key(deviceId));
    } else {
      _servicesCache[_key(deviceId)] = services;
    }
  }

  /// Retrieves the cached Bluetooth services for a specific device.
  List<BleService>? getServices(String deviceId) => _servicesCache[_key(deviceId)];

  /// Resets the cache for a specific device, removing all stored services.
  void resetDeviceCache(String deviceId) {
    _servicesCache.remove(_key(deviceId));
  }
}

import 'dart:developer' as developer;

class BleUuidParser {
  static const String _baseSuffix = '-0000-1000-8000-00805F9B34FB';

  static String string(String uuid) {
    if (uuid.isEmpty) {
      throw ArgumentError('UUID cannot be empty');
    }

    final trimmed = uuid.trim().toUpperCase();

    if (trimmed.length == 36 && trimmed.contains('-')) {
      if (_isValid128BitUuid(trimmed)) {
        return trimmed;
      }
      throw ArgumentError('Invalid 128-bit UUID format: $uuid');
    }

    if (trimmed.length == 4) {
      if (_isValid16BitUuid(trimmed)) {
        return '0000$trimmed$_baseSuffix';
      }
      throw ArgumentError('Invalid 16-bit UUID format: $uuid');
    }

    if (trimmed.length == 8) {
      if (_isValid32BitUuid(trimmed)) {
        return '${trimmed.substring(0, 4)}${trimmed.substring(4)}$_baseSuffix';
      }
      throw ArgumentError('Invalid 32-bit UUID format: $uuid');
    }

    throw ArgumentError('Unsupported UUID format: $uuid. Expected 4, 8, or 32 characters.');
  }

  static String? stringOrNull(String uuid) {
    if (uuid.isEmpty) {
      return null;
    }
    try {
      return string(uuid);
    } catch (e) {
      developer.log('Invalid UUID: $uuid', name: 'BleUuidParser');
      return null;
    }
  }

  static String number(int short) {
    if (short < 0 || short > 0xFFFF) {
      throw ArgumentError('16-bit UUID number must be between 0 and 0xFFFF, got: $short');
    }
    final hex = short.toRadixString(16).padLeft(4, '0').toUpperCase();
    return '0000$hex$_baseSuffix';
  }

  static bool compareStrings(String uuid1, String uuid2) {
    try {
      final normalized1 = string(uuid1);
      final normalized2 = string(uuid2);
      return normalized1 == normalized2;
    } catch (e) {
      developer.log('Error comparing UUIDs: $uuid1 vs $uuid2', name: 'BleUuidParser');
      return false;
    }
  }

  static bool _isValid128BitUuid(String uuid) {
    final regex = RegExp(
      r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',
    );
    return regex.hasMatch(uuid);
  }

  static bool _isValid16BitUuid(String uuid) {
    final regex = RegExp(r'^[0-9A-Fa-f]{4}$');
    return regex.hasMatch(uuid);
  }

  static bool _isValid32BitUuid(String uuid) {
    final regex = RegExp(r'^[0-9A-Fa-f]{8}$');
    return regex.hasMatch(uuid);
  }
}

extension StringListToUUID on List<String> {
  List<String> toUUIDList() {
    return map((uuid) {
      try {
        return BleUuidParser.string(uuid);
      } catch (e) {
        developer.log('Invalid UUID in list: $uuid', name: 'StringListToUUID');
        return uuid;
      }
    }).toList();
  }
}
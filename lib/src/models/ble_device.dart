import 'package:flutter/foundation.dart';
import 'package:printer_connect/printer_connect.dart';

class BleDevice {
  final String deviceId;
  final String? name;
  final String? rawName;
  final int? rssi;
  final bool? paired;
  final List<String> services;
  final bool? isSystemDevice;
  final List<ManufacturerData> manufacturerDataList;
  final Map<String, Uint8List> serviceData;
  final int? timestamp;

  BleDevice({
    required this.deviceId,
    required String? name,
    this.rssi,
    this.paired,
    this.services = const [],
    this.isSystemDevice,
    this.manufacturerDataList = const [],
    Map<String, Uint8List>? serviceData,
    this.timestamp,
  })  : rawName = name,
        name = name?.replaceAll(RegExp(r'[^ -~]'), '').trim(),
        serviceData = _validateServiceData(serviceData ?? const {});

  static Map<String, Uint8List> _validateServiceData(
      Map<String, Uint8List> data) {
    return data.map((key, value) {
      try {
        return MapEntry(BleUuidParser.string(key), value);
      } catch (_) {
        return MapEntry(key, value);
      }
    });
  }

  @Deprecated('Use manufacturerDataList instead')
  Uint8List? get manufacturerData {
    if (manufacturerDataList.isEmpty) return null;
    return manufacturerDataList.first.toUint8List();
  }

  Future<BleConnectionState> get connectionState async {
    return PrinterConnect.getConnectionState(deviceId);
  }

  Future<int?> get readRssi async {
    return PrinterConnect.readRssi(deviceId);
  }

  bool get receivesAdvertisements =>
      PrinterConnect.receivesAdvertisements(deviceId);

  DateTime? get timestampDateTime {
    final ts = timestamp;
    if (ts == null || ts == 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          name == other.name &&
          rawName == other.rawName &&
          rssi == other.rssi &&
          paired == other.paired &&
          _listEquals(services, other.services) &&
          isSystemDevice == other.isSystemDevice &&
          _listEquals(manufacturerDataList, other.manufacturerDataList) &&
          _mapEquals(serviceData, other.serviceData) &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        deviceId,
        name,
        rawName,
        rssi,
        paired,
        services,
        isSystemDevice,
        manufacturerDataList,
        serviceData,
        timestamp,
      );

  bool _listEquals(List a, List b) {
    return listEquals(a, b);
  }

  bool _mapEquals(Map<String, Uint8List> a, Map<String, Uint8List> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final va = a[key]!;
      final vb = b[key]!;
      if (va.length != vb.length) return false;
      for (int i = 0; i < va.length; i++) {
        if (va[i] != vb[i]) return false;
      }
    }
    return true;
  }

  @override
  String toString() =>
      'BleDevice(deviceId: $deviceId, name: $name, rssi: $rssi, paired: $paired, services: ${services.length}, isSystemDevice: $isSystemDevice, manufacturerDataList: ${manufacturerDataList.length}, serviceData: ${serviceData.length}, timestamp: $timestamp)';
}
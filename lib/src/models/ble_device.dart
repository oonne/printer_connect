import 'package:flutter/foundation.dart';
import 'package:printer_connect/printer_connect.dart';

import 'manufacturer_data.dart';

class BleDevice {
  final String deviceId;
  final String name;
  final String rawName;
  final int? rssi;
  final bool paired;
  final List<String> services;
  final bool isSystemDevice;
  final List<ManufacturerData> manufacturerDataList;
  final Map<String, Uint8List> serviceData;
  final int timestamp;

  const BleDevice({
    required this.deviceId,
    required this.name,
    this.rssi,
    this.paired = false,
    this.services = const [],
    this.isSystemDevice = false,
    this.manufacturerDataList = const [],
    this.serviceData = const {},
    this.timestamp = 0,
  }) : rawName = name;

  @Deprecated('Use manufacturerDataList instead')
  ManufacturerData? get manufacturerData {
    if (manufacturerDataList.isEmpty) return null;
    return manufacturerDataList.first;
  }

  Future<BleConnectionState> get connectionState async {
    return PrinterConnect.getConnectionState(deviceId);
  }

  Future<int?> get readRssi async {
    return PrinterConnect.readRssi(deviceId);
  }

  bool get receivesAdvertisements => timestamp > 0;

  DateTime get timestampDateTime {
    if (timestamp == 0) {
      return DateTime.now();
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  factory BleDevice.fromJson(Map<String, dynamic> json) {
    return BleDevice(
      deviceId: json['deviceId'] as String,
      name: json['name'] as String? ?? '',
      rssi: json['rssi'] as int?,
      paired: json['paired'] as bool? ?? false,
      services: (json['services'] as List<dynamic>?)?.cast<String>() ?? const [],
      isSystemDevice: json['isSystemDevice'] as bool? ?? false,
      manufacturerDataList: (json['manufacturerDataList'] as List<dynamic>?)
              ?.map((e) => ManufacturerData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      serviceData: (json['serviceData'] as Map<dynamic, dynamic>?)?.map(
            (key, value) => MapEntry(
              key as String,
              Uint8List.fromList((value as List<dynamic>).cast<int>()),
            ),
          ) ??
          const {},
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'name': name,
      'rawName': rawName,
      'rssi': rssi,
      'paired': paired,
      'services': services,
      'isSystemDevice': isSystemDevice,
      'manufacturerDataList': manufacturerDataList.map((e) => e.toJson()).toList(),
      'serviceData': serviceData.map(
        (key, value) => MapEntry(key, value),
      ),
      'timestamp': timestamp,
    };
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
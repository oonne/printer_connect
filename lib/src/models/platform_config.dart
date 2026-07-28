import 'dart:typed_data';

import 'package:printer_connect/src/printer_connect.g.dart' show AndroidScanCallbackType;

import 'manufacturer_data.dart';

class PlatformConfig {
  final WebOptions? web;
  final AndroidOptions? android;

  const PlatformConfig({
    this.web,
    this.android,
  });

  factory PlatformConfig.fromJson(Map<String, dynamic> json) {
    return PlatformConfig(
      web: json['web'] != null
          ? WebOptions.fromJson(json['web'] as Map<String, dynamic>)
          : null,
      android: json['android'] != null
          ? AndroidOptions.fromJson(json['android'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'web': web?.toJson(),
      'android': android?.toJson(),
    };
  }

  @override
  String toString() => 'PlatformConfig(web: $web, android: $android)';
}

class WebOptions {
  final List<String>? optionalServices;
  final List<ManufacturerData>? optionalManufacturerData;

  const WebOptions({
    this.optionalServices,
    this.optionalManufacturerData,
  });

  factory WebOptions.fromJson(Map<String, dynamic> json) {
    return WebOptions(
      optionalServices: (json['optionalServices'] as List<dynamic>?)
          ?.cast<String>(),
      optionalManufacturerData: (json['optionalManufacturerData'] as List<dynamic>?)
          ?.map((e) => ManufacturerData.fromData(
                e['companyId'] as int,
                e['data'] as Uint8List,
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'optionalServices': optionalServices,
      'optionalManufacturerData':
          optionalManufacturerData?.map((e) => e.toUniversalManufacturerData()).toList(),
    };
  }

  @override
  String toString() =>
      'WebOptions(optionalServices: ${optionalServices?.length ?? 0}, optionalManufacturerData: ${optionalManufacturerData?.length ?? 0})';
}

class AndroidOptions {
  final bool requestLocationPermission;
  final int scanMode;
  final int reportDelayMillis;
  final List<AndroidScanCallbackType>? callbackType;
  final int matchMode;
  final int numOfMatches;
  final bool legacy;

  const AndroidOptions({
    this.requestLocationPermission = true,
    this.scanMode = 0,
    this.reportDelayMillis = 0,
    this.callbackType,
    this.matchMode = 0,
    this.numOfMatches = 0,
    this.legacy = false,
  });

  factory AndroidOptions.fromJson(Map<String, dynamic> json) {
    return AndroidOptions(
      requestLocationPermission:
          json['requestLocationPermission'] as bool? ?? true,
      scanMode: json['scanMode'] as int? ?? 0,
      reportDelayMillis: json['reportDelayMillis'] as int? ?? 0,
      callbackType: (json['callbackType'] as List<dynamic>?)
          ?.map((e) => AndroidScanCallbackType.values[e as int])
          .toList(),
      matchMode: json['matchMode'] as int? ?? 0,
      numOfMatches: json['numOfMatches'] as int? ?? 0,
      legacy: json['legacy'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestLocationPermission': requestLocationPermission,
      'scanMode': scanMode,
      'reportDelayMillis': reportDelayMillis,
      'callbackType': callbackType?.map((e) => e.index).toList(),
      'matchMode': matchMode,
      'numOfMatches': numOfMatches,
      'legacy': legacy,
    };
  }

  AndroidOptions copyWith({
    bool? requestLocationPermission,
    int? scanMode,
    int? reportDelayMillis,
    List<AndroidScanCallbackType>? callbackType,
    int? matchMode,
    int? numOfMatches,
    bool? legacy,
  }) {
    return AndroidOptions(
      requestLocationPermission:
          requestLocationPermission ?? this.requestLocationPermission,
      scanMode: scanMode ?? this.scanMode,
      reportDelayMillis: reportDelayMillis ?? this.reportDelayMillis,
      callbackType: callbackType ?? this.callbackType,
      matchMode: matchMode ?? this.matchMode,
      numOfMatches: numOfMatches ?? this.numOfMatches,
      legacy: legacy ?? this.legacy,
    );
  }

  @override
  String toString() =>
      'AndroidOptions(requestLocationPermission: $requestLocationPermission, scanMode: $scanMode, reportDelayMillis: $reportDelayMillis, callbackType: ${callbackType?.length ?? 0}, matchMode: $matchMode, numOfMatches: $numOfMatches, legacy: $legacy)';
}

class AppleConnectionOptions {
  final bool enableAutoReceiveData;
  final int receiveDataTimeout;
  final bool notifyOnConnection;
  final bool notifyOnDisconnection;
  final bool notifyOnNotification;

  const AppleConnectionOptions({
    this.enableAutoReceiveData = true,
    this.receiveDataTimeout = 0,
    this.notifyOnConnection = true,
    this.notifyOnDisconnection = true,
    this.notifyOnNotification = false,
  });

  factory AppleConnectionOptions.fromJson(Map<String, dynamic> json) {
    return AppleConnectionOptions(
      enableAutoReceiveData:
          json['enableAutoReceiveData'] as bool? ?? true,
      receiveDataTimeout: json['receiveDataTimeout'] as int? ?? 0,
      notifyOnConnection: json['notifyOnConnection'] as bool? ?? true,
      notifyOnDisconnection: json['notifyOnDisconnection'] as bool? ?? true,
      notifyOnNotification: json['notifyOnNotification'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableAutoReceiveData': enableAutoReceiveData,
      'receiveDataTimeout': receiveDataTimeout,
      'notifyOnConnection': notifyOnConnection,
      'notifyOnDisconnection': notifyOnDisconnection,
      'notifyOnNotification': notifyOnNotification,
    };
  }

  @override
  String toString() =>
      'AppleConnectionOptions(enableAutoReceiveData: $enableAutoReceiveData, receiveDataTimeout: $receiveDataTimeout, notifyOnConnection: $notifyOnConnection, notifyOnDisconnection: $notifyOnDisconnection, notifyOnNotification: $notifyOnNotification)';
}

class ConnectionPlatformConfig {
  final AppleConnectionOptions? apple;

  const ConnectionPlatformConfig({
    this.apple,
  });

  factory ConnectionPlatformConfig.fromJson(Map<String, dynamic> json) {
    return ConnectionPlatformConfig(
      apple: json['apple'] != null
          ? AppleConnectionOptions.fromJson(
              json['apple'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apple': apple?.toJson(),
    };
  }

  @override
  String toString() => 'ConnectionPlatformConfig(apple: $apple)';
}
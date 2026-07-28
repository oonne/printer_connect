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
  final bool useBle;

  const WebOptions({
    this.useBle = true,
  });

  factory WebOptions.fromJson(Map<String, dynamic> json) {
    return WebOptions(
      useBle: json['useBle'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'useBle': useBle,
    };
  }

  @override
  String toString() => 'WebOptions(useBle: $useBle)';
}

class AndroidOptions {
  final bool requestLocationPermission;
  final int scanMode;
  final int reportDelayMillis;
  final int callbackType;
  final int matchMode;
  final int numOfMatches;
  final bool legacy;

  const AndroidOptions({
    this.requestLocationPermission = true,
    this.scanMode = 0,
    this.reportDelayMillis = 0,
    this.callbackType = 0,
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
      callbackType: json['callbackType'] as int? ?? 0,
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
      'callbackType': callbackType,
      'matchMode': matchMode,
      'numOfMatches': numOfMatches,
      'legacy': legacy,
    };
  }

  AndroidOptions copyWith({
    bool? requestLocationPermission,
    int? scanMode,
    int? reportDelayMillis,
    int? callbackType,
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
      'AndroidOptions(requestLocationPermission: $requestLocationPermission, scanMode: $scanMode, reportDelayMillis: $reportDelayMillis, callbackType: $callbackType, matchMode: $matchMode, numOfMatches: $numOfMatches, legacy: $legacy)';
}

class AppleConnectionOptions {
  final bool enableAutoReceiveData;
  final int receiveDataTimeout;

  const AppleConnectionOptions({
    this.enableAutoReceiveData = true,
    this.receiveDataTimeout = 0,
  });

  factory AppleConnectionOptions.fromJson(Map<String, dynamic> json) {
    return AppleConnectionOptions(
      enableAutoReceiveData:
          json['enableAutoReceiveData'] as bool? ?? true,
      receiveDataTimeout: json['receiveDataTimeout'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableAutoReceiveData': enableAutoReceiveData,
      'receiveDataTimeout': receiveDataTimeout,
    };
  }

  @override
  String toString() =>
      'AppleConnectionOptions(enableAutoReceiveData: $enableAutoReceiveData, receiveDataTimeout: $receiveDataTimeout)';
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
import 'package:flutter/foundation.dart';

class BleCapabilities {
  final bool supportsBluetooth;
  final bool supportsLE;
  final bool supportsScan;
  final bool supportsConnect;
  final bool supportsWrite;
  final bool supportsRead;
  final bool supportsNotify;
  final bool supportsIndicate;
  final bool supportsSecureConnections;
  final bool supportsExtendedAdvertising;
  final bool supportsPeriodicAdvertising;
  final bool supportsLE2M;
  final bool supportsCodedPHY;
  final bool supportsIOS17;
  final bool supportsAndroidV31;

  const BleCapabilities({
    this.supportsBluetooth = false,
    this.supportsLE = false,
    this.supportsScan = false,
    this.supportsConnect = false,
    this.supportsWrite = false,
    this.supportsRead = false,
    this.supportsNotify = false,
    this.supportsIndicate = false,
    this.supportsSecureConnections = false,
    this.supportsExtendedAdvertising = false,
    this.supportsPeriodicAdvertising = false,
    this.supportsLE2M = false,
    this.supportsCodedPHY = false,
    this.supportsIOS17 = false,
    this.supportsAndroidV31 = false,
  });

  factory BleCapabilities.fromJson(Map<String, dynamic> json) {
    return BleCapabilities(
      supportsBluetooth: json['supportsBluetooth'] as bool? ?? false,
      supportsLE: json['supportsLE'] as bool? ?? false,
      supportsScan: json['supportsScan'] as bool? ?? false,
      supportsConnect: json['supportsConnect'] as bool? ?? false,
      supportsWrite: json['supportsWrite'] as bool? ?? false,
      supportsRead: json['supportsRead'] as bool? ?? false,
      supportsNotify: json['supportsNotify'] as bool? ?? false,
      supportsIndicate: json['supportsIndicate'] as bool? ?? false,
      supportsSecureConnections: json['supportsSecureConnections'] as bool? ?? false,
      supportsExtendedAdvertising: json['supportsExtendedAdvertising'] as bool? ?? false,
      supportsPeriodicAdvertising: json['supportsPeriodicAdvertising'] as bool? ?? false,
      supportsLE2M: json['supportsLE2M'] as bool? ?? false,
      supportsCodedPHY: json['supportsCodedPHY'] as bool? ?? false,
      supportsIOS17: json['supportsIOS17'] as bool? ?? false,
      supportsAndroidV31: json['supportsAndroidV31'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supportsBluetooth': supportsBluetooth,
      'supportsLE': supportsLE,
      'supportsScan': supportsScan,
      'supportsConnect': supportsConnect,
      'supportsWrite': supportsWrite,
      'supportsRead': supportsRead,
      'supportsNotify': supportsNotify,
      'supportsIndicate': supportsIndicate,
      'supportsSecureConnections': supportsSecureConnections,
      'supportsExtendedAdvertising': supportsExtendedAdvertising,
      'supportsPeriodicAdvertising': supportsPeriodicAdvertising,
      'supportsLE2M': supportsLE2M,
      'supportsCodedPHY': supportsCodedPHY,
      'supportsIOS17': supportsIOS17,
      'supportsAndroidV31': supportsAndroidV31,
    };
  }

  bool get canScan => supportsScan && supportsLE;
  bool get canConnect => supportsConnect && supportsLE;
  bool get canWriteCharacteristic => supportsWrite;
  bool get canReadCharacteristic => supportsRead;
  bool get canNotify => supportsNotify;
  bool get canIndicate => supportsIndicate;
  bool get supportsAutoReconnect => supportsIOS17;
  bool get supportsBonded => supportsAndroidV31;

  factory BleCapabilities.detect() {
    if (kIsWeb) {
      return const BleCapabilities(
        supportsBluetooth: true,
        supportsLE: true,
        supportsScan: true,
        supportsConnect: true,
        supportsWrite: true,
        supportsRead: true,
        supportsNotify: true,
        supportsIndicate: true,
        supportsSecureConnections: false,
        supportsExtendedAdvertising: false,
        supportsPeriodicAdvertising: false,
        supportsLE2M: false,
        supportsCodedPHY: false,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const BleCapabilities(
          supportsBluetooth: true,
          supportsLE: true,
          supportsScan: true,
          supportsConnect: true,
          supportsWrite: true,
          supportsRead: true,
          supportsNotify: true,
          supportsIndicate: true,
          supportsSecureConnections: true,
          supportsExtendedAdvertising: true,
          supportsPeriodicAdvertising: false,
          supportsLE2M: false,
          supportsCodedPHY: false,
          supportsAndroidV31: true,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BleCapabilities(
          supportsBluetooth: true,
          supportsLE: true,
          supportsScan: true,
          supportsConnect: true,
          supportsWrite: true,
          supportsRead: true,
          supportsNotify: true,
          supportsIndicate: true,
          supportsSecureConnections: true,
          supportsExtendedAdvertising: false,
          supportsPeriodicAdvertising: false,
          supportsLE2M: false,
          supportsCodedPHY: false,
          supportsIOS17: true,
        );
      case TargetPlatform.linux:
        return const BleCapabilities(
          supportsBluetooth: true,
          supportsLE: true,
          supportsScan: true,
          supportsConnect: true,
          supportsWrite: true,
          supportsRead: true,
          supportsNotify: true,
          supportsIndicate: true,
          supportsSecureConnections: false,
          supportsExtendedAdvertising: false,
          supportsPeriodicAdvertising: false,
          supportsLE2M: false,
          supportsCodedPHY: false,
        );
      case TargetPlatform.windows:
        return const BleCapabilities(
          supportsBluetooth: true,
          supportsLE: true,
          supportsScan: true,
          supportsConnect: true,
          supportsWrite: true,
          supportsRead: true,
          supportsNotify: true,
          supportsIndicate: true,
          supportsSecureConnections: false,
          supportsExtendedAdvertising: false,
          supportsPeriodicAdvertising: false,
          supportsLE2M: false,
          supportsCodedPHY: false,
        );
      case TargetPlatform.fuchsia:
        return const BleCapabilities(
          supportsBluetooth: false,
          supportsLE: false,
          supportsScan: false,
          supportsConnect: false,
          supportsWrite: false,
          supportsRead: false,
          supportsNotify: false,
          supportsIndicate: false,
          supportsSecureConnections: false,
          supportsExtendedAdvertising: false,
          supportsPeriodicAdvertising: false,
          supportsLE2M: false,
          supportsCodedPHY: false,
        );
    }
  }

  @override
  String toString() =>
      'BleCapabilities(Bluetooth: $supportsBluetooth, LE: $supportsLE, Scan: $supportsScan, Connect: $supportsConnect, Write: $supportsWrite, Read: $supportsRead, Notify: $supportsNotify, Indicate: $supportsIndicate)';
}
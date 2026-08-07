import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_connect/src/printer_connect.g.dart'
    show ConnectionPlatformConfig;
import 'package:printer_connect/printer_connect.dart';

import 'printer_connect_test_mock.dart';

class _TestableMock extends PrinterConnectPlatformMock {
  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    return AvailabilityState.poweredOn;
  }

  @override
  Future<bool> enableBluetooth() async => true;

  @override
  Future<bool> hasPermissions({bool withAndroidFineLocation = false}) async =>
      true;

  @override
  Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {}

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<bool> isScanning() async => false;

  @override
  Future<void> connect(
    String deviceId, {
    bool autoConnect = false,
    Duration? connectionTimeout,
    ConnectionPlatformConfig? platformConfig,
  }) async {}

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors,
  ) async => [];

  @override
  Future<void> setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty,
  ) async {}

  @override
  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
  }) async => Uint8List(0);

  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {}

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async => expectedMtu;

  @override
  Future<int> readRssi(String deviceId) async => 0;

  @override
  Future<void> requestConnectionPriority(
    String deviceId,
    BleConnectionPriority priority,
  ) async {}

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async =>
      BleConnectionState.disconnected;

  @override
  Future<List<BleDevice>> getSystemDevices(List<String>? withServices) async =>
      [];

  @override
  Future<void> setLogLevel(BleLogLevel logLevel) async {}

  @override
  bool receivesAdvertisements(String deviceId) => false;
}

/// 模拟无权限的 mock
class _NoPermissionMock extends _TestableMock {
  bool _granted = false;

  @override
  Future<bool> hasPermissions({bool withAndroidFineLocation = false}) async =>
      _granted;

  @override
  Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {
    _granted = true;
  }
}

/// 模拟权限请求失败的 mock（用户拒绝）
class _PermissionDeniedMock extends _TestableMock {
  @override
  Future<bool> hasPermissions({bool withAndroidFineLocation = false}) async =>
      false;

  @override
  Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {
    throw Exception('Permission denied by user');
  }
}

/// 模拟蓝牙关闭的 mock（Android 场景，支持开启蓝牙）
class _BluetoothOffAndroidMock extends _TestableMock {
  bool _enabled = false;

  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    return _enabled ? AvailabilityState.poweredOn : AvailabilityState.poweredOff;
  }

  @override
  Future<bool> enableBluetooth() async {
    _enabled = true;
    return true;
  }
}

/// 模拟蓝牙关闭但用户拒绝开启的 mock
class _BluetoothEnableDeniedMock extends _TestableMock {
  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    return AvailabilityState.poweredOff;
  }

  @override
  Future<bool> enableBluetooth() async => false;
}

/// 模拟权限请求后仍未授予的 mock
class _PermissionStillDeniedMock extends _TestableMock {
  @override
  Future<bool> hasPermissions({bool withAndroidFineLocation = false}) async =>
      false;

  @override
  Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {
    // 请求后仍未授权
  }
}

/// 模拟 iOS 蓝牙关闭的 mock
/// 由于 BleCapabilities.supportsBluetoothEnableApi 在测试中无法动态切换，
/// 通过让 enableBluetooth 抛出来模拟 iOS 上"不支持开启蓝牙"的行为
class _BluetoothOffIosMock extends _TestableMock {
  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async {
    return AvailabilityState.poweredOff;
  }

  @override
  Future<bool> enableBluetooth() async {
    throw UnsupportedError('enableBluetooth is not supported on this platform');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default instance is PigeonPrinterConnectPlatform', () {
    final platform = PrinterConnectPlatform.instance;
    expect(platform, isInstanceOf<PigeonPrinterConnectPlatform>());
  });

  test('getBluetoothAvailabilityState', () async {
    _TestableMock fakePlatform = _TestableMock();
    PrinterConnectPlatform.instance = fakePlatform;

    expect(
      await PrinterConnect.getBluetoothAvailabilityState(),
      AvailabilityState.poweredOn,
    );
  });

  test('hasPermissions', () async {
    _TestableMock fakePlatform = _TestableMock();
    PrinterConnectPlatform.instance = fakePlatform;

    expect(await PrinterConnect.hasPermissions(), true);
  });

  test('isScanning', () async {
    _TestableMock fakePlatform = _TestableMock();
    PrinterConnectPlatform.instance = fakePlatform;

    expect(await PrinterConnect.isScanning(), false);
  });

  group('startScan pre-condition checks', () {
    test('自动请求权限（首次无权限）', () async {
      final mock = _NoPermissionMock();
      PrinterConnect.setInstance(mock);

      // 首次无权限，调用后自动请求成功
      await PrinterConnect.startScan();
      expect(mock._granted, true);
    });

    test('权限请求失败时抛出异常', () async {
      final mock = _PermissionDeniedMock();
      PrinterConnect.setInstance(mock);

      expect(
        () async => await PrinterConnect.startScan(),
        throwsA(predicate((e) =>
            e is PrinterConnectException && e.code == 'permission_request_failed')),
      );
    });

    test('权限请求后仍未授予时抛出异常', () async {
      final mock = _PermissionStillDeniedMock();
      PrinterConnect.setInstance(mock);

      expect(
        () async => await PrinterConnect.startScan(),
        throwsA(predicate((e) =>
            e is PrinterConnectException && e.code == 'permissions_not_granted')),
      );
    });

    test('Android 蓝牙关闭时自动开启', () async {
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final mock = _BluetoothOffAndroidMock();
        PrinterConnect.setInstance(mock);

        await PrinterConnect.startScan();
        // 蓝牙已被自动开启
        expect(await mock.getBluetoothAvailabilityState(), AvailabilityState.poweredOn);
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    });

    test('Android 蓝牙开启被拒绝时抛出异常', () async {
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final mock = _BluetoothEnableDeniedMock();
        PrinterConnect.setInstance(mock);

        expect(
          () async => await PrinterConnect.startScan(),
          throwsA(predicate((e) =>
              e is PrinterConnectException && e.code == 'bluetooth_not_enabled')),
        );
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    });

    test('iOS 蓝牙关闭时抛出异常', () async {
      final mock = _BluetoothOffIosMock();
      PrinterConnect.setInstance(mock);

      expect(
        () async => await PrinterConnect.startScan(),
        throwsA(isUnsupportedError),
      );
    });
  });

  group('connect pre-condition checks', () {
    test('connect 自动请求权限（首次无权限）', () async {
      final mock = _NoPermissionMock();
      PrinterConnect.setInstance(mock);

      // connect 前置检查会先请求权限，然后尝试连接
      try {
        await PrinterConnect.connect('test-device').timeout(
              const Duration(milliseconds: 50),
            );
      } on TimeoutException catch (_) {
        // 超时是预期的，因为 mock 没有推送连接事件
      }
      expect(mock._granted, true);
    });

    test('connect 权限请求失败时抛出异常', () async {
      final mock = _PermissionDeniedMock();
      PrinterConnect.setInstance(mock);

      expect(
        () async => await PrinterConnect.connect('test-device'),
        throwsA(predicate((e) =>
            e is PrinterConnectException && e.code == 'permission_request_failed')),
      );
    });

    test('Android connect 蓝牙关闭时自动开启', () async {
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final mock = _BluetoothOffAndroidMock();
        PrinterConnect.setInstance(mock);

        try {
          await PrinterConnect.connect('test-device').timeout(
                const Duration(milliseconds: 50),
              );
        } on TimeoutException catch (_) {
          // 连接超时是预期的
        }
        expect(mock._enabled, true);
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    });

    test('iOS connect 蓝牙关闭时抛出异常', () async {
      final mock = _BluetoothOffIosMock();
      PrinterConnect.setInstance(mock);

      expect(
        () async => await PrinterConnect.connect('test-device'),
        throwsA(isUnsupportedError),
      );
    });
  });
}

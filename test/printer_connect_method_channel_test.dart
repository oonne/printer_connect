import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printer_connect/src/printer_connect.g.dart'
    show ConnectionPlatformConfig;
import 'package:printer_connect/printer_connect.dart';

import 'printer_connect_test_mock.dart';

class _FullMock extends PrinterConnectPlatformMock {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PigeonPrinterConnectPlatform', () {
    test('is the default instance', () {
      expect(
        PrinterConnectPlatform.instance,
        isInstanceOf<PigeonPrinterConnectPlatform>(),
      );
    });

    test('can be replaced with a mock', () {
      final mockPlatform = _FullMock();
      PrinterConnectPlatform.instance = mockPlatform;

      expect(PrinterConnectPlatform.instance, isInstanceOf<_FullMock>());
    });
  });

  group('PrinterConnect static methods', () {
    late _FullMock mockPlatform;

    setUp(() {
      mockPlatform = _FullMock();
      PrinterConnectPlatform.instance = mockPlatform;
    });

    test('getBluetoothAvailabilityState', () async {
      final result = await PrinterConnect.getBluetoothAvailabilityState();
      expect(result, AvailabilityState.poweredOn);
    });

    test('enableBluetooth', () async {
      final result = await PrinterConnect.enableBluetooth();
      expect(result, true);
    });

    test('hasPermissions', () async {
      final result = await PrinterConnect.hasPermissions();
      expect(result, true);
    });

    test('isScanning', () async {
      final result = await PrinterConnect.isScanning();
      expect(result, false);
    });

    test('getConnectionState', () async {
      final result = await PrinterConnect.getConnectionState('test-device');
      expect(result, BleConnectionState.disconnected);
    });

    test('setLogLevel', () async {
      expect(() async {
        await PrinterConnect.setLogLevel(BleLogLevel.info);
      }, returnsNormally);
    });

    test('startScan / stopScan returns normally', () async {
      expect(() async {
        await PrinterConnect.startScan();
        await PrinterConnect.stopScan();
      }, returnsNormally);
    });

    test('discoverServices returns empty list', () async {
      final result = await PrinterConnect.discoverServices('test-device');
      expect(result, isEmpty);
    });

    test('requestMtu returns expected value', () async {
      final result = await PrinterConnect.requestMtu('test-device', 512);
      expect(result, 512);
    });

    test('readRssi returns 0', () async {
      final result = await PrinterConnect.readRssi('test-device');
      expect(result, 0);
    });

    test('read returns empty list', () async {
      final result = await PrinterConnect.read('test-device', '180a', '2a00');
      expect(result, Uint8List(0));
    });

    test('write returns normally', () async {
      expect(() async {
        await PrinterConnect.write(
          'test-device',
          '180a',
          '2a00',
          Uint8List.fromList([1, 2]),
        );
      }, returnsNormally);
    });

    test('subscribeNotifications / unsubscribe returns normally', () async {
      expect(() async {
        await PrinterConnect.subscribeNotifications(
          'test-device',
          '180a',
          '2a00',
        );
        await PrinterConnect.unsubscribe('test-device', '180a', '2a00');
      }, returnsNormally);
    });

    test('subscribeIndications returns normally', () async {
      expect(() async {
        await PrinterConnect.subscribeIndications(
          'test-device',
          '180a',
          '2a00',
        );
      }, returnsNormally);
    });

    test('requestConnectionPriority returns normally', () async {
      expect(() async {
        await PrinterConnect.requestConnectionPriority(
          'test-device',
          BleConnectionPriority.highPerformance,
        );
      }, returnsNormally);
    });

    test('getSystemDevices returns empty', () async {
      final result = await PrinterConnect.getSystemDevices();
      expect(result, isEmpty);
    });

    test('requestPermissions returns normally', () async {
      expect(() async {
        await PrinterConnect.requestPermissions();
      }, returnsNormally);
    });
  });

  // 回归测试：PigeonPrinterConnectPlatform 必须把原生返回值透传给调用方。
  // 修复前 enableBluetooth 丢弃原生返回值并恒为 true，
  // 导致用户拒绝开启蓝牙时仍得到 true。
  group('enableBluetooth propagates platform result', () {
    test('PigeonPrinterConnectPlatform forwards native bool (false)', () async {
      // supportsBluetoothEnableApi 在 iOS/macOS 上为 false 会直接抛异常，
      // 这里覆盖为 Android 以走通 PigeonPrinterConnectPlatform 的逻辑。
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final platform = PigeonPrinterConnectPlatform();
        // 通过测试绑定的 defaultBinaryMessenger 注册 Pigeon 通道的 mock 响应。
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const codec = UniversalBlePlatformChannel.pigeonChannelCodec;

        // Pigeon 成功响应格式为 [result]；返回 false 表示“未开启”。
        Future<ByteData?> replyFalse(ByteData? message) async =>
            codec.encodeMessage(<Object?>[false]);

        const enableChannel =
            'dev.flutter.pigeon.printer_connect.UniversalBlePlatformChannel.enableBluetooth';

        messenger.setMockMessageHandler(enableChannel, replyFalse);

        // 修复前：恒为 true（丢弃原生返回值）；修复后：透传原生 false。
        expect(await platform.enableBluetooth(), false);

        messenger.setMockMessageHandler(enableChannel, null);
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    });
  });
}

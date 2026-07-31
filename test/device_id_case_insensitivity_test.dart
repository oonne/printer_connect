import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:printer_connect/src/utils/cache_handler.dart';
import 'package:printer_connect/printer_connect.dart';
import 'package:printer_connect/src/printer_connect.g.dart'
    show ConnectionPlatformConfig;

import 'printer_connect_test_mock.dart';

class _MockPlatform extends PrinterConnectPlatformMock {
  @override
  Future<int> readRssi(String deviceId) => throw UnimplementedError();

  @override
  Future<void> connect(
    String deviceId, {
    bool autoConnect = false,
    Duration? connectionTimeout,
    ConnectionPlatformConfig? platformConfig,
  }) async {
    updateConnection(deviceId.toLowerCase(), true);
  }
}

void main() {
  const upper = 'AA:BB:CC:DD:EE:FF';
  const lower = 'aa:bb:cc:dd:ee:ff';
  const charId = '0000fff1-0000-1000-8000-00805f9b34fb';

  test(
    'connectionStream matches a device id reported in a different case',
    () async {
      final platform = _MockPlatform();
      final event = platform.connectionStream(upper).first;
      platform.updateConnection(lower, true);
      expect(await event, isTrue);
    },
  );

  test(
    'characteristicValueStream matches a device id reported in a different case',
    () async {
      final platform = _MockPlatform();
      final event = platform.characteristicValueStream(upper, charId).first;
      platform.updateCharacteristicValue(
        lower,
        charId,
        Uint8List.fromList([1, 2, 3]),
        null,
      );
      expect(await event, Uint8List.fromList([1, 2, 3]));
    },
  );

  test(
    'pairingStateStream matches a device id reported in a different case',
    () async {
      final platform = _MockPlatform();
      final event = platform.pairingStateStream(upper).first;
      platform.updatePairingState(lower, true);
      expect(await event, isTrue);
    },
  );

  test(
    'connect() completes when the platform reports the id in a different case',
    () async {
      PrinterConnect.setInstance(_MockPlatform());
      await PrinterConnect.connect(upper, timeout: const Duration(seconds: 2));
    },
  );

  test('pairing-state dedup treats the two cases as one device', () async {
    final platform = _MockPlatform();
    final events = <bool>[];
    final sub = platform.pairingStateStream(upper).listen(events.add);
    platform.updatePairingState(lower, true);
    platform.updatePairingState(upper, true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(events, [true]);
  });

  test(
    'connection-parameters dedup treats the two cases as one device',
    () async {
      final platform = _MockPlatform();
      final events = <String>[];
      platform.onConnectionParametersChange = (u) => events.add(u.deviceId);
      BleConnectionParametersUpdated params(String id) =>
          BleConnectionParametersUpdated(
            deviceId: id,
            interval: 12,
            latency: 0,
            supervisionTimeout: 500,
            status: 0,
          );
      platform.updateConnectionParameters(params(lower));
      platform.updateConnectionParameters(params(upper));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events, [lower]);
    },
  );

  test(
    'service cache is keyed case-insensitively (save one case, get/clear another)',
    () {
      final cache = CacheHandler.instance;
      cache.resetDeviceCache(upper);
      cache.saveServices(upper, const []);
      expect(cache.getServices(lower), isNotNull);
      cache.resetDeviceCache(lower);
      expect(cache.getServices(upper), isNull);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:printer_connect/printer_connect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BleConnectionParametersUpdatedX', () {
    test('intervalMs and supervisionTimeoutMs', () {
      final update = BleConnectionParametersUpdated(
        deviceId: 'aa:bb:cc:dd:ee:ff',
        interval: 12,
        latency: 0,
        supervisionTimeout: 500,
        status: 0,
      );
      expect(update.intervalMs, 15.0);
      expect(update.supervisionTimeoutMs, 5000);
      expect(update.isSuccess, isTrue);
    });

    test('estimatedPriority heuristic', () {
      // 当前项目的 estimatedPriority 返回 int（0=低性能/低功耗, 1=中, 2=高）
      // 逻辑: interval <= 0 -> 0; interval >= 800 -> 2; interval >= 200 -> 1; else 0
      expect(
        _update(interval: 12).estimatedPriority,
        0, // 与参考项目不同，当前项目返回 int 类型
      );
      expect(
        _update(interval: 40).estimatedPriority,
        0, // 40 < 200，当前项目返回 0
      );
      expect(
        _update(interval: 420).estimatedPriority,
        1, // 200 <= 420 < 800，返回 1
      );
      expect(
        _update(interval: 900).estimatedPriority,
        2, // >= 800 返回 2
      );
    });
  });

  group('updateConnectionParameters dedupe', () {
    late PrinterConnectPlatform platform;

    setUp(() {
      platform = PigeonPrinterConnectPlatform();
    });

    test('skips consecutive identical updates', () async {
      final events = <BleConnectionParametersUpdated>[];
      platform.onConnectionParametersChange = events.add;

      final update = BleConnectionParametersUpdated(
        deviceId: 'aa:bb:cc:dd:ee:ff',
        interval: 12,
        latency: 0,
        supervisionTimeout: 500,
        status: 0,
      );
      platform.updateConnectionParameters(update);
      platform.updateConnectionParameters(update);
      platform.updateConnectionParameters(
        BleConnectionParametersUpdated(
          deviceId: update.deviceId,
          interval: 420,
          latency: update.latency,
          supervisionTimeout: update.supervisionTimeout,
          status: update.status,
        ),
      );

      expect(events, hasLength(2));
      expect(events.first.interval, 12);
      expect(events.last.interval, 420);
    });
  });
}

BleConnectionParametersUpdated _update({required int interval}) {
  return BleConnectionParametersUpdated(
    deviceId: 'aa:bb:cc:dd:ee:ff',
    interval: interval,
    latency: 0,
    supervisionTimeout: 500,
    status: 0,
  );
}

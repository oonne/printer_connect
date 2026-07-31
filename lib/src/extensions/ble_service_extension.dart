import 'package:printer_connect/printer_connect.dart';

/// BleService 扩展方法
///
/// 为 BleService 提供便捷的特征查找方法。
extension BleServiceExtension on BleService {
  /// 获取指定 UUID 的特征
  ///
  /// [characteristicId] 目标特征 UUID
  /// 如果特征不存在则抛出 [PrinterConnectException]。
  BleCharacteristic getCharacteristic(String characteristicId) {
    if (characteristics.isEmpty) {
      throw PrinterConnectException(
        'No characteristics found',
        code: 'characteristicNotFound',
      );
    }
    return characteristics.firstWhere(
      (c) => BleUuidParser.compareStrings(c.uuid, characteristicId),
      orElse: () => throw PrinterConnectException(
        'Characteristic "$characteristicId" not available',
        code: 'characteristicNotFound',
      ),
    );
  }
}
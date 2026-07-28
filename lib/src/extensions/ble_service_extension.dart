import 'package:printer_connect/printer_connect.dart';

extension BleServiceExtension on BleService {
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
import 'dart:async';
import 'dart:typed_data';
import 'package:printer_connect/printer_connect.dart';

extension BleCharacteristicExtension on BleCharacteristic {
  Stream<Uint8List> get onValueReceived =>
      PrinterConnect.characteristicValueStream(metaData!.deviceId, uuid);

  CharacteristicSubscription get notifications =>
      CharacteristicSubscription(this, CharacteristicProperty.notify);

  CharacteristicSubscription get indications =>
      CharacteristicSubscription(this, CharacteristicProperty.indicate);

  Future<void> unsubscribe({Duration? timeout}) =>
      PrinterConnect.unsubscribe(
        metaData!.deviceId,
        metaData!.serviceId,
        uuid,
        timeout: timeout,
      );

  Future<Uint8List> read({Duration? timeout}) =>
      PrinterConnect.read(
        metaData!.deviceId,
        metaData!.serviceId,
        uuid,
        timeout: timeout,
      );

  Future<void> write(
    List<int> value, {
    bool withResponse = true,
    Duration? timeout,
  }) async {
    await PrinterConnect.write(
      metaData!.deviceId,
      metaData!.serviceId,
      uuid,
      Uint8List.fromList(value),
      withoutResponse: !withResponse,
      timeout: timeout,
    );
  }

  String get _deviceId {
    String? deviceId = metaData?.deviceId;
    if (deviceId == null) {
      throw "DeviceId is not preset in characteristic metaData";
    }
    return deviceId;
  }

  String get _serviceId {
    String? serviceId = metaData?.serviceId;
    if (serviceId == null) {
      throw "ServiceId is not preset in characteristic metaData";
    }
    return serviceId;
  }
}

class CharacteristicSubscription {
  final BleCharacteristic _characteristic;
  final CharacteristicProperty _property;
  final bool isSupported;

  CharacteristicSubscription(this._characteristic, this._property)
      : isSupported = _characteristic.properties.contains(_property);

  StreamSubscription listen(
    void Function(Uint8List event) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _characteristic.onValueReceived.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  Future<void> subscribe({Duration? timeout}) {
    if (!isSupported) throw Exception('Operation not supported');
    if (_property == CharacteristicProperty.indicate) {
      return PrinterConnect.subscribeIndications(
        _characteristic._deviceId,
        _characteristic._serviceId,
        _characteristic.uuid,
        timeout: timeout,
      );
    }
    return PrinterConnect.subscribeNotifications(
      _characteristic._deviceId,
      _characteristic._serviceId,
      _characteristic.uuid,
      timeout: timeout,
    );
  }

  Future<void> unsubscribe({Duration? timeout}) {
    if (!isSupported) throw Exception('Operation not supported');
    return PrinterConnect.unsubscribe(
      _characteristic._deviceId,
      _characteristic._serviceId,
      _characteristic.uuid,
      timeout: timeout,
    );
  }

  @override
  String toString() =>
      "CharacteristicSubscription(property: ${_property.name}, isSupported: $isSupported, characteristic: ${_characteristic.uuid})";
}
import 'dart:async';
import 'dart:typed_data';
import 'package:printer_connect/printer_connect.dart';

/// BleCharacteristic 扩展方法
///
/// 为 BleCharacteristic 提供便捷的特征操作方法，包括值监听、
/// 读/写、通知/指示订阅等。
extension BleCharacteristicExtension on BleCharacteristic {
  /// 特征值变化流
  ///
  /// 当特征值通过通知或指示更新时，会在流中推送新值。
  Stream<Uint8List> get onValueReceived =>
      PrinterConnect.characteristicValueStream(metaData!.deviceId, uuid);

  /// 通知订阅对象
  ///
  /// 用于订阅/取消订阅特征的通知（Notify）事件。
  CharacteristicSubscription get notifications =>
      CharacteristicSubscription(this, CharacteristicProperty.notify);

  /// 指示订阅对象
  ///
  /// 用于订阅/取消订阅特征的指示（Indicate）事件。
  CharacteristicSubscription get indications =>
      CharacteristicSubscription(this, CharacteristicProperty.indicate);

  /// 取消订阅特征的通知或指示
  ///
  /// [timeout] 操作超时时间
  Future<void> unsubscribe({Duration? timeout}) => PrinterConnect.unsubscribe(
    metaData!.deviceId,
    metaData!.serviceId,
    uuid,
    timeout: timeout,
  );

  /// 读取特征值
  ///
  /// [timeout] 操作超时时间
  Future<Uint8List> read({Duration? timeout}) => PrinterConnect.read(
    metaData!.deviceId,
    metaData!.serviceId,
    uuid,
    timeout: timeout,
  );

  /// 写入特征值
  ///
  /// [value] 要写入的字节数据
  /// [withResponse] 是否等待写入响应（默认 true）
  /// [timeout] 操作超时时间
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

  /// 获取设备 ID（从元数据中读取）
  String get _deviceId {
    String? deviceId = metaData?.deviceId;
    if (deviceId == null) {
      throw "DeviceId is not preset in characteristic metaData";
    }
    return deviceId;
  }

  /// 获取服务 ID（从元数据中读取）
  String get _serviceId {
    String? serviceId = metaData?.serviceId;
    if (serviceId == null) {
      throw "ServiceId is not preset in characteristic metaData";
    }
    return serviceId;
  }
}

/// 特征订阅管理类
///
/// 封装特征的通知/指示订阅操作，提供监听、订阅和取消订阅的便捷方法。
/// 内部会检查特征是否支持对应的属性。
class CharacteristicSubscription {
  final BleCharacteristic _characteristic;
  final CharacteristicProperty _property;

  /// 特征是否支持该订阅属性
  final bool isSupported;

  CharacteristicSubscription(this._characteristic, this._property)
    : isSupported = _characteristic.properties.contains(_property);

  /// 监听特征值变化
  ///
  /// 返回一个 [StreamSubscription]，可通过它取消监听。
  /// [onData] 收到数据时的回调
  /// [onError] 发生错误时的回调
  /// [onDone] 流关闭时的回调
  /// [cancelOnError] 是否在发生错误时自动取消订阅
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

  /// 订阅特征的通知或指示
  ///
  /// 如果特征不支持该属性，将抛出异常。
  /// [timeout] 操作超时时间
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

  /// 取消订阅特征的通知或指示
  ///
  /// 如果特征不支持该属性，将抛出异常。
  /// [timeout] 操作超时时间
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

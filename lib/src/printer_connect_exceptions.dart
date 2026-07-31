import 'package:flutter/services.dart';

/// 蓝牙连接插件基础异常类，所有特定异常均继承此类
class PrinterConnectException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  PrinterConnectException(this.message, {this.code, this.details});

  @override
  String toString() {
    if (code != null) {
      return 'PrinterConnectException: [$code] $message';
    }
    return 'PrinterConnectException: $message';
  }

  /// 从平台异常创建实例
  factory PrinterConnectException.fromError(dynamic error) {
    String message = error.toString();
    String? code;
    dynamic details = error;
    if (error is PlatformException) {
      message = error.message ?? error.details?.toString() ?? error.code;
      code = error.code;
      details = error.details;
    }
    return PrinterConnectException(message, code: code, details: details);
  }
}

/// 连接异常类，用于处理设备连接/断开相关的错误
class ConnectionException extends PrinterConnectException {
  ConnectionException(super.message, {super.code, super.details});

  factory ConnectionException.fromError(dynamic error) {
    String message;
    String? code;
    dynamic details;

    if (error is PlatformException) {
      message = error.message ?? error.details?.toString() ?? error.code;
      code = error.code;
      details = error.details;
    } else {
      message = error.toString();
      code = 'connection_error';
      details = error;
    }

    return ConnectionException(message, code: code, details: details);
  }
}

/// 配对异常类，用于处理设备配对/取消配对相关的错误
class PairingException extends PrinterConnectException {
  PairingException(super.message, {super.code, super.details});
}

/// 写入异常类，用于处理特征值写入操作的错误
class WriteException extends PrinterConnectException {
  WriteException(super.message, {super.code, super.details});
}

/// 读取异常类，用于处理特征值读取操作的错误
class ReadException extends PrinterConnectException {
  ReadException(super.message, {super.code, super.details});
}

/// 扫描异常类，用于处理设备扫描相关的错误
class ScanException extends PrinterConnectException {
  ScanException(super.message, {super.code, super.details});
}

/// 服务发现异常类，用于处理 GATT 服务发现相关的错误
class DiscoverServicesException extends PrinterConnectException {
  DiscoverServicesException(super.message, {super.code, super.details});
}

/// 通知/指示设置异常类，用于处理特征值通知（Notification）或指示（Indication）订阅的错误
class SetNotifyException extends PrinterConnectException {
  SetNotifyException(super.message, {super.code, super.details});
}

/// MTU 异常类，用于处理最大传输单元协商相关的错误
class MtuException extends PrinterConnectException {
  MtuException(super.message, {super.code, super.details});
}

/// Web 蓝牙全局禁用异常，浏览器设置中未启用 Web Bluetooth 时抛出
class WebBluetoothGloballyDisabled extends PrinterConnectException {
  WebBluetoothGloballyDisabled()
    : super(
        'Web Bluetooth is globally disabled. Please enable it in the browser settings.',
      );
}

/// 设备未找到异常类，用于处理设备、服务、特征或描述符查找失败的错误
class DeviceNotFoundException extends PrinterConnectException {
  DeviceNotFoundException([String? message])
    : super(message ?? 'Device not found', code: 'device_not_found');
}

/// 操作不支持异常类，用于处理当前平台不支持的操作
class OperationNotSupportedException extends PrinterConnectException {
  OperationNotSupportedException([String? message])
    : super(
        message ?? 'Operation not supported on this platform',
        code: 'operation_not_supported',
      );
}

/// 错误解析器，将原生层（iOS/Android）返回的错误码映射为对应的异常类型
///
/// 首先尝试解析数字错误码（iOS 和 Android 均以字符串形式传递数字码），
/// 然后匹配字符串错误码标识
PrinterConnectException errorParser(PlatformException e) {
  final code = e.code;
  final message = e.message ?? 'Unknown error';
  final details = e.details;

  // 优先尝试解析数字错误码 - iOS 和 Android 均以字符串形式传递数字码
  // （例如 "6" 表示连接失败，"11" 表示写入失败）
  final int? numericCode = int.tryParse(code);
  if (numericCode != null) {
    switch (numericCode) {
      // 6-10: 连接错误（Connection errors）
      case 6: // connectionFailed 连接失败
      case 7: // connectionTimeout 连接超时
      case 8: // connectionLost 连接丢失
      case 9: // connectionNotEstablished 连接未建立
      case 10: // disconnectionFailed 断开失败
      case 52: // connectionInProgress 连接进行中
      case 53: // deviceDisconnected 设备已断开
        return ConnectionException(message, code: code, details: details);
      // 11-12: 读取/写入错误（Read/Write errors）
      case 11: // writeFailed 写入失败
      case 37: // writeNotPermitted 写入未授权
      case 38: // writeRequestBusy 写入请求繁忙
      case 54: // characteristicDoesNotSupportWrite 特征不支持写入
      case 55: // characteristicDoesNotSupportWriteWithoutResponse 特征不支持无响应写入
        return WriteException(message, code: code, details: details);
      case 12: // readFailed 读取失败
      case 41: // readNotPermitted 读取未授权
      case 56: // characteristicDoesNotSupportRead 特征不支持读取
        return ReadException(message, code: code, details: details);
      // 13: 服务发现错误（Discover services errors）
      case 13: // discoverServicesFailed 服务发现失败
        return DiscoverServicesException(message, code: code, details: details);
      // 14-15: 通知/指示错误（Notify/Indicate errors）
      case 14: // setNotifyFailed 设置通知失败
      case 15: // setIndicateFailed 设置指示失败
      case 57: // characteristicDoesNotSupportNotify 特征不支持通知
      case 58: // characteristicDoesNotSupportIndicate 特征不支持指示
        return SetNotifyException(message, code: code, details: details);
      // 16-17: 扫描错误（Scan errors）
      case 16: // scanFailed 扫描失败
      case 17: // scanTimeout 扫描超时
        return ScanException(message, code: code, details: details);
      // 18-21: 未找到错误（Not found errors）
      case 18: // deviceNotFound 设备未找到
      case 19: // serviceNotFound 服务未找到
      case 20: // characteristicNotFound 特征未找到
      case 21: // descriptorNotFound 描述符未找到
      case 47: // invalidHandle 无效句柄
        return DeviceNotFoundException(message);
      // 22-25: 操作错误（Operation errors）
      case 22: // invalidValue 无效值
      case 23: // invalidDeviceId 无效设备ID
      case 24: // operationCancelled 操作已取消
      case 25: // operationNotSupported 操作不支持
      case 39: // notImplemented 未实现
      case 40: // notSupported 不支持
      case 45: // invalidOffset 无效偏移量
      case 46: // invalidAttributeLength 无效属性长度
      case 48: // invalidPdu 无效协议数据单元
      case 49: // insufficientKeySize 密钥长度不足
      case 50: // failed 操作失败
      case 51: // operationInProgress 操作进行中
        return OperationNotSupportedException(message);
      // 26: MTU 错误
      case 26: // mtuRequestFailed MTU请求失败
        return MtuException(message, code: code, details: details);
      // 27-28: 配对错误（Pairing errors）
      case 27: // pairingFailed 配对失败
      case 28: // unpairFailed 取消配对失败
      case 36: // notPaired 未配对
        return PairingException(message, code: code, details: details);
      // 29: 安全错误（Security errors）
      case 29: // securityError 安全错误
      case 42: // insufficientAuthentication 认证不足
      case 43: // insufficientAuthorization 授权不足
      case 44: // insufficientEncryption 加密不足
        return ConnectionException(message, code: code, details: details);
      // 30-31: 流错误（Stream errors）
      case 30: // streamAlreadyListening 流已在监听
      case 31: // streamNotListening 流未在监听
        return PrinterConnectException(message, code: code, details: details);
      // 32-33: 事务错误（Transaction errors）
      case 32: // transactionInProgress 事务进行中
      case 33: // invalidTransactionId 无效事务ID
        return PrinterConnectException(message, code: code, details: details);
      // 34-35: 蓝牙状态错误（Bluetooth state errors）
      case 34: // bluetoothNotEnabled 蓝牙未启用
      case 35: // bluetoothNotAllowed 蓝牙未被允许
        return PrinterConnectException(message, code: code, details: details);
    }
  }

  // 字符串错误码匹配
  switch (code) {
    case 'connection_error':
    case 'connect_error':
    case 'already_connecting':
      return ConnectionException(message, code: code, details: details);
    case 'disconnect_error':
      return ConnectionException(message, code: code, details: details);
    case 'pairing_error':
    case 'pair_error':
      return PairingException(message, code: code, details: details);
    case 'write_error':
    case 'write_failed':
      return WriteException(message, code: code, details: details);
    case 'read_error':
    case 'read_failed':
      return ReadException(message, code: code, details: details);
    case 'scan_error':
    case 'scan_failed':
      return ScanException(message, code: code, details: details);
    case 'discover_services_error':
    case 'discover_services_failed':
      return DiscoverServicesException(message, code: code, details: details);
    case 'set_notify_error':
    case 'set_notify_failed':
      return SetNotifyException(message, code: code, details: details);
    case 'mtu_error':
    case 'mtu_request_failed':
      return MtuException(message, code: code, details: details);
    case 'device_not_found':
      return DeviceNotFoundException(message);
    case 'operation_not_supported':
      return OperationNotSupportedException(message);
    default:
      return PrinterConnectException(message, code: code, details: details);
  }
}

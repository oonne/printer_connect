import 'dart:async';

import 'package:flutter/services.dart';

/// 通用蓝牙错误码枚举
///
/// 错误码分为两段：
/// - 0~33：原始错误码
/// - 34~58：扩展错误码，匹配 iOS/Android 原生枚举值
enum UniversalBleErrorCode {
  // 0-33: 原始错误码
  unknownError,
  bluetoothNotAvailable,
  bluetoothNotAuthorized,
  bluetoothPermissionDenied,
  bluetoothDisabled,
  bluetoothInvalidState,
  connectionFailed,
  connectionTimeout,
  connectionLost,
  connectionNotEstablished,
  disconnectionFailed,
  writeFailed,
  readFailed,
  discoverServicesFailed,
  setNotifyFailed,
  setIndicateFailed,
  scanFailed,
  scanTimeout,
  deviceNotFound,
  serviceNotFound,
  characteristicNotFound,
  descriptorNotFound,
  invalidValue,
  invalidDeviceId,
  operationCancelled,
  operationNotSupported,
  mtuRequestFailed,
  pairingFailed,
  unpairFailed,
  securityError,
  streamAlreadyListening,
  streamNotListening,
  transactionInProgress,
  invalidTransactionId,
  // 34-58: 扩展错误码，匹配 iOS/Android 原生枚举
  bluetoothNotEnabled,
  bluetoothNotAllowed,
  notPaired,
  writeNotPermitted,
  writeRequestBusy,
  notImplemented,
  notSupported,
  readNotPermitted,
  insufficientAuthentication,
  insufficientAuthorization,
  insufficientEncryption,
  invalidOffset,
  invalidAttributeLength,
  invalidHandle,
  invalidPdu,
  insufficientKeySize,
  failed,
  operationInProgress,
  connectionInProgress,
  deviceDisconnected,
  characteristicDoesNotSupportWrite,
  characteristicDoesNotSupportWriteWithoutResponse,
  characteristicDoesNotSupportRead,
  characteristicDoesNotSupportNotify,
  characteristicDoesNotSupportIndicate,
}

/// 通用蓝牙错误解析器
///
/// 将各种来源的错误（原生平台异常、数字错误码、字符串错误信息等）
/// 统一解析为 [UniversalBleErrorCode] 枚举值。
class UniversalBleErrorParser {
  UniversalBleErrorParser._();

  /// 从各种类型的 [error] 中解析出 [UniversalBleErrorCode]
  static UniversalBleErrorCode getCode(dynamic error) {
    if (error is UniversalBleErrorCode) return error;

    if (error is PlatformException) {
      final code = error.code;
      final int? intCode = int.tryParse(code);
      if (intCode != null) {
        final parsed = _parseNumericErrorCode(intCode);
        if (parsed != null) return parsed;
      }
      return _parseStringErrorCode(code) ?? UniversalBleErrorCode.unknownError;
    }

    if (error is num) {
      final parsed = _parseNumericErrorCode(error.toInt());
      return parsed ?? UniversalBleErrorCode.unknownError;
    }

    if (error is String) {
      final int? intCode = int.tryParse(error);
      if (intCode != null) {
        final parsed = _parseNumericErrorCode(intCode);
        if (parsed != null) return parsed;
      }
      return _parseStringErrorCode(error) ?? UniversalBleErrorCode.unknownError;
    }

    if (error is TimeoutException) {
      return UniversalBleErrorCode.connectionTimeout;
    } else if (error is StateError) {
      return UniversalBleErrorCode.unknownError;
    } else if (error is ArgumentError) {
      return UniversalBleErrorCode.invalidValue;
    } else if (error is Exception) {
      return _parseStringErrorCode(error.toString()) ??
          UniversalBleErrorCode.unknownError;
    }
    return UniversalBleErrorCode.unknownError;
  }

  /// 通过字符串匹配解析错误码
  ///
  /// 将字符串转为小写后，通过关键字匹配映射到对应的错误码。
  static UniversalBleErrorCode? _parseStringErrorCode(String code) {
    final lowerCode = code.toLowerCase();

    if (lowerCode.contains('bluetooth') || lowerCode.contains('ble')) {
      if (lowerCode.contains('not_available') ||
          lowerCode.contains('unavailable')) {
        return UniversalBleErrorCode.bluetoothNotAvailable;
      }
      if (lowerCode.contains('not_authorized') ||
          lowerCode.contains('unauthorized')) {
        return UniversalBleErrorCode.bluetoothNotAuthorized;
      }
      if (lowerCode.contains('permission') &&
          (lowerCode.contains('denied') || lowerCode.contains('rejected'))) {
        return UniversalBleErrorCode.bluetoothPermissionDenied;
      }
      if (lowerCode.contains('disabled') || lowerCode.contains('off')) {
        return UniversalBleErrorCode.bluetoothDisabled;
      }
      if (lowerCode.contains('invalid_state') || lowerCode.contains('state')) {
        return UniversalBleErrorCode.bluetoothInvalidState;
      }
    }

    if (lowerCode.contains('connect')) {
      if (lowerCode.contains('timeout') || lowerCode.contains('timed_out')) {
        return UniversalBleErrorCode.connectionTimeout;
      }
      if (lowerCode.contains('fail') || lowerCode.contains('error')) {
        return UniversalBleErrorCode.connectionFailed;
      }
      if (lowerCode.contains('lost')) {
        return UniversalBleErrorCode.connectionLost;
      }
      if (lowerCode.contains('not_established') ||
          lowerCode.contains('not_connected')) {
        return UniversalBleErrorCode.connectionNotEstablished;
      }
    }

    if (lowerCode.contains('disconnect')) {
      return UniversalBleErrorCode.disconnectionFailed;
    }

    if (lowerCode.contains('write')) {
      return UniversalBleErrorCode.writeFailed;
    }

    if (lowerCode.contains('read')) {
      return UniversalBleErrorCode.readFailed;
    }

    if (lowerCode.contains('discover') || lowerCode.contains('service')) {
      if (lowerCode.contains('service_not_found') ||
          lowerCode.contains('not_found')) {
        return UniversalBleErrorCode.serviceNotFound;
      }
      return UniversalBleErrorCode.discoverServicesFailed;
    }

    if (lowerCode.contains('characteristic')) {
      if (lowerCode.contains('not_found')) {
        return UniversalBleErrorCode.characteristicNotFound;
      }
    }

    if (lowerCode.contains('descriptor')) {
      if (lowerCode.contains('not_found')) {
        return UniversalBleErrorCode.descriptorNotFound;
      }
    }

    if (lowerCode.contains('notify')) {
      return UniversalBleErrorCode.setNotifyFailed;
    }

    if (lowerCode.contains('indicate')) {
      return UniversalBleErrorCode.setIndicateFailed;
    }

    if (lowerCode.contains('scan')) {
      if (lowerCode.contains('timeout') || lowerCode.contains('timed_out')) {
        return UniversalBleErrorCode.scanTimeout;
      }
      return UniversalBleErrorCode.scanFailed;
    }

    if (lowerCode.contains('device_not_found') ||
        lowerCode.contains('peripheral_not_found')) {
      return UniversalBleErrorCode.deviceNotFound;
    }

    if (lowerCode.contains('invalid_value') || lowerCode.contains('invalid')) {
      return UniversalBleErrorCode.invalidValue;
    }

    if (lowerCode.contains('invalid_device_id') ||
        lowerCode.contains('invalid_id')) {
      return UniversalBleErrorCode.invalidDeviceId;
    }

    if (lowerCode.contains('cancel')) {
      return UniversalBleErrorCode.operationCancelled;
    }

    if (lowerCode.contains('not_supported') ||
        lowerCode.contains('unsupported')) {
      return UniversalBleErrorCode.operationNotSupported;
    }

    if (lowerCode.contains('mtu')) {
      return UniversalBleErrorCode.mtuRequestFailed;
    }

    if (lowerCode.contains('pair')) {
      if (lowerCode.contains('fail') || lowerCode.contains('error')) {
        return UniversalBleErrorCode.pairingFailed;
      }
    }

    if (lowerCode.contains('unpair')) {
      return UniversalBleErrorCode.unpairFailed;
    }

    if (lowerCode.contains('security') || lowerCode.contains('encrypt')) {
      return UniversalBleErrorCode.securityError;
    }

    if (lowerCode.contains('stream')) {
      if (lowerCode.contains('already')) {
        return UniversalBleErrorCode.streamAlreadyListening;
      }
      if (lowerCode.contains('not')) {
        return UniversalBleErrorCode.streamNotListening;
      }
    }

    if (lowerCode.contains('transaction')) {
      if (lowerCode.contains('in_progress') || lowerCode.contains('busy')) {
        return UniversalBleErrorCode.transactionInProgress;
      }
      return UniversalBleErrorCode.invalidTransactionId;
    }

    return null;
  }

  /// 解析来自原生平台的数字错误码
  ///
  /// iOS 和 Android 均以字符串形式传递数字错误码（如 "6" 表示 connection_failed，
  /// "11" 表示 write_failed）。Dart 侧的 [UniversalBleErrorCode] 枚举索引（0..58）
  /// 与原生枚举值一一对应，因此可以直接通过索引查找。
  ///
  /// GATT/HCI 错误码映射：
  /// - GATT 错误码范围 0x00-0x1F，对应 BLE GATT 协议层的错误
  /// - HCI 错误码范围更大，对应蓝牙控制器层的错误
  /// 两类错误码都会被映射到 [UniversalBleErrorCode] 中对应的语义错误码。
  static UniversalBleErrorCode? _parseNumericErrorCode(int code) {
    // 首先尝试直接索引查找（适用于 0..58 的原生错误码）
    if (code >= 0 && code < UniversalBleErrorCode.values.length) {
      return UniversalBleErrorCode.values[code];
    }

    // GATT 错误码映射（0x00-0x1F）
    switch (code) {
      case 0x00:
        return UniversalBleErrorCode.unknownError;
      case 0x01:
        return UniversalBleErrorCode.invalidHandle;
      case 0x02:
        return UniversalBleErrorCode.readNotPermitted;
      case 0x03:
        return UniversalBleErrorCode.writeNotPermitted;
      case 0x04:
        return UniversalBleErrorCode.invalidPdu;
      case 0x05:
        return UniversalBleErrorCode.insufficientAuthentication;
      case 0x06:
        return UniversalBleErrorCode.operationNotSupported;
      case 0x07:
        return UniversalBleErrorCode.invalidOffset;
      case 0x08:
        return UniversalBleErrorCode.insufficientAuthorization;
      case 0x09:
        return UniversalBleErrorCode.operationInProgress;
      case 0x0A:
        return UniversalBleErrorCode.serviceNotFound;
      case 0x0B:
        return UniversalBleErrorCode.invalidAttributeLength;
      case 0x0C:
        return UniversalBleErrorCode.insufficientKeySize;
      case 0x0D:
        return UniversalBleErrorCode.invalidAttributeLength;
      case 0x0E:
        return UniversalBleErrorCode.failed;
      case 0x0F:
        return UniversalBleErrorCode.insufficientEncryption;
      case 0x10:
        return UniversalBleErrorCode.operationNotSupported;
      case 0x11:
        return UniversalBleErrorCode.failed;
    }

    // HCI 错误码映射
    switch (code) {
      // 连接相关错误
      case 0x08:
      case 0x10:
        return UniversalBleErrorCode.connectionTimeout;
      case 0x09:
      case 0x0A:
        return UniversalBleErrorCode.connectionFailed;
      case 0x0B:
        return UniversalBleErrorCode.connectionInProgress;
      case 0x0C:
      case 0x11:
      case 0x12:
      case 0x1A:
      case 0x1E:
      case 0x20:
        return UniversalBleErrorCode.operationNotSupported;
      case 0x0D:
      case 0x0F:
      case 0x39:
        return UniversalBleErrorCode.connectionFailed;
      case 0x0E:
        return UniversalBleErrorCode.connectionFailed;
      case 0x13:
      case 0x14:
      case 0x15:
      case 0x16:
      case 0x3D:
        return UniversalBleErrorCode.deviceDisconnected;
      case 0x3E:
      case 0x3F:
        return UniversalBleErrorCode.connectionFailed;
      // 配对/认证相关错误
      case 0x05:
        return UniversalBleErrorCode.insufficientAuthentication;
      case 0x18:
        return UniversalBleErrorCode.notPaired;
      case 0x22:
        return UniversalBleErrorCode.operationNotSupported;
    }

    return null;
  }
}

import 'dart:async';

import 'package:flutter/services.dart';

enum UniversalBleErrorCode {
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
}

class UniversalBleErrorParser {
  UniversalBleErrorParser._();

  static UniversalBleErrorCode getCode(dynamic error) {
    if (error is PlatformException) {
      return _parseStringErrorCode(error.code);
    } else if (error is TimeoutException) {
      return UniversalBleErrorCode.connectionTimeout;
    } else if (error is StateError) {
      return UniversalBleErrorCode.unknownError;
    } else if (error is ArgumentError) {
      return UniversalBleErrorCode.invalidValue;
    } else if (error is Exception) {
      return _parseStringErrorCode(error.toString());
    }
    return UniversalBleErrorCode.unknownError;
  }

  static UniversalBleErrorCode _parseStringErrorCode(String code) {
    final lowerCode = code.toLowerCase();

    if (lowerCode.contains('bluetooth') || lowerCode.contains('ble')) {
      if (lowerCode.contains('not_available') || lowerCode.contains('unavailable')) {
        return UniversalBleErrorCode.bluetoothNotAvailable;
      }
      if (lowerCode.contains('not_authorized') || lowerCode.contains('unauthorized')) {
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
      if (lowerCode.contains('not_established') || lowerCode.contains('not_connected')) {
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

    if (lowerCode.contains('device_not_found') || lowerCode.contains('peripheral_not_found')) {
      return UniversalBleErrorCode.deviceNotFound;
    }

    if (lowerCode.contains('invalid_value') || lowerCode.contains('invalid')) {
      return UniversalBleErrorCode.invalidValue;
    }

    if (lowerCode.contains('invalid_device_id') || lowerCode.contains('invalid_id')) {
      return UniversalBleErrorCode.invalidDeviceId;
    }

    if (lowerCode.contains('cancel')) {
      return UniversalBleErrorCode.operationCancelled;
    }

    if (lowerCode.contains('not_supported') || lowerCode.contains('unsupported')) {
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

    return _parseNumericErrorCode(code.hashCode);
  }

  static UniversalBleErrorCode _parseNumericErrorCode(int code) {
    switch (code) {
      case 0:
        return UniversalBleErrorCode.unknownError;
      case 1:
        return UniversalBleErrorCode.bluetoothNotAvailable;
      case 2:
        return UniversalBleErrorCode.bluetoothNotAuthorized;
      case 3:
        return UniversalBleErrorCode.bluetoothPermissionDenied;
      case 4:
        return UniversalBleErrorCode.bluetoothDisabled;
      case 5:
        return UniversalBleErrorCode.bluetoothInvalidState;
      case 6:
        return UniversalBleErrorCode.connectionFailed;
      case 7:
        return UniversalBleErrorCode.connectionTimeout;
      case 8:
        return UniversalBleErrorCode.connectionLost;
      case 9:
        return UniversalBleErrorCode.connectionNotEstablished;
      case 10:
        return UniversalBleErrorCode.disconnectionFailed;
      case 11:
        return UniversalBleErrorCode.writeFailed;
      case 12:
        return UniversalBleErrorCode.readFailed;
      case 13:
        return UniversalBleErrorCode.discoverServicesFailed;
      case 14:
        return UniversalBleErrorCode.setNotifyFailed;
      case 15:
        return UniversalBleErrorCode.setIndicateFailed;
      case 16:
        return UniversalBleErrorCode.scanFailed;
      case 17:
        return UniversalBleErrorCode.scanTimeout;
      case 18:
        return UniversalBleErrorCode.deviceNotFound;
      case 19:
        return UniversalBleErrorCode.serviceNotFound;
      case 20:
        return UniversalBleErrorCode.characteristicNotFound;
      case 21:
        return UniversalBleErrorCode.descriptorNotFound;
      case 22:
        return UniversalBleErrorCode.invalidValue;
      case 23:
        return UniversalBleErrorCode.invalidDeviceId;
      case 24:
        return UniversalBleErrorCode.operationCancelled;
      case 25:
        return UniversalBleErrorCode.operationNotSupported;
      case 26:
        return UniversalBleErrorCode.mtuRequestFailed;
      case 27:
        return UniversalBleErrorCode.pairingFailed;
      case 28:
        return UniversalBleErrorCode.unpairFailed;
      case 29:
        return UniversalBleErrorCode.securityError;
      case 30:
        return UniversalBleErrorCode.streamAlreadyListening;
      case 31:
        return UniversalBleErrorCode.streamNotListening;
      case 32:
        return UniversalBleErrorCode.transactionInProgress;
      case 33:
        return UniversalBleErrorCode.invalidTransactionId;
      default:
        return UniversalBleErrorCode.unknownError;
    }
  }
}

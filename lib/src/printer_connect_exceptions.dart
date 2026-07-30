import 'package:flutter/services.dart';

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

class PairingException extends PrinterConnectException {
  PairingException(super.message, {super.code, super.details});
}

class WriteException extends PrinterConnectException {
  WriteException(super.message, {super.code, super.details});
}

class ReadException extends PrinterConnectException {
  ReadException(super.message, {super.code, super.details});
}

class ScanException extends PrinterConnectException {
  ScanException(super.message, {super.code, super.details});
}

class DiscoverServicesException extends PrinterConnectException {
  DiscoverServicesException(super.message, {super.code, super.details});
}

class SetNotifyException extends PrinterConnectException {
  SetNotifyException(super.message, {super.code, super.details});
}

class MtuException extends PrinterConnectException {
  MtuException(super.message, {super.code, super.details});
}

class WebBluetoothGloballyDisabled extends PrinterConnectException {
  WebBluetoothGloballyDisabled()
      : super('Web Bluetooth is globally disabled. Please enable it in the browser settings.');
}

class DeviceNotFoundException extends PrinterConnectException {
  DeviceNotFoundException([String? message])
      : super(message ?? 'Device not found',
            code: 'device_not_found');
}

class OperationNotSupportedException extends PrinterConnectException {
  OperationNotSupportedException([String? message])
      : super(message ?? 'Operation not supported on this platform',
            code: 'operation_not_supported');
}

PrinterConnectException errorParser(PlatformException e) {
  final code = e.code;
  final message = e.message ?? 'Unknown error';
  final details = e.details;

  // Try to parse numeric code first - both iOS and Android send numeric
  // codes as strings (e.g. "6" for connection_failed, "11" for write_failed).
  final int? numericCode = int.tryParse(code);
  if (numericCode != null) {
    switch (numericCode) {
      // 6-10: Connection errors
      case 6: // connectionFailed
      case 7: // connectionTimeout
      case 8: // connectionLost
      case 9: // connectionNotEstablished
      case 10: // disconnectionFailed
      case 52: // connectionInProgress
      case 53: // deviceDisconnected
        return ConnectionException(message,
            code: code, details: details);
      // 11-12: Read/Write errors
      case 11: // writeFailed
      case 37: // writeNotPermitted
      case 38: // writeRequestBusy
      case 54: // characteristicDoesNotSupportWrite
      case 55: // characteristicDoesNotSupportWriteWithoutResponse
        return WriteException(message, code: code, details: details);
      case 12: // readFailed
      case 41: // readNotPermitted
      case 56: // characteristicDoesNotSupportRead
        return ReadException(message, code: code, details: details);
      // 13: Discover services errors
      case 13: // discoverServicesFailed
        return DiscoverServicesException(message,
            code: code, details: details);
      // 14-15: Notify/Indicate errors
      case 14: // setNotifyFailed
      case 15: // setIndicateFailed
      case 57: // characteristicDoesNotSupportNotify
      case 58: // characteristicDoesNotSupportIndicate
        return SetNotifyException(message, code: code, details: details);
      // 16-17: Scan errors
      case 16: // scanFailed
      case 17: // scanTimeout
        return ScanException(message, code: code, details: details);
      // 18-21: Not found errors
      case 18: // deviceNotFound
      case 19: // serviceNotFound
      case 20: // characteristicNotFound
      case 21: // descriptorNotFound
      case 47: // invalidHandle
        return DeviceNotFoundException(message);
      // 22-25: Operation errors
      case 22: // invalidValue
      case 23: // invalidDeviceId
      case 24: // operationCancelled
      case 25: // operationNotSupported
      case 39: // notImplemented
      case 40: // notSupported
      case 45: // invalidOffset
      case 46: // invalidAttributeLength
      case 48: // invalidPdu
      case 49: // insufficientKeySize
      case 50: // failed
      case 51: // operationInProgress
        return OperationNotSupportedException(message);
      // 26: MTU errors
      case 26: // mtuRequestFailed
        return MtuException(message, code: code, details: details);
      // 27-28: Pairing errors
      case 27: // pairingFailed
      case 28: // unpairFailed
      case 36: // notPaired
        return PairingException(message, code: code, details: details);
      // 29: Security errors
      case 29: // securityError
      case 42: // insufficientAuthentication
      case 43: // insufficientAuthorization
      case 44: // insufficientEncryption
        return ConnectionException(message,
            code: code, details: details);
      // 30-31: Stream errors
      case 30: // streamAlreadyListening
      case 31: // streamNotListening
        return PrinterConnectException(message,
            code: code, details: details);
      // 32-33: Transaction errors
      case 32: // transactionInProgress
      case 33: // invalidTransactionId
        return PrinterConnectException(message,
            code: code, details: details);
      // 34-35: Bluetooth state errors
      case 34: // bluetoothNotEnabled
      case 35: // bluetoothNotAllowed
        return PrinterConnectException(message,
            code: code, details: details);
    }
  }

  switch (code) {
    case 'connection_error':
    case 'connect_error':
    case 'already_connecting':
      return ConnectionException(message, code: code, details: details);
    case 'disconnect_error':
      return ConnectionException(message,
          code: code, details: details);
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
      return DiscoverServicesException(message,
          code: code, details: details);
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

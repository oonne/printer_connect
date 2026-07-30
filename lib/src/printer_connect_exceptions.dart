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
      case 6: // connectionFailed
      case 7: // connectionTimeout
      case 8: // connectionLost
      case 9: // connectionNotEstablished
      case 10: // disconnectionFailed
        return ConnectionException(message,
            code: code, details: details);
      case 11: // writeFailed
        return WriteException(message, code: code, details: details);
      case 12: // readFailed
        return ReadException(message, code: code, details: details);
      case 13: // discoverServicesFailed
        return DiscoverServicesException(message,
            code: code, details: details);
      case 14: // setNotifyFailed
      case 15: // setIndicateFailed
        return SetNotifyException(message, code: code, details: details);
      case 16: // scanFailed
      case 17: // scanTimeout
        return ScanException(message, code: code, details: details);
      case 18: // deviceNotFound
        return DeviceNotFoundException(message);
      case 24: // operationCancelled
      case 25: // operationNotSupported
        return OperationNotSupportedException(message);
      case 26: // mtuRequestFailed
        return MtuException(message, code: code, details: details);
      case 27: // pairingFailed
      case 28: // unpairFailed
        return PairingException(message, code: code, details: details);
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

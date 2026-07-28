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
}

class ConnectionException extends PrinterConnectException {
  ConnectionException(super.message, {super.code, super.details});
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

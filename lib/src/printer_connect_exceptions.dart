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

class WebBluetoothGloballyDisabled extends PrinterConnectException {
  WebBluetoothGloballyDisabled()
      : super('Web Bluetooth is globally disabled. Please enable it in the browser settings.');
}

PrinterConnectException _errorParser(PlatformException e) {
  final code = e.code;
  final message = e.message ?? 'Unknown error';
  final details = e.details;

  switch (code) {
    case 'connection_error':
    case 'connect_error':
      return ConnectionException(message, code: code, details: details);
    case 'pairing_error':
    case 'pair_error':
      return PairingException(message, code: code, details: details);
    default:
      return PrinterConnectException(message, code: code, details: details);
  }
}
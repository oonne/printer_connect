import 'dart:typed_data';

import 'package:printer_connect/src/printer_connect.g.dart'
    hide BleConnectionParametersUpdated, ConnectionPlatformConfig;
import 'package:printer_connect/src/models/model_exports.dart';

typedef OnScanResultUpdate = void Function(BleDevice device);
typedef OnConnectionChange = void Function(String deviceId, BleConnectionState state);
typedef OnValueChange = void Function(String deviceId, String service, String characteristic, Uint8List value);
typedef OnAvailabilityChange = void Function(AvailabilityState state);
typedef OnPairingStateChange = void Function(String deviceId, bool isPaired);
typedef OnConnectionParametersChange = void Function(String deviceId, BleConnectionParametersUpdated params);
typedef OnQueueUpdate = void Function(String deviceId, int remainingItems);
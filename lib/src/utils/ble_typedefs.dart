import 'dart:typed_data';

import 'package:printer_connect/src/printer_connect.g.dart'
    hide BleConnectionParametersUpdated, ConnectionPlatformConfig;
import 'package:printer_connect/src/models/model_exports.dart';

/// Central mode callbacks
typedef OnConnectionChange =
    void Function(String deviceId, bool isConnected, String? error);

typedef OnValueChange =
    void Function(
      String deviceId,
      String characteristicId,
      Uint8List value,
      int? timestamp,
    );

typedef OnScanResult = void Function(BleDevice scanResult);

typedef OnAvailabilityChange = void Function(AvailabilityState state);

typedef OnPairingStateChange = void Function(String deviceId, bool isPaired);

typedef OnConnectionParametersChange =
    void Function(BleConnectionParametersUpdated update);

typedef OnQueueUpdate = void Function(String id, int remainingQueueItems);
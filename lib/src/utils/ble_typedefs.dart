import 'dart:typed_data';

import 'package:printer_connect/src/printer_connect.g.dart'
    hide BleConnectionParametersUpdated, ConnectionPlatformConfig;
import 'package:printer_connect/src/models/model_exports.dart';

/// 中央模式回调：设备连接状态变化
///
/// [deviceId] 设备标识，[isConnected] 是否已连接，[error] 错误信息（可选）
typedef OnConnectionChange =
    void Function(String deviceId, bool isConnected, String? error);

/// 特征值变化回调：接收到特征值数据时触发
///
/// [deviceId] 设备标识，[characteristicId] 特征值标识，[value] 数据值，[timestamp] 时间戳
typedef OnValueChange =
    void Function(
      String deviceId,
      String characteristicId,
      Uint8List value,
      int? timestamp,
    );

/// 扫描结果回调：扫描到蓝牙设备时触发
typedef OnScanResult = void Function(BleDevice scanResult);

/// 蓝牙可用性变化回调：蓝牙开关状态或权限变化时触发
typedef OnAvailabilityChange = void Function(AvailabilityState state);

/// 连接参数变化回调：连接参数（如 MTU、间隔等）更新时触发
typedef OnConnectionParametersChange =
    void Function(BleConnectionParametersUpdated update);

/// 队列更新回调：队列剩余项变化时触发
///
/// [id] 队列标识，[remainingQueueItems] 剩余待执行的命令数量
typedef OnQueueUpdate = void Function(String id, int remainingQueueItems);

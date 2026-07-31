/// BLE 连接参数更新事件
///
/// 当设备连接参数更新时触发，包含连接间隔、延迟、监督超时等信息。
class BleConnectionParametersUpdated {
  /// 设备 ID
  final String deviceId;

  /// 连接间隔（单位：1.25ms），取值范围 7.5ms ~ 4000ms
  final int interval;

  /// 从设备延迟，允许从设备在收到连接事件后跳过的最大间隔数
  final int latency;

  /// 监督超时（单位：10ms），连接在此时间内无数据交换则视为断开
  final int supervisionTimeout;

  /// 更新状态（0 表示成功）
  final int status;

  const BleConnectionParametersUpdated({
    required this.deviceId,
    required this.interval,
    required this.latency,
    required this.supervisionTimeout,
    required this.status,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleConnectionParametersUpdated &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          interval == other.interval &&
          latency == other.latency &&
          supervisionTimeout == other.supervisionTimeout &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
        deviceId,
        interval,
        latency,
        supervisionTimeout,
        status,
      );

  @override
  String toString() =>
      'BleConnectionParametersUpdated(deviceId: $deviceId, interval: $interval, latency: $latency, supervisionTimeout: $supervisionTimeout, status: $status)';
}

/// BleConnectionParametersUpdated 的扩展方法
///
/// 提供将原始参数转换为实际毫秒值、判断连接状态和优先级的便捷方法。
extension BleConnectionParametersUpdatedX on BleConnectionParametersUpdated {
  /// 连接间隔（毫秒），interval * 1.25ms
  double get intervalMs => interval * 1.25;

  /// 监督超时（毫秒），supervisionTimeout * 10ms
  int get supervisionTimeoutMs => supervisionTimeout * 10;

  /// 连接参数更新是否成功
  bool get isSuccess => status == 0;

  /// 估算的连接优先级（0=低，1=中，2=高）
  ///
  /// 间隔越大优先级越低：>= 800 为低，>= 200 为中，其余为高。
  int get estimatedPriority {
    if (interval <= 0) return 0;
    if (interval >= 800) return 2;
    if (interval >= 200) return 1;
    return 0;
  }
}
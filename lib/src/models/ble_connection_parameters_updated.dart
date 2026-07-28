class BleConnectionParametersUpdated {
  final String deviceId;
  final int interval;
  final int latency;
  final int supervisionTimeout;
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

extension BleConnectionParametersUpdatedX on BleConnectionParametersUpdated {
  double get intervalMs => interval * 1.25;

  int get supervisionTimeoutMs => supervisionTimeout * 10;

  bool get isSuccess => status == 0;

  int get estimatedPriority {
    if (interval <= 0) return 0;
    if (interval >= 800) return 2;
    if (interval >= 200) return 1;
    return 0;
  }
}
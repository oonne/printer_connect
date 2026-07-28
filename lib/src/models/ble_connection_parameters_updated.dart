class BleConnectionParametersUpdated {
  final int mtu;
  final String deviceId;
  final int? interval;
  final int? latency;
  final int? supervisionTimeout;
  final int? status;

  const BleConnectionParametersUpdated({
    required this.mtu,
    required this.deviceId,
    this.interval,
    this.latency,
    this.supervisionTimeout,
    this.status,
  });

  factory BleConnectionParametersUpdated.fromJson(Map<String, dynamic> json) {
    return BleConnectionParametersUpdated(
      mtu: json['mtu'] as int,
      deviceId: json['deviceId'] as String,
      interval: json['interval'] as int?,
      latency: json['latency'] as int?,
      supervisionTimeout: json['supervisionTimeout'] as int?,
      status: json['status'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mtu': mtu,
      'deviceId': deviceId,
      'interval': interval,
      'latency': latency,
      'supervisionTimeout': supervisionTimeout,
      'status': status,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleConnectionParametersUpdated &&
          runtimeType == other.runtimeType &&
          mtu == other.mtu &&
          deviceId == other.deviceId &&
          interval == other.interval &&
          latency == other.latency &&
          supervisionTimeout == other.supervisionTimeout &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
        mtu,
        deviceId,
        interval,
        latency,
        supervisionTimeout,
        status,
      );

  @override
  String toString() =>
      'BleConnectionParametersUpdated(mtu: $mtu, deviceId: $deviceId, interval: $interval, latency: $latency, supervisionTimeout: $supervisionTimeout, status: $status)';
}

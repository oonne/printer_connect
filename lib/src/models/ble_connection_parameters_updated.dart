class BleConnectionParametersUpdated {
  final int minInterval;
  final int maxInterval;
  final int latency;
  final int timeout;

  const BleConnectionParametersUpdated({
    required this.minInterval,
    required this.maxInterval,
    required this.latency,
    required this.timeout,
  });

  factory BleConnectionParametersUpdated.fromJson(Map<String, dynamic> json) {
    return BleConnectionParametersUpdated(
      minInterval: json['minInterval'] as int,
      maxInterval: json['maxInterval'] as int,
      latency: json['latency'] as int,
      timeout: json['timeout'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minInterval': minInterval,
      'maxInterval': maxInterval,
      'latency': latency,
      'timeout': timeout,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleConnectionParametersUpdated &&
          runtimeType == other.runtimeType &&
          minInterval == other.minInterval &&
          maxInterval == other.maxInterval &&
          latency == other.latency &&
          timeout == other.timeout;

  @override
  int get hashCode => Object.hash(minInterval, maxInterval, latency, timeout);

  @override
  String toString() =>
      'BleConnectionParametersUpdated(minInterval: $minInterval, maxInterval: $maxInterval, latency: $latency, timeout: $timeout)';
}
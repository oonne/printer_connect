import 'package:printer_connect/src/models/model_exports.dart';

import 'ble_typedefs.dart';
import 'queue.dart';

/// 设置队列类型并进行命令排队
///
/// 支持三种队列策略：
/// - [QueueType.global]：全局队列，所有设备的命令串行执行
/// - [QueueType.perDevice]：按设备ID独立队列，每个设备的命令各自串行
/// - [QueueType.none]：不排队，命令立即执行
class BleCommandQueue {
  /// 队列类型，决定命令的排队策略
  QueueType queueType;

  /// 默认超时时间，为 null 时命令不会超时
  Duration? timeout = const Duration(seconds: 10);

  /// 队列更新回调，当队列剩余项变化时触发
  OnQueueUpdate? onQueueUpdate;

  /// 各队列实例的映射表，key 为队列标识
  final Map<String, Queue> _queueMap = {};

  /// 全局队列的标识
  static const String globalQueueId = 'global';

  BleCommandQueue({this.queueType = QueueType.global});

  /// 将命令加入队列并带超时执行
  ///
  /// 根据 [queueType] 选择对应的队列策略：
  /// - global：所有命令共享同一个全局队列，严格串行
  /// - perDevice：按 deviceId 分配独立队列，不同设备可并行
  /// - none：直接执行命令，不经过排队
  Future<T> queueCommand<T>(
    Future<T> Function() command, {
    String? deviceId,
    Duration? timeout,
    String? queueId,
  }) {
    Duration? timeoutDuration = timeout ?? this.timeout;
    if (timeoutDuration == null) {
      return queueCommandWithoutTimeout(
        command,
        deviceId: deviceId,
        queueId: queueId,
      );
    }
    return switch (queueType) {
      QueueType.global => _queue(queueId).add(command, timeoutDuration),
      QueueType.perDevice => _queue(
        queueId ?? deviceId,
      ).add(command, timeoutDuration),
      QueueType.none => command().timeout(timeoutDuration),
    };
  }

  /// 将命令加入队列且不设置超时
  Future<T> queueCommandWithoutTimeout<T>(
    Future<T> Function() command, {
    String? deviceId,
    String? queueId,
  }) {
    return switch (queueType) {
      QueueType.global => _queue(queueId).add(command),
      QueueType.perDevice => _queue(queueId ?? deviceId).add(command),
      QueueType.none => command(),
    };
  }

  /// 根据 ID 获取或创建队列实例
  Queue _queue(String? id) {
    final queueKey = id ?? globalQueueId;
    return _queueMap[queueKey] ?? _newQueue(queueKey);
  }

  /// 创建新队列并注册回调监听
  Queue _newQueue(String id) {
    final queue = Queue();
    queue.onRemainingItemsUpdate = (int items) {
      try {
        onQueueUpdate?.call(id, items);
      } catch (_) {}
    };
    _queueMap[id] = queue;
    return queue;
  }

  /// 清除指定队列或全部队列
  void clearQueue(String? id) {
    if (id == null) {
      _queueMap.forEach((k, v) => v.dispose());
      _queueMap.clear();
    } else {
      _queueMap[id]?.dispose();
      _queueMap.remove(id);
    }
  }
}
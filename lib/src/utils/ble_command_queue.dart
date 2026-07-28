import 'dart:async';

import 'package:printer_connect/src/models/model_exports.dart';

import 'ble_typedefs.dart';
import 'queue.dart';

class BleCommandQueue {
  static const String globalQueueId = 'global';

  QueueType queueType;
  final Duration? timeout;
  final OnQueueUpdate? onQueueUpdate;

  final Map<String, Queue<dynamic>> _queueMap = {};

  BleCommandQueue({
    this.queueType = QueueType.global,
    this.timeout = const Duration(seconds: 10),
    this.onQueueUpdate,
  });

  Queue<dynamic> _queue(String? id) {
    switch (queueType) {
      case QueueType.global:
        return _queueMap.putIfAbsent(globalQueueId, () {
          final queue = Queue<dynamic>(
            onRemainingItemsUpdate: (remaining) {
              onQueueUpdate?.call(globalQueueId, remaining);
            },
          );
          return queue;
        });
      case QueueType.perDevice:
        final key = (id == null || id.isEmpty) ? globalQueueId : id;
        return _queueMap.putIfAbsent(key, () {
          final queue = Queue<dynamic>(
            onRemainingItemsUpdate: (remaining) {
              onQueueUpdate?.call(key, remaining);
            },
          );
          return queue;
        });
      case QueueType.none:
        return _queueMap.putIfAbsent(globalQueueId, () {
          final queue = Queue<dynamic>(
            onRemainingItemsUpdate: (remaining) {
              onQueueUpdate?.call(globalQueueId, remaining);
            },
          );
          return queue;
        });
    }
  }

  Future<T> queueCommand<T>(
    Future<T> Function() task, {
    String? deviceId,
    Duration? timeout,
  }) {
    switch (queueType) {
      case QueueType.none:
        return task();
      case QueueType.global:
        return _queue(globalQueueId).add(task, timeout: timeout ?? this.timeout)
            as Future<T>;
      case QueueType.perDevice:
        final queue = _queue(deviceId);
        return queue.add(task, timeout: timeout ?? this.timeout) as Future<T>;
    }
  }

  Future<T> queueCommandWithoutTimeout<T>(
    Future<T> Function() task, {
    String? deviceId,
  }) {
    switch (queueType) {
      case QueueType.none:
        return task();
      case QueueType.global:
        return _queue(globalQueueId).add(task) as Future<T>;
      case QueueType.perDevice:
        final queue = _queue(deviceId);
        return queue.add(task) as Future<T>;
    }
  }

  int getGlobalQueueRemainingItems() {
    return _queueMap[globalQueueId]?.totalRemainingItems ?? 0;
  }

  int getDeviceQueueRemainingItems(String deviceId) {
    return _queueMap[deviceId]?.totalRemainingItems ?? 0;
  }

  void clearQueue({String? deviceId}) {
    final key = deviceId ?? globalQueueId;
    final queue = _queueMap[key];
    if (queue != null) {
      queue.clear();
    }
  }

  void dispose() {
    for (final queue in _queueMap.values) {
      queue.dispose();
    }
    _queueMap.clear();
  }
}
import 'dart:async';

import 'package:printer_connect/src/models/model_exports.dart';

import 'ble_typedefs.dart';
import 'queue.dart';

class BleCommandQueue {
  final QueueType queueType;
  final Duration? timeout;
  final OnQueueUpdate? onQueueUpdate;

  final Map<String, Queue<dynamic>> _queues = {};
  final Queue<dynamic> _globalQueue = Queue<dynamic>();

  BleCommandQueue({
    this.queueType = QueueType.none,
    this.timeout = const Duration(seconds: 10),
    this.onQueueUpdate,
  });

  Queue<dynamic> _queue(String? id) {
    switch (queueType) {
      case QueueType.global:
        return _globalQueue;
      case QueueType.perDevice:
        if (id == null || id.isEmpty) {
          return _globalQueue;
        }
        return _queues.putIfAbsent(id, () {
          final queue = Queue<dynamic>(
            onRemainingItemsUpdate: (remaining) {
              onQueueUpdate?.call(id, remaining);
            },
          );
          return queue;
        });
      case QueueType.none:
        return _globalQueue;
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
        return _globalQueue.add(task, timeout: timeout ?? this.timeout)
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
        return _globalQueue.add(task) as Future<T>;
      case QueueType.perDevice:
        final queue = _queue(deviceId);
        return queue.add(task) as Future<T>;
    }
  }

  int getGlobalQueueRemainingItems() {
    return _globalQueue.totalRemainingItems;
  }

  int getDeviceQueueRemainingItems(String deviceId) {
    final queue = _queues[deviceId];
    return queue?.totalRemainingItems ?? 0;
  }

  void dispose() {
    _globalQueue.dispose();
    for (final queue in _queues.values) {
      queue.dispose();
    }
    _queues.clear();
  }
}

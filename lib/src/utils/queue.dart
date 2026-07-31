import 'dart:async';

/// 原作者：Ryan Knell (https://github.com/rknell/dart_queue)
///
/// 串行执行队列。
/// 工作原理：按顺序依次执行入队的 Future，每个 Future 必须等前一个完成后才会开始执行。
/// 同一时刻只有一个任务处于活跃状态，新任务被添加到 [_nextCycle] 列表中排队等待。
class Queue {
  /// 当前正在执行的任务 ID 集合
  final Set<int> _activeItems = {};

  /// 用于生成唯一任务 ID 的计数器
  int _lastProcessId = 0;

  /// 队列是否已取消
  bool _isCancelled = false;

  /// 等待执行的任务列表
  final List<_QueuedFuture> _nextCycle = [];

  /// 队列剩余项变化回调
  Function(int)? onRemainingItemsUpdate;

  /// 添加任务到队列，可选超时时间
  Future<T> add<T>(Future<T> Function() closure, [Duration? timeout]) {
    if (_isCancelled) throw Exception('Queue Cancelled');
    final completer = Completer<T>();
    _nextCycle.add(_QueuedFuture<T>(closure, completer, timeout));
    _updateRemainingItems();
    if (_activeItems.isEmpty) _queueUpNext();
    return completer.future;
  }

  /// 释放队列，取消所有等待中的任务
  void dispose() {
    for (final item in _nextCycle) {
      item.completer.completeError(Exception('Queue Cancelled'));
    }
    _nextCycle.removeWhere((item) => item.completer.isCompleted);
    _isCancelled = true;
  }

  /// 调度下一个任务执行
  ///
  /// 当活跃任务为空时，从 [_nextCycle] 取出队首任务执行，
  /// 并在任务完成后递归调用自身以处理后续排队任务。
  void _queueUpNext() {
    if (_nextCycle.isNotEmpty && !_isCancelled && _activeItems.length <= 1) {
      final processId = _lastProcessId;
      _activeItems.add(processId);
      final item = _nextCycle.first;
      _lastProcessId++;
      _nextCycle.remove(item);
      item.onComplete = () async {
        _activeItems.remove(processId);
        _updateRemainingItems();
        _queueUpNext();
      };
      unawaited(item.execute());
    }
  }

  /// 更新并通知队列剩余项数量
  void _updateRemainingItems() {
    int remainingQueueItems = _nextCycle.length + _activeItems.length;
    onRemainingItemsUpdate?.call(remainingQueueItems);
  }
}

/// 封装了带超时机制的排队 Future 任务
///
/// 超时机制：当 [timeout] 非空时，通过 [Future.timeout] 对原始 Future 进行包装，
/// 若任务在指定时间内未完成，将抛出 [TimeoutException]，由 [execute] 的 catch 块捕获
/// 并传递给 completer 完成错误回调。
class _QueuedFuture<T> {
  final Completer completer;
  final Future<T> Function() closure;
  Function? onComplete;
  final Duration? timeout;

  _QueuedFuture(this.closure, this.completer, this.timeout, {this.onComplete});

  /// 执行排队任务
  Future<void> execute() async {
    try {
      T result;
      if (timeout != null) {
        result = await closure().timeout(timeout!);
      } else {
        result = await closure();
      }
      if (result != null) {
        completer.complete(result);
      } else {
        completer.complete(null);
      }
      await Future.microtask(() {});
    } catch (e, stack) {
      completer.completeError(e, stack);
    } finally {
      if (onComplete != null) onComplete!.call();
    }
  }
}
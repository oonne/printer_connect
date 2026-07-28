import 'dart:async';

class Queue<T> {
  final List<_QueueItem<T>> _items = [];
  final List<_QueueItem<T>> _nextCycleItems = [];
  bool _isProcessing = false;

  final void Function(int remainingItems)? onRemainingItemsUpdate;

  Queue({this.onRemainingItemsUpdate});

  int get activeItemsCount => _items.where((e) => e.isActive).length;

  int get nextCycleItemsCount => _nextCycleItems.length;

  int get totalRemainingItems => _items.length + _nextCycleItems.length;

  Future<T> add(Future<T> Function() task, {Duration? timeout}) {
    final completer = Completer<T>();
    final item = _QueueItem<T>(
      task: task,
      completer: completer,
      timeout: timeout,
    );
    _items.add(item);
    _tryProcess();
    return completer.future;
  }

  void _tryProcess() {
    if (_isProcessing) return;
    if (_items.isEmpty) {
      _onRemainingItemsUpdate();
      return;
    }
    _isProcessing = true;
    _processNext();
  }

  void _processNext() {
    if (_items.isEmpty) {
      _isProcessing = false;
      _tryProcess();
      return;
    }

    final item = _items.first;
    item.execute().whenComplete(() {
      _items.remove(item);
      _isProcessing = false;
      _tryProcess();
    });
  }

  void _onRemainingItemsUpdate() {
    onRemainingItemsUpdate?.call(totalRemainingItems);
  }

  void moveToNextCycle() {
    _nextCycleItems.addAll(_items);
    _items.clear();
  }

  void dispose() {
    for (final item in _items) {
      if (!item.completer.isCompleted) {
        item.completer.completeError(
          StateError('Queue has been disposed'),
        );
      }
    }
    for (final item in _nextCycleItems) {
      if (!item.completer.isCompleted) {
        item.completer.completeError(
          StateError('Queue has been disposed'),
        );
      }
    }
    _items.clear();
    _nextCycleItems.clear();
    _isProcessing = false;
  }
}

class _QueueItem<T> {
  final Future<T> Function() task;
  final Completer<T> completer;
  final Duration? timeout;
  bool isActive = false;

  _QueueItem({
    required this.task,
    required this.completer,
    this.timeout,
  });

  Future<void> execute() async {
    isActive = true;
    try {
      final result = await task().timeout(
            timeout ?? const Duration(seconds: 30),
          );
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
  }
}

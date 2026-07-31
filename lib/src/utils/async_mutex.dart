/// 异步互斥锁
///
/// 工作原理：通过维护一个 [_current] Future 作为锁的标识。
/// 当 [protect] 被调用时，若 [_current] 非空（即有任务正在执行），
/// 则等待该 Future 完成后再执行新任务。任务完成后在 finally 中清除 [_current]，
/// 确保后续排队的任务能够获取锁。
///
/// 此实现保证了同一时刻只有一个异步任务在执行，适用于需要串行访问共享资源的场景。
class AsyncMutex {
  Future? _current;

  /// 受互斥锁保护地执行 [computation]
  ///
  /// 若当前有其他任务在执行，将等待其完成后再开始执行 [computation]。
  Future<T> protect<T>(Future<T> Function() computation) async {
    while (_current != null) {
      await _current;
    }
    final Future<T> result = computation();
    _current = result;
    try {
      return await result;
    } finally {
      if (_current == result) {
        _current = null;
      }
    }
  }
}
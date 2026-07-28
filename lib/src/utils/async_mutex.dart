class AsyncMutex {
  Future? _current;

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
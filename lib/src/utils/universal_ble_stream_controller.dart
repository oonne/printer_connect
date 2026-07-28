import 'dart:async';

class UniversalBleStreamController<T> {
  final Future<T>? Function()? initialEvent;

  StreamController<T>? _controller;
  Stream<T>? _stream;
  bool _isClosed = false;

  UniversalBleStreamController({this.initialEvent});

  Stream<T> get stream {
    if (_isClosed) {
      throw StateError('UniversalBleStreamController has been closed');
    }
    _setupStreamIfRequired();
    return _stream!;
  }

  void _setupStreamIfRequired() {
    if (_controller != null) return;
    _controller = StreamController<T>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
    _stream = _controller!.stream;
  }

  void _onListen() {
    if (initialEvent != null) {
      final future = initialEvent!();
      if (future != null) {
        future.then((value) {
          if (!_isClosed && _controller != null) {
            _controller!.add(value);
          }
        }).catchError((_) {});
      }
    }
  }

  void _onCancel() {
    if (_controller != null && _controller!.hasListener) {
      return;
    }
    _disposeController();
  }

  void add(T value) {
    if (_isClosed) return;
    _setupStreamIfRequired();
    _controller!.add(value);
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    if (_isClosed) return;
    _setupStreamIfRequired();
    _controller!.addError(error, stackTrace);
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _disposeController();
  }

  Future<void> _disposeController() async {
    if (_controller != null) {
      await _controller!.close();
      _controller = null;
      _stream = null;
    }
  }

  bool get isClosed => _isClosed || (_controller?.isClosed ?? true);

  bool get hasListener => _controller?.hasListener ?? false;
}

import 'dart:async';

/// 自动释放的 StreamController
///
/// 当无订阅者时（即 [onCancel] 触发），StreamController 会自动关闭并释放资源，
/// 避免内存泄漏。支持 [initialEvent] 回调，在首次订阅时触发初始事件发送。
class UniversalBleStreamController<T> {
  /// 首次订阅时触发的初始事件回调
  Future<T> Function()? initialEvent;

  UniversalBleStreamController({this.initialEvent});

  StreamController<T>? _streamController;

  /// 获取广播流
  ///
  /// 首次访问时会创建 StreamController，设置 [onListen] 回调。
  /// [onListen] 在每次有新订阅者时触发，会调用 [initialEvent] 获取初始数据并添加到流中。
  Stream<T> get stream {
    _setupStreamIfRequired();
    return _streamController!.stream;
  }

  /// 流是否已关闭
  bool get isClosed => _streamController?.isClosed ?? true;

  /// 向流中添加数据
  void add(T data) => _streamController?.add(data);

  /// 关闭流并释放资源
  void close() {
    _streamController?.close();
    _streamController = null;
  }

  /// 按需初始化 StreamController
  ///
  /// 使用 broadcast 模式创建，支持多订阅者。
  /// [onListen]：首次订阅时触发，执行 [initialEvent] 回调获取初始事件。
  /// [onCancel]：最后一个订阅者取消订阅时触发，自动调用 [close] 释放资源。
  void _setupStreamIfRequired() {
    if (_streamController != null) return;
    _streamController = StreamController<T>.broadcast(
      onListen: () async {
        try {
          T? event = await initialEvent?.call();
          if (event != null) add(event);
        } catch (_) {}
      },
      onCancel: close,
    );
  }
}

import 'package:printer_connect/printer_connect.dart';

/// 打印机服务信息
///
/// 包含打印所需的设备和服务信息，由 [PrinterServiceFinder.initDevice] 返回。
class PrinterServiceInfo {
  /// 设备 ID
  final String deviceId;

  /// 设备名称
  final String name;

  /// 服务 UUID（小写 128 位格式）
  final String service;

  /// 特征 UUID（小写 128 位格式）
  final String characteristic;

  PrinterServiceInfo({
    required this.deviceId,
    required this.name,
    required this.service,
    required this.characteristic,
  });

  @override
  String toString() =>
      'PrinterServiceInfo(deviceId: $deviceId, name: $name, '
      'service: $service, characteristic: $characteristic)';
}

/// 打印机服务查找器
///
/// 不同的打印机设备，使用不同的标准方式来获取可用的 service 和 characteristic。
/// 通过蓝牙名判断设备厂商，每个厂商有不同的获取方式。
///
/// 说明：本插件中 [PrinterConnect.discoverServices] 一次返回所有 service 及其
/// characteristic（characteristic 已内嵌在 [BleService] 中），因此等价于小程序中
/// `wx.getBLEDeviceServices` + `wx.getBLEDeviceCharacteristics` 的组合调用。
/// 另外本插件会将所有 UUID 规范化为小写 128 位格式，前缀匹配时已做大小写归一化处理。
class PrinterServiceFinder {
  PrinterServiceFinder._();

  /// 初始化设备
  ///
  /// 输入 [deviceId] 和 [name]，先连接设备，
  /// 然后根据蓝牙名判断厂商，按照各厂商的标准方式获取打印所需的 service 和 characteristic。
  ///
  /// 返回 [PrinterServiceInfo]，其中包含 deviceId、name、service、characteristic。
  ///
  /// 可能抛出：
  /// - [ConnectionException]：连接失败
  /// - [PrinterConnectException]：未找到可用服务或特征（code: serviceNotFound / characteristicNotFound）
  static Future<PrinterServiceInfo> initDevice({
    required String deviceId,
    required String name,
  }) async {
    // 1. 连接设备
    await PrinterConnect.connect(deviceId);

    // 2. 根据蓝牙名判断厂商，获取 service 和 characteristic
    late String service;
    late String characteristic;

    if (_isPt(name)) {
      // 普贴打印机
      final result = await _getPt(deviceId);
      service = result.service;
      characteristic = result.characteristic;
    } else if (_isZicox(name)) {
      // 芝柯打印机
      final result = await _getZicox(deviceId);
      service = result.service;
      characteristic = result.characteristic;
    } else {
      // 其他通用打印机
      final result = await _getUniversal(deviceId);
      service = result.service;
      characteristic = result.characteristic;
    }

    return PrinterServiceInfo(
      deviceId: deviceId,
      name: name,
      service: service,
      characteristic: characteristic,
    );
  }

  // ===========================================================================
  // 普贴打印机
  // 蓝牙名包含 "51DC" 或 "54DC"
  // serviceId 以 "49535343" 开头
  // characteristicId 以 "49535343" 开头
  // ===========================================================================

  /// 判断是否为普贴打印机
  static bool _isPt(String localName) {
    return localName.contains('51DC') || localName.contains('54DC');
  }

  /// 获取普贴打印机的 service 和 characteristic
  static Future<({String service, String characteristic})> _getPt(
    String deviceId,
  ) async {
    // 获取设备所有服务（对应 wx.getBLEDeviceServices）
    final services = await PrinterConnect.discoverServices(deviceId);

    // 查找以 "49535343" 开头的 service
    // 注意：普贴使用自定义 128 位 UUID（如 49535343-fe7d-4ae4-bf50-eb645e79f2d3），
    // 不能通过 BleUuidParser.string("49535343") 补全为标准 UUID，因此采用前缀匹配。
    final service = services.firstWhere(
      (s) => _uuidStartsWith(s.uuid, '49535343'),
      orElse: () => throw PrinterConnectException(
        '打印机不支持(未找到可用服务)',
        code: 'serviceNotFound',
      ),
    );

    // 确定 characteristic：以 "49535343" 开头且支持 write
    final characteristic = service.characteristics.firstWhere(
      (c) =>
          _uuidStartsWith(c.uuid, '49535343') &&
          c.properties.contains(CharacteristicProperty.write),
      orElse: () => throw PrinterConnectException(
        '打印机不支持(未找到可用特征)',
        code: 'characteristicNotFound',
      ),
    );

    return (service: service.uuid, characteristic: characteristic.uuid);
  }

  // ===========================================================================
  // 芝柯打印机
  // 蓝牙名以 "CC4" 开头
  // serviceId 以 "0000FFF0" 开头
  // characteristicId 以 "0000FFF2" 开头
  // ===========================================================================

  /// 判断是否为芝柯打印机
  static bool _isZicox(String localName) {
    return localName.startsWith('CC4') || localName.startsWith('KP02');
  }

  /// 获取芝柯打印机的 service 和 characteristic
  static Future<({String service, String characteristic})> _getZicox(
    String deviceId,
  ) async {
    // 获取设备所有服务（对应 wx.getBLEDeviceServices）
    final services = await PrinterConnect.discoverServices(deviceId);

    // 查找以 "0000FFF0" 开头的 service
    final service = services.firstWhere(
      (s) => _uuidStartsWith(s.uuid, '0000FFF0'),
      orElse: () => throw PrinterConnectException(
        '打印机不支持(未找到可用服务)',
        code: 'serviceNotFound',
      ),
    );

    // 确定 characteristic：以 "0000FFF2" 开头且支持 write
    final characteristic = service.characteristics.firstWhere(
      (c) =>
          _uuidStartsWith(c.uuid, '0000FFF2') &&
          c.properties.contains(CharacteristicProperty.write),
      orElse: () => throw PrinterConnectException(
        '打印机不支持(未找到可用特征)',
        code: 'characteristicNotFound',
      ),
    );

    return (service: service.uuid, characteristic: characteristic.uuid);
  }
  // ===========================================================================
  // 其他通用打印机
  // 取第一个满足 (notify || indicate) && write 的特征值
  // ===========================================================================

  /// 获取通用打印机的 service 和 characteristic
  ///
  /// 遍历所有服务和特征，查找第一个满足 (notify || indicate) && write 的特征值。
  static Future<({String service, String characteristic})> _getUniversal(
    String deviceId,
  ) async {
    // 获取设备所有服务（对应 wx.getBLEDeviceServices）
    final services = await PrinterConnect.discoverServices(deviceId);

    // 遍历所有服务和特征，查找第一个满足 (notify || indicate) && write 的特征
    // （对应 wx.getBLEDeviceCharacteristics，本插件中特征已内嵌在服务对象中）
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        final hasNotifyOrIndicate =
            characteristic.properties.contains(CharacteristicProperty.notify) ||
            characteristic.properties.contains(CharacteristicProperty.indicate);
        final hasWrite =
            characteristic.properties.contains(CharacteristicProperty.write);
        if (hasNotifyOrIndicate && hasWrite) {
          return (
            service: service.uuid,
            characteristic: characteristic.uuid,
          );
        }
      }
    }

    throw PrinterConnectException(
      '打印机不支持(未找到可用特征)',
      code: 'characteristicNotFound',
    );
  }

  // ===========================================================================
  // 辅助方法
  // ===========================================================================

  /// 检查 UUID 是否以指定前缀开头（不区分大小写）
  ///
  /// 本插件会将所有 UUID 规范化为小写 128 位格式（如 `0000fff0-0000-1000-8000-00805f9b34fb`），
  /// 此处对前缀也做 toLowerCase，确保大小写不影响匹配。
  static bool _uuidStartsWith(String uuid, String prefix) {
    return uuid.toLowerCase().startsWith(prefix.toLowerCase());
  }
}

/// BLE UUID 解析工具类
///
/// 提供 UUID 字符串解析、格式化和比较的静态工具方法。
/// 支持短 UUID（如 0x1800）和完整 128 位 UUID 之间的转换。
class BleUuidParser {
  BleUuidParser._();

  /// 将字符串解析为有效的 128 位 UUID 格式
  ///
  /// 支持以下输入格式：
  /// - 短 UUID（如 "1800"、"0x1800"），会自动补全为标准 128 位 UUID
  /// - 无连字符的 32 位十六进制字符串
  /// - 标准带连字符的 UUID 格式
  ///
  /// 如果字符串不是有效的 UUID 格式，会抛出 [FormatException]。
  static String string(String uuid) {
    uuid = uuid.trim();
    if (uuid.length < 4) {
      throw const FormatException('Invalid UUID');
    }

    if (uuid.startsWith('0x')) {
      uuid = uuid.substring(2);
    }

    if (uuid.length <= 8) {
      uuid = "${uuid.padLeft(8, '0')}-0000-1000-8000-00805f9b34fb";
    }

    if (!uuid.contains("-")) {
      if (uuid.length != 32) throw const FormatException("Invalid UUID");

      uuid =
          "${uuid.substring(0, 8)}-${uuid.substring(8, 12)}"
          "-${uuid.substring(12, 16)}-${uuid.substring(16, 20)}-${uuid.substring(20, 32)}";
    }

    var groups = uuid.split('-');

    if (groups.length != 5 ||
        groups[0].length != 8 ||
        groups[1].length != 4 ||
        groups[2].length != 4 ||
        groups[3].length != 4 ||
        groups[4].length != 12) {
      throw const FormatException('Invalid UUID');
    }

    try {
      int.parse(groups[0], radix: 16);
      int.parse(groups[1], radix: 16);
      int.parse(groups[2], radix: 16);
      int.parse(groups[3], radix: 16);
      int.parse(groups[4], radix: 16);
    } catch (e) {
      throw const FormatException('Invalid UUID');
    }

    return uuid.toLowerCase();
  }

  /// 将字符串解析为有效的 128 位 UUID，无效时返回 null
  static String? stringOrNull(String uuid) {
    try {
      return string(uuid);
    } catch (e) {
      return null;
    }
  }

  /// 将整数转换为 128 位 UUID 字符串
  ///
  /// 例如：`0x1800` → `00001800-0000-1000-8000-00805f9b34fb`。
  /// 仅支持 16 位短 UUID（0x00FF ~ 0xFFFF）。
  static String number(int short) {
    if (short <= 0xFF || short > 0xFFFF) {
      throw const FormatException('Invalid UUID');
    }
    return string(short.toRadixString(16).padLeft(4, '0'));
  }

  /// 比较两个 UUID 字符串是否相同（忽略格式差异）
  ///
  /// 将两个 UUID 都标准化后再比较。
  static bool compareStrings(String uuid1, String uuid2) =>
      string(uuid1) == string(uuid2);
}

/// 字符串列表转 UUID 列表扩展
extension StringListToUUID on List<String> {
  /// 将字符串列表中每个元素转换为有效的 UUID
  List<String> toValidUUIDList() => map(BleUuidParser.string).toList();
}

import Foundation

/// 日志系统类（单例模式）。
///
/// 支持 5 个日志级别：error、warning、info、debug、verbose。
/// 通过 setLogLevel 设置输出级别，只有级别值 <= 当前设置的日志才会输出。
/// 日志格式：[时间戳] PrinterConnect:级别 消息内容
final class PrinterConnectLogger {
    /// 共享实例
    static let shared = PrinterConnectLogger()
    private init() {}

    /// 日期格式化器，用于生成日志时间戳
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    /// 当前日志级别（默认为 .none 即不输出任何日志）
    private var currentLogLevel: BleLogLevel = .none

    /// 设置日志输出级别
    func setLogLevel(_ logLevel: BleLogLevel) {
        currentLogLevel = logLevel
    }

    /// 输出 ERROR 级别日志
    func logError(_ message: String) {
        guard allows(.error) else { return }
        print("PrinterConnect:ERROR \(withTimestamp(message))")
    }

    /// 输出 WARNING 级别日志
    func logWarning(_ message: String) {
        guard allows(.warning) else { return }
        print("PrinterConnect:WARN \(withTimestamp(message))")
    }

    /// 输出 INFO 级别日志
    func logInfo(_ message: String) {
        guard allows(.info) else { return }
        print("PrinterConnect:INFO \(withTimestamp(message))")
    }

    /// 输出 DEBUG 级别日志
    func logDebug(_ message: String) {
        guard allows(.debug) else { return }
        print("PrinterConnect:DEBUG \(withTimestamp(message))")
    }

    /// 输出 VERBOSE 级别日志
    func logVerbose(_ message: String) {
        guard allows(.verbose) else { return }
        print("PrinterConnect:VERBOSE \(withTimestamp(message))")
    }

    /// 判断指定级别是否应该输出（只有当级别值 <= 当前设置值时才输出）
    private func allows(_ level: BleLogLevel) -> Bool {
        return currentLogLevel != .none && level.rawValue <= currentLogLevel.rawValue
    }

    /// 为日志消息添加时间戳前缀
    private func withTimestamp(_ message: String) -> String {
        let time = dateFormatter.string(from: Date())
        return "[\(time)] \(message)"
    }
}
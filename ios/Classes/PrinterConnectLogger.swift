import Foundation

final class PrinterConnectLogger {
    static let shared = PrinterConnectLogger()
    private init() {}

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private var currentLogLevel: BleLogLevel = .none

    func setLogLevel(_ logLevel: BleLogLevel) {
        currentLogLevel = logLevel
    }

    func logError(_ message: String) {
        guard allows(.error) else { return }
        print("PrinterConnect:ERROR \(withTimestamp(message))")
    }

    func logWarning(_ message: String) {
        guard allows(.warning) else { return }
        print("PrinterConnect:WARN \(withTimestamp(message))")
    }

    func logInfo(_ message: String) {
        guard allows(.info) else { return }
        print("PrinterConnect:INFO \(withTimestamp(message))")
    }

    func logDebug(_ message: String) {
        guard allows(.debug) else { return }
        print("PrinterConnect:DEBUG \(withTimestamp(message))")
    }

    func logVerbose(_ message: String) {
        guard allows(.verbose) else { return }
        print("PrinterConnect:VERBOSE \(withTimestamp(message))")
    }

    private func allows(_ level: BleLogLevel) -> Bool {
        return currentLogLevel != .none && level.rawValue >= currentLogLevel.rawValue
    }

    private func withTimestamp(_ message: String) -> String {
        let time = dateFormatter.string(from: Date())
        return "[\(time)] \(message)"
    }
}
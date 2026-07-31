//
//  PrinterConnectHelper.swift
//  printer_connect
//

import CoreBluetooth
import Foundation

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

extension CBCharacteristicProperties {
    var toCharacteristicProperty: [CharacteristicProperty] {
        var properties: [CharacteristicProperty] = []
        if contains(.broadcast) { properties.append(.broadcast) }
        if contains(.read) { properties.append(.read) }
        if contains(.writeWithoutResponse) { properties.append(.writeWithoutResponse) }
        if contains(.write) { properties.append(.write) }
        if contains(.notify) { properties.append(.notify) }
        if contains(.indicate) { properties.append(.indicate) }
        if contains(.authenticatedSignedWrites) { properties.append(.authenticatedSignedWrites) }
        if contains(.extendedProperties) { properties.append(.extendedProperties) }
        return properties
    }
}

extension CBManagerState {
    func toAvailabilityState() -> AvailabilityState {
        switch self {
        case .unknown: return .unknown
        case .resetting: return .resetting
        case .unsupported: return .unsupported
        case .unauthorized: return .unauthorized
        case .poweredOff: return .poweredOff
        case .poweredOn: return .poweredOn
        @unknown default: return .unknown
        }
    }
}

/// 跨平台统一错误码枚举。
///
/// 与 Pigeon 生成的 `UniversalBleErrorCode` 枚举保持一致的数值定义，
/// 数值与 Android 端的 `UniversalBleErrorCode` rawValue 对齐，
/// 以便 Dart 端解析器（`_parseNumericErrorCode`）可以直接通过
/// `UniversalBleErrorCode.values[code]` 进行索引查找。
enum UniversalBleErrorCode: Int {
    case unknownError = 0
    case bluetoothNotAvailable = 1
    case bluetoothNotAuthorized = 2
    case bluetoothPermissionDenied = 3
    case bluetoothDisabled = 4
    case bluetoothInvalidState = 5
    case connectionFailed = 6
    case connectionTimeout = 7
    case connectionLost = 8
    case connectionNotEstablished = 9
    case disconnectionFailed = 10
    case writeFailed = 11
    case readFailed = 12
    case discoverServicesFailed = 13
    case setNotifyFailed = 14
    case setIndicateFailed = 15
    case scanFailed = 16
    case scanTimeout = 17
    case deviceNotFound = 18
    case serviceNotFound = 19
    case characteristicNotFound = 20
    case descriptorNotFound = 21
    case invalidValue = 22
    case invalidDeviceId = 23
    case operationCancelled = 24
    case operationNotSupported = 25
    case mtuRequestFailed = 26
    case pairingFailed = 27
    case unpairFailed = 28
    case securityError = 29
    case streamAlreadyListening = 30
    case streamNotListening = 31
    case transactionInProgress = 32
    case invalidTransactionId = 33
    case bluetoothNotEnabled = 34
    case bluetoothNotAllowed = 35
    case notPaired = 36
    case writeNotPermitted = 37
    case writeRequestBusy = 38
    case notImplemented = 39
    case notSupported = 40
    case readNotPermitted = 41
    case insufficientAuthentication = 42
    case insufficientAuthorization = 43
    case insufficientEncryption = 44
    case invalidOffset = 45
    case invalidAttributeLength = 46
    case invalidHandle = 47
    case invalidPdu = 48
    case insufficientKeySize = 49
    case failed = 50
    case operationInProgress = 51
    case connectionInProgress = 52
    case deviceDisconnected = 53
    case characteristicDoesNotSupportWrite = 54
    case characteristicDoesNotSupportWriteWithoutResponse = 55
    case characteristicDoesNotSupportRead = 56
    case characteristicDoesNotSupportNotify = 57
    case characteristicDoesNotSupportIndicate = 58
}

/// 将错误码（字符串或数值）映射为 UniversalBleErrorCode 枚举。
///
/// CoreBluetooth 返回的 NSError 带有数值错误码（如 CBATTErrorDomain 使用 0..13）。
/// 当 `toFlutterError` 将 NSError 的 code 转为字符串时，本函数会先尝试解析为整数，
/// 以便将 CBATTError / GATT / HCI 错误码映射到正确的 `UniversalBleErrorCode`。
/// 对于无法解析为整数的字符串，保留字符串回退逻辑以兼容旧代码路径。
func mapErrorCodeToEnum(_ code: String) -> UniversalBleErrorCode {
    // 优先尝试解析为 CoreBluetooth 数值错误码（GATT 错误码 0-13）
    if let intCode = Int(code) {
        switch intCode {
        case 0: return .unknownError
        case 1: return .deviceDisconnected // CBATTError.invalidHandle
        case 2: return .readNotPermitted
        case 3: return .writeNotPermitted
        case 4: return .invalidPdu
        case 5: return .insufficientAuthentication
        case 6: return .operationNotSupported // requestNotSupported
        case 7: return .invalidOffset
        case 8: return .insufficientAuthorization
        case 9: return .operationInProgress
        case 10: return .serviceNotFound // attrNotFound
        case 11: return .invalidAttributeLength
        case 12: return .insufficientKeySize
        case 13: return .invalidAttributeLength // attrNotLong
        case 14: return .failed // unlikely
        case 15: return .insufficientEncryption
        case 16: return .operationNotSupported // unsupportedGroup
        case 17: return .failed // insufficientResources
        // HCI 错误码映射
        case 0x08, 0x10: return .connectionTimeout
        case 0x09, 0x0A: return .failed // connectionLimitExceeded -> failed
        case 0x0B: return .connectionInProgress
        case 0x0C, 0x11, 0x12, 0x1A, 0x1E, 0x20: return .operationNotSupported
        case 0x0D, 0x0F, 0x39: return .connectionFailed // connectionRejected
        case 0x0E: return .connectionFailed // connectionRejectedDueToSecurity
        case 0x13, 0x14, 0x15, 0x16, 0x3D: return .deviceDisconnected
        case 0x3E, 0x3F: return .connectionFailed
        case 0x05: return .insufficientAuthentication // authenticationFailure
        case 0x18: return .notPaired
        case 0x22: return .operationNotSupported // lmpResponseTimeout
        default: break
        }
    }

    // 字符串回退：兼容旧代码路径，处理字符串格式的错误码
    switch code.lowercased() {
    case "notsupported", "not_supported":
        return .notSupported
    case "notimplemented", "not_implemented":
        return .notImplemented
    case "channel-error", "channelerror":
        return .unknownError // channelError mapped to unknownError in aligned scheme
    case "failed":
        return .failed
    case "devicedisconnected", "device_disconnected":
        return .deviceDisconnected
    case "illegalargument", "illegal_argument":
        return .invalidValue // illegalArgument -> invalidValue
    case "invalidaction", "invalid_action":
        return .invalidValue
    case "readfailed", "read_failed":
        return .readFailed
    case "devicenotfound", "device_not_found":
        return .deviceNotFound
    case "servicenotfound", "service_not_found":
        return .serviceNotFound
    case "characteristicnotfound", "characteristic_not_found":
        return .characteristicNotFound
    case "invalidserviceuuid", "invalid_service_uuid":
        return .invalidValue // invalidServiceUuid -> invalidValue
    case "characteristicdoesnotsupportread":
        return .characteristicDoesNotSupportRead
    case "characteristicdoesnotsupportwrite":
        return .characteristicDoesNotSupportWrite
    case "characteristicdoesnotsupportwritewithoutresponse":
        return .characteristicDoesNotSupportWriteWithoutResponse
    case "characteristicdoesnotsupportnotify":
        return .characteristicDoesNotSupportNotify
    case "characteristicdoesnotsupportindicate":
        return .characteristicDoesNotSupportIndicate
    default:
        return .unknownError
    }
}

/// 创建传递给 Flutter 层的 PigeonError 对象。
///
/// 将枚举的 rawValue（Int）转为字符串作为 error code，
/// 将枚举的 rawValue 作为 details，便于 Dart 端识别错误类型。
func createFlutterError(
    code: UniversalBleErrorCode,
    message: String? = nil,
    details: String? = nil
) -> PigeonError {
    // Pass the enum's rawValue (Int) in code as string, and enum name in details
    return PigeonError(
        code: code.rawValue.description,
        message: message,
        details: details ?? code.rawValue
    )
}

extension Error {
    func toFlutterError() -> PigeonError {
        let nsError = self as NSError
        let errorCode: String = .init(nsError.code)
        let errorDescription: String = nsError.localizedDescription
        let mappedCode = mapErrorCodeToEnum(errorCode)
        return createFlutterError(code: mappedCode, message: errorDescription, details: errorCode)
    }
}

/// CBUUID 扩展：提供统一的 UUID 字符串格式（小写）
public extension CBUUID {
    var uuidStr: String {
        uuidString.lowercased()
    }
}

/// CBPeripheral 扩展：提供 UUID 获取、特征值查找等便捷方法
public extension CBPeripheral {
    // FIXME: https://forums.developer.apple.com/thread/84375
    /// 获取外设的 UUID（兼容不同 iOS 版本的 KVC 实现）
    var uuid: UUID {
        value(forKey: "identifier") as! NSUUID as UUID
    }

    /// 根据服务 UUID 和特征值 UUID 查找对应的 CBCharacteristic。
    /// 支持完整 UUID 和短 UUID（仅 16-bit 部分）两种格式。
    func getCharacteristic(_ characteristic: String, of service: String) -> CBCharacteristic? {
        let GSS_SUFFIX = "0000-1000-8000-00805f9b34fb"
        let s = services?.first {
            $0.uuid.uuidStr.lowercased() == service.lowercased() || service.lowercased() == "0000\($0.uuid.uuidStr)-\(GSS_SUFFIX)".lowercased()
        }
        let c = s?.characteristics?.first {
            $0.uuid.uuidStr.lowercased() == characteristic.lowercased() || characteristic.lowercased() == "0000\($0.uuid.uuidStr)-\(GSS_SUFFIX)".lowercased()
        }
        return c
    }

    func setNotifiable(_ bleInputProperty: String, for characteristic: String, of service: String) {
        guard let characteristic = getCharacteristic(characteristic, of: service) else {
            return
        }
        setNotifyValue(bleInputProperty != "disabled", for: characteristic)
    }
}

extension FlutterStandardTypedData {
    func toData() -> Data {
        return Data(data)
    }
}

// MARK: - Future 类（用于匹配异步操作回调）

/// 特征值读取操作的 Future，存储读取请求的上下文信息及结果回调
class CharacteristicReadFuture {
    let deviceId: String
    let characteristicId: String
    let serviceId: String?
    let result: (Result<FlutterStandardTypedData, Error>) -> Void

    init(deviceId: String, characteristicId: String, serviceId: String?, result: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
        self.deviceId = deviceId
        self.characteristicId = characteristicId
        self.serviceId = serviceId
        self.result = result
    }
}

/// 特征值写入操作的 Future
class CharacteristicWriteFuture {
    let deviceId: String
    let characteristicId: String
    let serviceId: String?
    let result: (Result<Void, Error>) -> Void

    init(deviceId: String, characteristicId: String, serviceId: String?, result: @escaping (Result<Void, Error>) -> Void) {
        self.deviceId = deviceId
        self.characteristicId = characteristicId
        self.serviceId = serviceId
        self.result = result
    }
}

/// 特征值通知/指示订阅操作的 Future
class CharacteristicNotifyFuture {
    let deviceId: String
    let characteristicId: String
    let serviceId: String?
    let result: (Result<Void, Error>) -> Void

    init(deviceId: String, characteristicId: String, serviceId: String?, result: @escaping (Result<Void, Error>) -> Void) {
        self.deviceId = deviceId
        self.characteristicId = characteristicId
        self.serviceId = serviceId
        self.result = result
    }
}

/// 服务发现操作的 Future
class DiscoverServicesFuture {
    let deviceId: String
    let result: (Result<[UniversalBleService], Error>) -> Void

    init(deviceId: String, result: @escaping (Result<[UniversalBleService], Error>) -> Void) {
        self.deviceId = deviceId
        self.result = result
    }
}

/// RSSI 读取操作的 Future
class RssiReadFuture {
    let deviceId: String
    let result: (Result<Int64, Error>) -> Void

    init(deviceId: String, result: @escaping (Result<Int64, Error>) -> Void) {
        self.deviceId = deviceId
        self.result = result
    }
}

// MARK: - String 扩展：设备查找便捷方法

extension String {
    /// 根据设备 ID 查找对应的 CBPeripheral（优先从缓存中查找）
    func getPeripheral(manager: CBCentralManager) throws -> CBPeripheral {
        guard let peripheral = findPeripheral(manager: manager) else {
            throw createFlutterError(code: .deviceNotFound, message: "Unknown deviceId:\(self)")
        }
        return peripheral
    }

    /// 优先从缓存中查找外设，若未找到则通过系统 API 检索
    func findPeripheral(manager: CBCentralManager) -> CBPeripheral? {
        if let peripheral = discoveredPeripherals[self] {
            return peripheral
        }
        if let uuid = UUID(uuidString: self) {
            let peripherals = manager.retrievePeripherals(withIdentifiers: [uuid])
            if let peripheral = peripherals.first {
                discoveredPeripherals[self] = peripheral
                return peripheral
            }
        }
        return nil
    }
}

// MARK: - [String] 扩展：UUID 数组转换

extension [String] {
    /// 将字符串数组转换为 CBUUID 数组，字符串格式无效时抛出错误
    func toCBUUID() throws -> [CBUUID] {
        return try compactMap { serviceUUID in
            guard UUID(uuidString: serviceUUID) != nil else {
                throw createFlutterError(code: .invalidValue, message: "Invalid service UUID:\(serviceUUID)")
            }
            return CBUUID(string: serviceUUID)
        }
    }
}

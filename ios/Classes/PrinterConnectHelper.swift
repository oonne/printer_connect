import Foundation
import CoreBluetooth

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
    var toAvailabilityState: AvailabilityState {
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

func mapErrorCodeToEnum(_ error: Error) -> String {
    let nsError = error as NSError
    switch nsError.code {
    case CBError.Code.unknown.rawValue: return "unknown"
    case CBError.Code.invalidParameter.rawValue: return "invalidParameter"
    case CBError.Code.invalidHandle.rawValue: return "invalidHandle"
    case CBError.Code.notConnected.rawValue: return "notConnected"
    case CBError.Code.outOfSpace.rawValue: return "outOfSpace"
    case CBError.Code.operationCancelled.rawValue: return "operationCancelled"
    case CBError.Code.operationTimedOut.rawValue: return "operationTimedOut"
    case CBError.Code.operationDisconnected.rawValue: return "operationDisconnected"
    case CBError.Code.notFound.rawValue: return "notFound"
    case CBError.Code.notLongConnected.rawValue: return "notLongConnected"
    case CBError.Code.uncachedError.rawValue: return "uncachedError"
    case CBError.Code.attRequestNotSupported.rawValue: return "attRequestNotSupported"
    case CBError.Code.invalidOffset.rawValue: return "invalidOffset"
    case CBError.Code.invalidLength.rawValue: return "invalidLength"
    case CBError.Code.invalidValue.rawValue: return "invalidValue"
    case CBError.Code.insufficientEncryption.rawValue: return "insufficientEncryption"
    default: return "unknownError_\(nsError.code)"
    }
}

func createFlutterError(code: String, message: String?, details: Any? = nil) -> PigeonError {
    return PigeonError(code: code, message: message, details: details)
}

extension Error {
    func toPigeonError() -> PigeonError {
        let nsError = self as NSError
        return PigeonError(
            code: mapErrorCodeToEnum(self),
            message: nsError.localizedDescription,
            details: nsError.userInfo
        )
    }
}

extension CBUUID {
    var uuidStr: String {
        return uuidString
    }
}

extension CBPeripheral {
    var uuid: String {
        return identifier.uuidString
    }

    func getCharacteristic(uuid: CBUUID) -> CBCharacteristic? {
        guard let services = services else { return nil }
        for service in services {
            if let characteristic = service.characteristics?.first(where: { $0.uuid == uuid }) {
                return characteristic
            }
        }
        return nil
    }

    func getCharacteristic(_ characteristicUUID: String, of serviceUUID: String) -> CBCharacteristic? {
        guard let services = services else { return nil }
        for service in services {
            if service.uuid.uuidString == serviceUUID {
                return service.characteristics?.first(where: { $0.uuid.uuidString == characteristicUUID })
            }
        }
        return nil
    }
}

#if os(iOS)
extension FlutterStandardTypedData {
    func toData() -> Data {
        return data
    }
}
#endif

extension String {
    func toData() -> Data {
        return Data(Array(hexStringToBytes(self)))
    }

    private func hexStringToBytes(_ hexString: String) -> [UInt8] {
        var bytes: [UInt8] = []
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            if nextIndex <= hexString.endIndex {
                let byteString = String(hexString[index..<nextIndex])
                if let byte = UInt8(byteString, radix: 16) {
                    bytes.append(byte)
                }
            }
            index = nextIndex
        }
        return bytes
    }
}

extension Data {
    func toData() -> Data {
        return self
    }

    func toInt64List() -> [Int64] {
        return map { Int64($0) }
    }

    init(int64List: [Int64]) {
        self.init(bytes: int64List.map { UInt8($0 & 0xFF) })
    }
}

class CharacteristicReadFuture {
    let deviceId: String
    let characteristicId: String
    let serviceId: String
    let result: (Result<FlutterStandardTypedData, Error>) -> Void

    init(deviceId: String, characteristicId: String, serviceId: String, result: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
        self.deviceId = deviceId
        self.characteristicId = characteristicId
        self.serviceId = serviceId
        self.result = result
    }
}

class CharacteristicWriteFuture {
    let deviceId: String
    let characteristicId: String
    let serviceId: String
    let result: (Result<Void, Error>) -> Void

    init(deviceId: String, characteristicId: String, serviceId: String, result: @escaping (Result<Void, Error>) -> Void) {
        self.deviceId = deviceId
        self.characteristicId = characteristicId
        self.serviceId = serviceId
        self.result = result
    }
}

class CharacteristicNotifyFuture {
    let deviceId: String
    let characteristicId: String
    let serviceId: String
    let result: (Result<Void, Error>) -> Void

    init(deviceId: String, characteristicId: String, serviceId: String, result: @escaping (Result<Void, Error>) -> Void) {
        self.deviceId = deviceId
        self.characteristicId = characteristicId
        self.serviceId = serviceId
        self.result = result
    }
}

class DiscoverServicesFuture {
    let deviceId: String
    let result: (Result<[UniversalBleService], Error>) -> Void

    init(deviceId: String, result: @escaping (Result<[UniversalBleService], Error>) -> Void) {
        self.deviceId = deviceId
        self.result = result
    }
}

class RssiReadFuture {
    let deviceId: String
    let result: (Result<Int64, Error>) -> Void

    init(deviceId: String, result: @escaping (Result<Int64, Error>) -> Void) {
        self.deviceId = deviceId
        self.result = result
    }
}

extension String {
    func toCBUUID() -> CBUUID {
        return CBUUID(string: self)
    }

    func findPeripheral(in manager: CBCentralManager) -> CBPeripheral? {
        let peripherals = manager.retrievePeripherals(withIdentifiers: [self])
        return peripherals.first
    }

    func getPeripheral(manager: CBCentralManager) throws -> CBPeripheral {
        guard let peripheral = findPeripheral(in: manager) else {
            throw createFlutterError(code: "deviceNotFound", message: "Unknown deviceId:\(self)")
        }
        return peripheral
    }
}

extension [String] {
    func toCBUUID() throws -> [CBUUID] {
        return try compactMap { serviceUUID in
            guard UUID(uuidString: serviceUUID) != nil else {
                throw createFlutterError(code: "invalidServiceUuid", message: "Invalid service UUID:\(serviceUUID)")
            }
            return CBUUID(string: serviceUUID)
        }
    }
}
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
}

#if os(iOS)
extension FlutterStandardTypedData {
    func toData() -> Data {
        return data
    }
}
#endif

extension Data {
    func toInt64List() -> [Int64] {
        return map { Int64($0) }
    }

    init(int64List: [Int64]) {
        self.init(bytes: int64List.map { UInt8($0 & 0xFF) })
    }
}

class CharacteristicReadFuture {
    let completion: (Result<FlutterStandardTypedData, PigeonError>) -> Void
    init(completion: @escaping (Result<FlutterStandardTypedData, PigeonError>) -> Void) {
        self.completion = completion
    }
}

class CharacteristicWriteFuture {
    let completion: (Result<Void, PigeonError>) -> Void
    init(completion: @escaping (Result<Void, PigeonError>) -> Void) {
        self.completion = completion
    }
}

class CharacteristicNotifyFuture {
    let completion: (Result<Void, PigeonError>) -> Void
    init(completion: @escaping (Result<Void, PigeonError>) -> Void) {
        self.completion = completion
    }
}

class DiscoverServicesFuture {
    let completion: (Result<[UniversalBleService], PigeonError>) -> Void
    init(completion: @escaping (Result<[UniversalBleService], PigeonError>) -> Void) {
        self.completion = completion
    }
}

class RssiReadFuture {
    let completion: (Result<Int64, PigeonError>) -> Void
    init(completion: @escaping (Result<Int64, PigeonError>) -> Void) {
        self.completion = completion
    }
}

class ConnectionStateFuture {
    let completion: (Result<Void, PigeonError>) -> Void
    init(completion: @escaping (Result<Void, PigeonError>) -> Void) {
        self.completion = completion
    }
}

class PairedStateFuture {
    let completion: (Result<Bool, PigeonError>) -> Void
    init(completion: @escaping (Result<Bool, PigeonError>) -> Void) {
        self.completion = completion
    }
}

class MtuFuture {
    let completion: (Result<Int64, PigeonError>) -> Void
    init(completion: @escaping (Result<Int64, PigeonError>) -> Void) {
        self.completion = completion
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

    func findOrConnectPeripheral(in manager: CBCentralManager) -> CBPeripheral? {
        if let peripheral = findPeripheral(in: manager) {
            return peripheral
        }
        return nil
    }
}
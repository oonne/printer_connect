import Foundation
import CoreBluetooth

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

// MARK: - CBCharacteristicProperties to CharacteristicProperty

extension CBCharacteristicProperties {
    var toCharacteristicProperty: [CharacteristicProperty] {
        var properties: [CharacteristicProperty] = []
        if contains(.read) { properties.append(.read) }
        if contains(.write) { properties.append(.write) }
        if contains(.writeWithoutResponse) { properties.append(.writeWithoutResponse) }
        if contains(.notify) { properties.append(.notify) }
        if contains(.indicate) { properties.append(.indicate) }
        if contains(.broadcast) { properties.append(.broadcast) }
        if contains(.extendedProperties) { properties.append(.extendedSbleProps) }
        if contains(.signedWrite) { properties.append(.signedWrite) }
        return properties
    }
}

// MARK: - CBManagerState to AvailabilityState

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

// MARK: - Error mapping

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
    func toFlutterError() -> PigeonError {
        let nsError = self as NSError
        return PigeonError(
            code: mapErrorCodeToEnum(self),
            message: nsError.localizedDescription,
            details: nsError.userInfo
        )
    }
}

// MARK: - CBUUID extensions

extension CBUUID {
    var uuidStr: String {
        return uuidString
    }
}

// MARK: - CBPeripheral extensions

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

// MARK: - Data extensions

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

// MARK: - Future classes

class CharacteristicReadFuture {
    let completion: (Result<UniversalBleCharacteristic, PigeonError>) -> Void
    init(completion: @escaping (Result<UniversalBleCharacteristic, PigeonError>) -> Void) {
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
    let completion: (Result<BleConnectionState, PigeonError>) -> Void
    init(completion: @escaping (Result<BleConnectionState, PigeonError>) -> Void) {
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

// MARK: - String extensions for getting peripherals

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
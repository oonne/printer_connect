import Foundation
import CoreBluetooth

final class PrinterConnectAsyncServiceDiscovery {

    private let logger = PrinterConnectLogger.shared
    private let peripheral: CBPeripheral
    private let deviceId: String
    private let completion: (Result<[UniversalBleService], Error>) -> Void
    private let withDescriptors: Bool

    private var discoveredServices: [UniversalBleService] = []
    private var serviceCharacteristicsMap: [String: [CBCharacteristic]] = [:]

    private var totalServicesExpected: Int = 0
    private var servicesWithCharacteristicsDiscovered: Int = 0
    private var characteristicsDiscovered: Int = 0
    private var descriptorsDiscovered: Int = 0
    private var totalCharacteristicsExpected: Int = 0
    private var totalDescriptorsExpected: Int = 0

    private var allServicesReady: Bool = false

    init(peripheral: CBPeripheral, deviceId: String, withDescriptors: Bool, completion: @escaping (Result<[UniversalBleService], Error>) -> Void) {
        self.peripheral = peripheral
        self.deviceId = deviceId
        self.withDescriptors = withDescriptors
        self.completion = completion
    }

    func startDiscovery() {
        guard !allServicesReady else {
            completion(.success(discoveredServices))
            return
        }

        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func cleanup() {
        discoveredServices.removeAll()
        serviceCharacteristicsMap.removeAll()
        totalServicesExpected = 0
        servicesWithCharacteristicsDiscovered = 0
        characteristicsDiscovered = 0
        descriptorsDiscovered = 0
        totalCharacteristicsExpected = 0
        totalDescriptorsExpected = 0
        allServicesReady = false
    }

    func handleDidDiscoverServices(_ peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            logger.logError("Error discovering services: \(error.localizedDescription)")
            completion(.failure(error))
            cleanup()
            return
        }

        guard let services = peripheral.services else {
            completion(.failure(createFlutterError(
                code: "discoverServicesError",
                message: "No services found"
            )))
            cleanup()
            return
        }

        totalServicesExpected = services.count
        servicesWithCharacteristicsDiscovered = 0
        characteristicsDiscovered = 0
        descriptorsDiscovered = 0
        totalCharacteristicsExpected = 0
        totalDescriptorsExpected = 0

        for service in services {
            let bleService = UniversalBleService(
                uuid: service.uuid.uuidString,
                characteristics: nil
            )
            discoveredServices.append(bleService)
            serviceCharacteristicsMap[service.uuid.uuidString] = []

            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func handleDidDiscoverCharacteristicsFor(_ peripheral: CBPeripheral, service: CBService, error: Error?) {
        if let error = error {
            logger.logError("Error discovering characteristics: \(error.localizedDescription)")
            completion(.failure(error))
            cleanup()
            return
        }

        let characteristicsList = service.characteristics ?? []
        serviceCharacteristicsMap[service.uuid.uuidString] = characteristicsList

        characteristicsDiscovered += characteristicsList.count
        servicesWithCharacteristicsDiscovered += 1

        if withDescriptors {
            for characteristic in characteristicsList {
                peripheral.discoverDescriptors(for: characteristic)
            }
        }

        updateExpectedCounts()
        checkForDiscoveryCompletion()
    }

    func handleDidDiscoverDescriptorsFor(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            descriptorsDiscovered += 1
            logger.logError("Descriptor discovery error: \(error.localizedDescription)")
        } else if let descriptors = characteristic.descriptors {
            descriptorsDiscovered += descriptors.count
        } else {
            descriptorsDiscovered += 1
        }

        updateExpectedCounts()
        checkForDiscoveryCompletion()
    }

    private func updateExpectedCounts() {
        var totalChars = 0
        var totalDescs = 0

        for (_, characteristics) in serviceCharacteristicsMap {
            totalChars += characteristics.count
            if withDescriptors {
                for characteristic in characteristics {
                    if let descriptors = characteristic.descriptors {
                        totalDescs += descriptors.count
                    }
                }
            }
        }

        totalCharacteristicsExpected = totalChars
        totalDescriptorsExpected = withDescriptors ? totalDescs : 0
    }

    private func checkForDiscoveryCompletion() {
        let allServicesDiscovered = servicesWithCharacteristicsDiscovered >= totalServicesExpected
        let allCharacteristicsDiscovered = characteristicsDiscovered >= totalCharacteristicsExpected
        let allDescriptorsDiscovered = withDescriptors ? (descriptorsDiscovered >= totalDescriptorsExpected) : true

        if allServicesDiscovered && allCharacteristicsDiscovered && allDescriptorsDiscovered {
            allServicesReady = true
            let result = buildResultServices()
            completion(.success(result))
            cleanup()
        }
    }

    private func buildResultServices() -> [UniversalBleService] {
        var result: [UniversalBleService] = []

        for service in discoveredServices {
            guard let characteristics = serviceCharacteristicsMap[service.uuid] else {
                result.append(service)
                continue
            }

            let bleCharacteristics = characteristics.map { char in
                let descriptors = (withDescriptors ? (char.descriptors ?? []).map { desc in
                    UniversalBleDescriptor(uuid: desc.uuid.uuidString)
                } : [])

                return UniversalBleCharacteristic(
                    uuid: char.uuid.uuidString,
                    properties: char.properties.toCharacteristicProperty,
                    descriptors: descriptors
                )
            }

            result.append(UniversalBleService(
                uuid: service.uuid,
                characteristics: bleCharacteristics
            ))
        }

        return result
    }
}
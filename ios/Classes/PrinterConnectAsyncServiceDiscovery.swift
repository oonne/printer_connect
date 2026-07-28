import Foundation
import CoreBluetooth

final class PrinterConnectAsyncServiceDiscovery {

    private let logger = PrinterConnectLogger.shared
    private let peripheral: CBPeripheral
    private let completion: (Result<[UniversalBleService], PigeonError>) -> Void

    private var discoveredServices: [UniversalBleService] = []
    private var serviceCharacteristicsMap: [String: [CBCharacteristic]] = [:]

    private var totalServicesExpected: Int = 0
    private var servicesWithCharacteristicsDiscovered: Int = 0
    private var characteristicsDiscovered: Int = 0
    private var descriptorsDiscovered: Int = 0
    private var totalCharacteristicsExpected: Int = 0
    private var totalDescriptorsExpected: Int = 0

    private var allServicesReady: Bool = false

    init(peripheral: CBPeripheral, completion: @escaping (Result<[UniversalBleService], PigeonError>) -> Void) {
        self.peripheral = peripheral
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

    func handleDidDiscoverServices(_ services: [CBService]?) {
        guard let services = services else {
            completion(.failure(createFlutterError(
                code: "discoverServicesError",
                message: "No services found",
                details: nil
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
                isPrimary: service.isPrimary
            )
            discoveredServices.append(bleService)
            serviceCharacteristicsMap[service.uuid.uuidString] = []

            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func handleDidDiscoverCharacteristicsFor(_ characteristics: [CBCharacteristic]?, for service: CBService) {
        let characteristicsList = characteristics ?? []
        serviceCharacteristicsMap[service.uuid.uuidString] = characteristicsList

        characteristicsDiscovered += characteristicsList.count
        servicesWithCharacteristicsDiscovered += 1

        for characteristic in characteristicsList {
            peripheral.discoverDescriptors(for: characteristic)
        }

        updateExpectedCounts()
        checkForDiscoveryCompletion()
    }

    func handleDidDiscoverDescriptorsFor(_ characteristic: CBCharacteristic, error: Error?) {
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
            for characteristic in characteristics {
                if let descriptors = characteristic.descriptors {
                    totalDescs += descriptors.count
                }
            }
        }

        totalCharacteristicsExpected = totalChars
        totalDescriptorsExpected = totalDescs
    }

    private func checkForDiscoveryCompletion() {
        let allServicesDiscovered = servicesWithCharacteristicsDiscovered >= totalServicesExpected
        let allCharacteristicsDiscovered = characteristicsDiscovered >= totalCharacteristicsExpected
        let allDescriptorsDiscovered = descriptorsDiscovered >= totalDescriptorsExpected

        if allServicesDiscovered && allCharacteristicsDiscovered && allDescriptorsDiscovered {
            allServicesReady = true
            completion(.success(discoveredServices))
            cleanup()
        }
    }
}
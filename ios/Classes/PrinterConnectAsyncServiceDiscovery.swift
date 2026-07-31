import CoreBluetooth
import Foundation

/// 处理 BLE 外设的异步服务发现流程。
///
/// 管理完整的 GATT 发现链路：服务 → 特征值 → 描述符。
/// 通过维护进度映射表来跟踪每个阶段的完成情况，
/// 确保所有服务及其特征值（可选描述符）都被发现后才回调完成。
class PrinterConnectAsyncServiceDiscovery: NSObject {
    private let peripheral: CBPeripheral
    private let deviceId: String
    private let completion: (Result<[UniversalBleService], Error>) -> Void
    /// 已发现服务的进度映射表（存储部分完成的服务信息）
    private var discoveredServicesProgressMap: [UniversalBleService] = []
    /// 已完成描述符发现的特征值集合（格式: "serviceUuid:characteristicUuid"）
    private var discoveredDescriptorsSet: Set<String> = []
    /// 每个服务期望发现的特征值数量（用于判断完成条件）
    private var expectedCharacteristicsCountMap: [String: Int] = [:]
    /// 标记发现流程是否正在进行中
    private var isDiscoveryInProgress = false
    /// 是否需要发现描述符
    private var withDescriptors: Bool

    init(peripheral: CBPeripheral, deviceId: String, withDescriptors: Bool, completion: @escaping (Result<[UniversalBleService], Error>) -> Void) {
        self.peripheral = peripheral
        self.deviceId = deviceId
        self.completion = completion
        self.withDescriptors = withDescriptors
        super.init()
    }

    /// 启动服务发现流程。
    /// 如果服务已被缓存则直接处理，否则调用系统 API 触发发现。
    func startDiscovery() {
        guard !isDiscoveryInProgress else {
            PrinterConnectLogger.shared.logWarning("Service discovery already in progress for device: \(deviceId)")
            return
        }
        isDiscoveryInProgress = true
        // Check if services are already cached
        if let cachedServices = peripheral.services, !cachedServices.isEmpty {
            handleServicesDiscovered(cachedServices)
        } else {
            peripheral.discoverServices(nil)
        }
    }

    /// 清理发现状态，重置所有进度变量
    func cleanup() {
        isDiscoveryInProgress = false
        discoveredServicesProgressMap.removeAll()
        discoveredDescriptorsSet.removeAll()
        expectedCharacteristicsCountMap.removeAll()
    }

    /// 处理已发现的服务列表。
    /// 为每个服务启动特征值发现流程；如果特征值已缓存则直接处理。
    private func handleServicesDiscovered(_ services: [CBService]) {
        discoveredServicesProgressMap = services.map { UniversalBleService(uuid: $0.uuid.uuidString, characteristics: nil) }
        discoveredDescriptorsSet = Set<String>()
        expectedCharacteristicsCountMap = [:]

        // If no services, complete discovery immediately
        guard !services.isEmpty else {
            checkForDiscoveryCompletion()
            return
        }

        // Discover characteristics for each service
        for service in services {
            if let cachedChar = service.characteristics, !cachedChar.isEmpty {
                // Characteristics already cached, process them
                processCharacteristicsForService(service)
            } else {
                // Need to discover characteristics
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    /// 处理单个服务的特征值发现。
    /// 如果需要描述符发现，则为每个特征值启动描述符发现流程；
    /// 否则直接构建 UniversalBleCharacteristic 列表并更新进度映射表。
    private func processCharacteristicsForService(_ service: CBService) {
        let serviceUuid = service.uuid.uuidString
        guard let characteristics = service.characteristics else {
            // Service has no characteristics, mark as complete
            expectedCharacteristicsCountMap[serviceUuid] = 0
            if let index = discoveredServicesProgressMap.firstIndex(where: { $0.uuid == serviceUuid }) {
                discoveredServicesProgressMap[index] = UniversalBleService(uuid: serviceUuid, characteristics: [])
            }
            checkForDiscoveryCompletion()
            return
        }

        // Store expected characteristic count for this service
        expectedCharacteristicsCountMap[serviceUuid] = characteristics.count

        // If no characteristics, mark service as complete
        if characteristics.isEmpty {
            if let index = discoveredServicesProgressMap.firstIndex(where: { $0.uuid == serviceUuid }) {
                discoveredServicesProgressMap[index] = UniversalBleService(uuid: serviceUuid, characteristics: [])
            }
            checkForDiscoveryCompletion()
            return
        }

        if withDescriptors {
            for characteristic in characteristics {
                if let cachedDescriptors = characteristic.descriptors, !cachedDescriptors.isEmpty {
                    handleDescriptorsDiscovered(for: characteristic)
                } else {
                    peripheral.discoverDescriptors(for: characteristic)
                }
            }
        } else {
            if let index = discoveredServicesProgressMap.firstIndex(where: { $0.uuid == serviceUuid }) {
                discoveredServicesProgressMap[index] = UniversalBleService(
                    uuid: serviceUuid,
                    characteristics: characteristics.map {
                        UniversalBleCharacteristic(
                            uuid: $0.uuid.uuidString,
                            properties: $0.properties.toCharacteristicProperty,
                            descriptors: []
                        )
                    }
                )
            }
            checkForDiscoveryCompletion()
        }
    }

    /// 处理描述符发现完成回调。
    /// 当服务的所有特征值的描述符都被发现后，更新该服务的进度条目为完整状态，
    /// 然后检查是否所有服务都已完成发现。
    private func handleDescriptorsDiscovered(for characteristic: CBCharacteristic) {
        guard let service = characteristic.service else {
            return
        }
        let serviceUuid = service.uuid.uuidString
        let characteristicUuid = characteristic.uuid.uuidString
        let characteristicKey = "\(serviceUuid):\(characteristicUuid)"

        // Mark this characteristic's descriptors as discovered
        discoveredDescriptorsSet.insert(characteristicKey)

        // Get expected characteristic count for this service
        guard let expectedCount = expectedCharacteristicsCountMap[serviceUuid] else {
            return
        }

        // Check if all characteristics for this service have had their descriptors discovered
        guard let allCharacteristics = service.characteristics else {
            return
        }

        let discoveredCount = allCharacteristics.filter { char in
            let key = "\(serviceUuid):\(char.uuid.uuidString)"
            return discoveredDescriptorsSet.contains(key)
        }.count

        // Only update the service when all characteristics have descriptors discovered
        if discoveredCount == expectedCount {
            var universalBleCharacteristicsList: [UniversalBleCharacteristic] = []
            for characteristic in allCharacteristics {
                universalBleCharacteristicsList.append(
                    UniversalBleCharacteristic(
                        uuid: characteristic.uuid.uuidString,
                        properties: characteristic.properties.toCharacteristicProperty,
                        descriptors: (characteristic.descriptors ?? []).map { UniversalBleDescriptor(uuid: $0.uuid.uuidString) }
                    )
                )
            }

            if let index = discoveredServicesProgressMap.firstIndex(where: { $0.uuid == serviceUuid }) {
                discoveredServicesProgressMap[index] = UniversalBleService(uuid: serviceUuid, characteristics: universalBleCharacteristicsList)
            }
            checkForDiscoveryCompletion()
        }
    }

    /// 检查是否所有服务都已完成发现。
    /// 判定条件：进度映射表中所有服务的 characteristics 不为 nil（即已完整发现）。
    /// 如果全部完成，调用 completion 回调并清理状态。
    private func checkForDiscoveryCompletion() {
        // Check if all services have been fully discovered (all characteristics with all descriptors)
        guard discoveredServicesProgressMap.allSatisfy({ $0.characteristics != nil }) else {
            return
        }
        completion(.success(discoveredServicesProgressMap))
        cleanup()
    }
}

// MARK: - 代理回调处理（由主插件类的 CBCentralManagerDelegate 转发调用）

extension PrinterConnectAsyncServiceDiscovery {
    /// 服务发现回调处理
    func handleDidDiscoverServices(_ peripheral: CBPeripheral, error: Error?) {
        guard error == nil else {
            completion(.failure(error!))
            cleanup()
            return
        }
        guard let services = peripheral.services else {
            completion(.success([]))
            cleanup()
            return
        }
        handleServicesDiscovered(services)
    }

    /// 特征值发现回调处理
    func handleDidDiscoverCharacteristicsFor(_: CBPeripheral, service: CBService, error: Error?) {
        guard error == nil else {
            completion(.failure(error!))
            cleanup()
            return
        }
        processCharacteristicsForService(service)
    }

    /// 描述符发现回调处理
    func handleDidDiscoverDescriptorsFor(_: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            completion(.failure(error!))
            cleanup()
            return
        }
        handleDescriptorsDiscovered(for: characteristic)
    }
}

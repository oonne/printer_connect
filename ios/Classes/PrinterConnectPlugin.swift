import CoreBluetooth

#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import AppKit
import FlutterMacOS
#endif

public class PrinterConnectPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let binaryMessenger = registrar.messenger()
        let callbackChannel = UniversalBleCallbackChannel(binaryMessenger: binaryMessenger)
        let api = BleCentralDarwin(callbackChannel: callbackChannel)
        UniversalBlePlatformChannelSetup.setUp(binaryMessenger: binaryMessenger, api: api)
        #if os(iOS)
        // When the host app declares `bluetooth-central`, build the manager during
        // launch so CoreBluetooth can deliver `willRestoreState:` after a background
        // relaunch (see activateStateRestoration).
        api.activateStateRestoration()
        #endif
    }
}

private var discoveredPeripherals = [String: CBPeripheral]()

// Cache last advertised local name for peripherals
// since iOS and MacOS don't do that for system devices
private var advertisementNameCache = [String: String]()

private class BleCentralDarwin: NSObject, UniversalBlePlatformChannel, CBCentralManagerDelegate, CBPeripheralDelegate {

    static let stateRestorationIdentifier = "com.printerconnect.central.restoration"

    #if os(iOS)
    private static let hasBluetoothCentralBackgroundMode: Bool = {
        guard let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] else {
            return false
        }
        return modes.contains("bluetooth-central")
    }()

    private static var hasBluetoothPermission: Bool {
        CBCentralManager.authorization == .allowedAlways
    }

    private static var availabilityStateFromAuthorization: AvailabilityState {
        switch CBCentralManager.authorization {
        case .restricted, .denied:
            return .unauthorized
        case .notDetermined:
            return .unknown
        default:
            return .unknown
        }
    }
    #endif

    var callbackChannel: UniversalBleCallbackChannel
    private let printerConnectFilterUtil = PrinterConnectFilterUtil()

    #if os(iOS)
    private lazy var manager: CBCentralManager = {
        if Self.hasBluetoothCentralBackgroundMode {
            return CBCentralManager(
                delegate: self,
                queue: nil,
                options: [CBCentralManagerOptionRestoreIdentifierKey: BleCentralDarwin.stateRestorationIdentifier]
            )
        }
        return CBCentralManager(delegate: self, queue: nil)
    }()
    #else
    private lazy var manager: CBCentralManager = .init(delegate: self, queue: nil)
    #endif

    private var availabilityStateUpdateHandlers: [(Result<AvailabilityState, Error>) -> Void] = []
    private var requestPermissionStateUpdateHandlers: [(Result<Void, Error>) -> Void] = []

    private var activeServiceDiscoveries: [String: PrinterConnectAsyncServiceDiscovery] = [:]

    private var characteristicReadFutures = [CharacteristicReadFuture]()
    private var characteristicWriteFutures = [CharacteristicWriteFuture]()
    private var characteristicWriteWithoutResponseFutures = [CharacteristicWriteFuture]()
    private var characteristicNotifyFutures = [CharacteristicNotifyFuture]()
    private var discoverServicesFutures = [DiscoverServicesFuture]()
    private var rssiReadFutures = [RssiReadFuture]()

    private var isManageScanning = false
    private var autoConnectDevices = Set<String>()

    private let logger = PrinterConnectLogger.shared

    init(callbackChannel: UniversalBleCallbackChannel) {
        self.callbackChannel = callbackChannel
        super.init()
    }

    #if os(iOS)
    func activateStateRestoration() {
        guard Self.hasBluetoothCentralBackgroundMode, Self.hasBluetoothPermission else { return }
        _ = manager
    }
    #endif

    func getBluetoothAvailabilityState(completion: @escaping (Result<AvailabilityState, Error>) -> Void) {
        #if os(iOS)
        if Self.hasBluetoothCentralBackgroundMode, !Self.hasBluetoothPermission {
            completion(.success(Self.availabilityStateFromAuthorization))
            return
        }
        #endif
        if manager.state != .unknown {
            completion(.success(manager.state.toAvailabilityState()))
        } else {
            availabilityStateUpdateHandlers.append(completion)
            _ = manager
        }
    }

    func hasPermissions(withAndroidFineLocation _: Bool) throws -> Bool {
        return CBCentralManager.authorization == .allowedAlways
    }

    func requestPermissions(withAndroidFineLocation _: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        if manager.state != .unknown {
            completePermissionRequest(completion: completion)
        } else {
            requestPermissionStateUpdateHandlers.append(completion)
            _ = manager
        }
    }

    private func completePermissionRequest(completion: @escaping (Result<Void, Error>) -> Void) {
        let state = manager.state
        switch state {
        case .unauthorized:
            completion(.failure(createFlutterError(code: .bluetoothUnauthorized, message: "Not authorized to access Bluetooth")))
        case .unsupported:
            completion(.failure(createFlutterError(code: .notSupported, message: "Bluetooth is not supported")))
        default:
            completion(.success(()))
        }
    }

    func enableBluetooth(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.failure(createFlutterError(code: .notSupported)))
    }

    func disableBluetooth(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.failure(createFlutterError(code: .notSupported)))
    }

    func startScan(filter: UniversalScanFilter?, config _: UniversalScanConfig?) throws {
        let usesCustomFilters = filter?.usesCustomFilters ?? false

        var withServices: [CBUUID] = try filter?.withServices.compactMap { CBUUID(string: $0) } ?? []

        if usesCustomFilters {
            logger.logInfo("Using Custom Filters")
            printerConnectFilterUtil.scanFilter = filter
            printerConnectFilterUtil.scanFilterServicesUUID = withServices
            withServices = []
        } else {
            printerConnectFilterUtil.scanFilter = nil
            printerConnectFilterUtil.scanFilterServicesUUID = []
        }

        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        manager.scanForPeripherals(withServices: withServices, options: options)
        isManageScanning = true
    }

    func stopScan() throws {
        manager.stopScan()
        isManageScanning = false
    }

    func isScanning() throws -> Bool {
        if CBCentralManager.authorization == .allowedAlways {
            return manager.isScanning
        }
        return isManageScanning
    }

    func setLogLevel(logLevel: BleLogLevel) throws {
        logger.setLogLevel(logLevel)
    }

    func connect(deviceId: String, autoConnect: Bool?, platformConfig: ConnectionPlatformConfig?) throws {
        let peripheral = try deviceId.getPeripheral(manager: manager)
        peripheral.delegate = self
        let shouldAutoConnect = autoConnect ?? false

        var options: [String: Any] = [:]

        if let appleOptions = platformConfig?.apple {
            if appleOptions.notifyOnConnection == true {
                options[CBConnectPeripheralOptionNotifyOnConnectionKey] = true
            }
            if appleOptions.notifyOnDisconnection == true {
                options[CBConnectPeripheralOptionNotifyOnDisconnectionKey] = true
            }
            if appleOptions.notifyOnNotification == true {
                options[CBConnectPeripheralOptionNotifyOnNotificationKey] = true
            }
        }

        if shouldAutoConnect {
            autoConnectDevices.insert(deviceId)
            if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
                options[CBConnectPeripheralOptionEnableAutoReconnect] = true
            } else {
                logger.logInfo(
                    "autoConnect requested for device \(deviceId), " +
                    "but automatic reconnection via CBConnectPeripheralOptionEnableAutoReconnect " +
                    "is only available on iOS 17+/macOS 14+/watchOS 10+/tvOS 17+. " +
                    "On this OS version, reconnections must be handled manually."
                )
            }
        } else {
            autoConnectDevices.remove(deviceId)
        }

        manager.connect(peripheral, options: options.isEmpty ? nil : options)
    }

    func disconnect(deviceId: String) throws {
        autoConnectDevices.remove(deviceId)

        guard let peripheral = deviceId.findPeripheral(manager: manager) else {
            callbackChannel.onConnectionChanged(deviceId: deviceId, connected: false, error: nil) { _ in }
            cleanUpConnection(deviceId: deviceId)
            return
        }

        if peripheral.state != .disconnected {
            manager.cancelPeripheralConnection(peripheral)
        }
        cleanUpConnection(deviceId: deviceId)
    }

    func getConnectionState(deviceId: String) throws -> BleConnectionState {
        guard let peripheral = deviceId.findPeripheral(manager: manager) else {
            return .disconnected
        }

        switch peripheral.state {
        case .disconnected: return .disconnected
        case .connecting: return .connecting
        case .connected: return .connected
        case .disconnecting: return .disconnecting
        @unknown default: return .disconnected
        }
    }

    private func cleanUpConnection(deviceId: String) {
        characteristicReadFutures.removeAll { future in
            if future.deviceId == deviceId {
                future.result(.failure(createFlutterError(code: .deviceDisconnected, message: "Device Disconnected")))
                return true
            }
            return false
        }

        characteristicWriteFutures.removeAll { future in
            if future.deviceId == deviceId {
                future.result(.failure(createFlutterError(code: .deviceDisconnected, message: "Device Disconnected")))
                return true
            }
            return false
        }

        characteristicNotifyFutures.removeAll { future in
            if future.deviceId == deviceId {
                future.result(.failure(createFlutterError(code: .deviceDisconnected, message: "Device Disconnected")))
                return true
            }
            return false
        }

        discoverServicesFutures.removeAll { future in
            if future.deviceId == deviceId {
                future.result(.failure(createFlutterError(code: .deviceDisconnected, message: "Device Disconnected")))
                return true
            }
            return false
        }

        rssiReadFutures.removeAll { future in
            if future.deviceId == deviceId {
                future.result(.failure(createFlutterError(code: .deviceDisconnected, message: "Device Disconnected")))
                return true
            }
            return false
        }

        activeServiceDiscoveries[deviceId]?.cleanup()
        activeServiceDiscoveries[deviceId] = nil
    }

    func discoverServices(deviceId: String, withDescriptors: Bool, completion: @escaping (Result<[UniversalBleService], Error>) -> Void) {
        guard let peripheral = deviceId.findPeripheral(manager: manager) else {
            completion(.failure(createFlutterError(code: .deviceNotFound, message: "Unknown deviceId:\(deviceId)")))
            return
        }

        if activeServiceDiscoveries[deviceId] != nil {
            logger.logWarning("Services discovery already in progress for:\(deviceId), waiting for completion.")
            discoverServicesFutures.append(DiscoverServicesFuture(deviceId: deviceId, result: completion))
            return
        }

        let wrappedCompletion: (Result<[UniversalBleService], Error>) -> Void = { result in
            completion(result)
            self.discoverServicesFutures.removeAll { future in
                if future.deviceId == deviceId {
                    future.result(result)
                    return true
                }
                return false
            }
            self.activeServiceDiscoveries[deviceId] = nil
        }

        let discovery = PrinterConnectAsyncServiceDiscovery(
            peripheral: peripheral,
            deviceId: deviceId,
            withDescriptors: withDescriptors,
            completion: wrappedCompletion
        )

        activeServiceDiscoveries[deviceId] = discovery
        discovery.startDiscovery()
    }

    func setNotifiable(deviceId: String, service: String, characteristic: String, bleInputProperty: BleInputProperty, completion: @escaping (Result<Void, Error>) -> Void) {
        logger.logDebug("SET_NOTIFY -> \(deviceId) \(service) \(characteristic) input=\(bleInputProperty)")

        guard let peripheral = deviceId.findPeripheral(manager: manager) else {
            completion(.failure(createFlutterError(code: .deviceNotFound, message: "Unknown deviceId:\(deviceId)")))
            return
        }

        guard let gattCharacteristic = peripheral.getCharacteristic(characteristic, of: service) else {
            completion(.failure(createFlutterError(code: .characteristicNotFound, message: "Unknown characteristic:\(characteristic)")))
            return
        }

        if bleInputProperty == .notification && !gattCharacteristic.properties.contains(.notify) {
            completion(.failure(createFlutterError(code: .characteristicDoesNotSupportNotify, message: "Characteristic does not support notify")))
            return
        }

        if bleInputProperty == .indication && !gattCharacteristic.properties.contains(.indicate) {
            completion(.failure(createFlutterError(code: .characteristicDoesNotSupportIndicate, message: "Characteristic does not support indicate")))
            return
        }

        let shouldNotify = bleInputProperty != .disabled
        peripheral.setNotifyValue(shouldNotify, for: gattCharacteristic)
        characteristicNotifyFutures.append(CharacteristicNotifyFuture(
            deviceId: deviceId,
            characteristicId: gattCharacteristic.uuid.uuidStr,
            serviceId: gattCharacteristic.service?.uuid.uuidStr,
            result: completion
        ))
    }

    func readValue(deviceId: String, service: String, characteristic: String, completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
        logger.logDebug("READ -> \(deviceId) \(service) \(characteristic)")

        guard let peripheral = deviceId.findPeripheral(manager: manager) else {
            completion(.failure(createFlutterError(code: .deviceNotFound, message: "Unknown deviceId:\(deviceId)")))
            return
        }

        guard let gattCharacteristic = peripheral.getCharacteristic(characteristic, of: service) else {
            completion(.failure(createFlutterError(code: .characteristicNotFound, message: "Unknown characteristic:\(characteristic)")))
            return
        }

        if !gattCharacteristic.properties.contains(.read) {
            completion(.failure(createFlutterError(code: .characteristicDoesNotSupportRead, message: "Characteristic does not support read")))
            return
        }

        peripheral.readValue(for: gattCharacteristic)
        characteristicReadFutures.append(CharacteristicReadFuture(
            deviceId: deviceId,
            characteristicId: gattCharacteristic.uuid.uuidStr,
            serviceId: gattCharacteristic.service?.uuid.uuidStr,
            result: completion
        ))
    }

    func requestMtu(deviceId: String, expectedMtu _: Int64, completion: @escaping (Result<Int64, Error>) -> Void) {
        logger.logDebug("REQUEST_MTU -> \(deviceId)")

        guard let peripheral = deviceId.findPeripheral(manager: manager) else {
            completion(.failure(createFlutterError(code: .deviceNotFound, message: "Unknown deviceId:\(deviceId)")))
            return
        }

        let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
        let GATT_HEADER_LENGTH = 3
        let mtuResult = Int64(mtu + GATT_HEADER_LENGTH)
        completion(.success(mtuResult))
    }

    func writeValue(deviceId: String, service: String, characteristic: String, value: FlutterStandardTypedData, bleOutputProperty: BleOutputProperty, completion: @escaping (Result<Void, Error>) -> Void) {
        logger.logDebug("WRITE -> \(deviceId) \(service) \(characteristic) len=\(value.data.count) property=\(bleOutputProperty)")

        guard let peripheral = deviceId.findPeripheral(manager: manager) else {
            completion(.failure(createFlutterError(code: .deviceNotFound, message: "Unknown deviceId:\(deviceId)")))
            return
        }

        guard let gattCharacteristic = peripheral.getCharacteristic(characteristic, of: service) else {
            completion(.failure(createFlutterError(code: .characteristicNotFound, message: "Unknown characteristic:\(characteristic)")))
            return
        }

        let type = bleOutputProperty == .withoutResponse ? CBCharacteristicWriteType.withoutResponse : CBCharacteristicWriteType.withResponse

        if type == .withResponse {
            if !gattCharacteristic.properties.contains(.write) {
                completion(.failure(createFlutterError(code: .characteristicDoesNotSupportWrite, message: "Characteristic does not support write withResponse")))
                return
            }
        } else if type == .withoutResponse {
            if !gattCharacteristic.properties.contains(.writeWithoutResponse) {
                completion(.failure(createFlutterError(code: .characteristicDoesNotSupportWriteWithoutResponse, message: "Characteristic does not support write withoutResponse")))
                return
            }
        }

        peripheral.writeValue(value.data, for: gattCharacteristic, type: type)

        let future = CharacteristicWriteFuture(
            deviceId: deviceId,
            characteristicId: gattCharacteristic.uuid.uuidStr,
            serviceId: gattCharacteristic.service?.uuid.uuidStr,
            result: completion
        )

        if type == .withResponse {
            characteristicWriteFutures.append(future)
        } else {
            characteristicWriteWithoutResponseFutures.append(future)
        }
    }

    func isPaired(deviceId _: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.failure(createFlutterError(code: .notSupported)))
    }

    func pair(deviceId _: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.failure(createFlutterError(code: .notImplemented)))
    }

    func unPair(deviceId _: String) throws {
        throw createFlutterError(code: .notSupported)
    }

    func getSystemDevices(withServices: [String], completion: @escaping (Result<[UniversalBleScanResult], Error>) -> Void) {
        var servicesFilter = withServices
        if servicesFilter.isEmpty {
            logger.logInfo("No services filter was set for getting system connected devices. Using default services...")
            servicesFilter = ["1800", "1801", "180A", "180D", "1810", "181B", "1808", "181D", "1816", "1814", "181A", "1802", "1803", "1804", "1815", "1805", "1807", "1806", "1848", "185E", "180F", "1812", "180E", "1813"]
        }
        let filterCBUUID = servicesFilter.map { CBUUID(string: $0) }
        let bleDevices = manager.retrieveConnectedPeripherals(withServices: filterCBUUID)
        bleDevices.forEach { $0.saveCache() }
        completion(.success(bleDevices.map { peripheral in
            let id = peripheral.uuid.uuidString
            let name = advertisementNameCache[id] ?? discoveredPeripherals[id]?.name ?? peripheral.name ?? ""
            return UniversalBleScanResult(
                deviceId: id,
                name: name,
                serviceData: nil,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000)
            )
        }))
    }

    func readRssi(deviceId: String, completion: @escaping (Result<Int64, Error>) -> Void) {
        logger.logDebug("READ_RSSI -> \(deviceId)")

        guard let peripheral = deviceId.findPeripheral(manager: manager) else {
            completion(.failure(createFlutterError(code: .deviceNotFound, message: "Unknown deviceId:\(deviceId)")))
            return
        }

        peripheral.readRSSI()
        rssiReadFutures.append(RssiReadFuture(deviceId: deviceId, result: completion))
    }

    func requestConnectionPriority(deviceId _: String, priority _: BleConnectionPriority, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.failure(createFlutterError(code: .notSupported, message: "requestConnectionPriority is not supported on Apple platforms")))
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state.toAvailabilityState()
        callbackChannel.onAvailabilityChanged(state: state) { _ in }

        availabilityStateUpdateHandlers.removeAll { handler in
            handler(.success(state))
            return true
        }

        requestPermissionStateUpdateHandlers.removeAll { handler in
            completePermissionRequest(completion: handler)
            return true
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        peripheral.saveCache()

        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        let serviceDataDict = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]

        var manufacturerDataList: [UniversalManufacturerData] = []
        var universalManufacturerData: UniversalManufacturerData? = nil

        if let msd = manufacturerData, msd.count > 2 {
            let companyIdentifier = msd.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self) }
            let data = FlutterStandardTypedData(bytes: msd.suffix(from: 2))
            universalManufacturerData = UniversalManufacturerData(companyIdentifier: Int64(companyIdentifier), data: data)
            manufacturerDataList.append(universalManufacturerData!)
        }

        var serviceData: [String: FlutterStandardTypedData]? = nil
        if let serviceDataDict = serviceDataDict {
            serviceData = Dictionary(uniqueKeysWithValues: serviceDataDict.map { uuid, data in
                (uuid.uuidStr, FlutterStandardTypedData(bytes: data))
            })
        }

        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let displayName = advertisedName ?? peripheral.name
        advertisementNameCache[peripheral.uuid.uuidString] = displayName

        if !printerConnectFilterUtil.filterDevice(name: displayName, manufacturerData: universalManufacturerData, services: services) {
            return
        }

        callbackChannel.onScanResult(result: UniversalBleScanResult(
            deviceId: peripheral.uuid.uuidString,
            name: displayName,
            isPaired: nil,
            rssi: RSSI.int64Value,
            manufacturerDataList: manufacturerDataList,
            serviceData: serviceData,
            services: services?.map { $0.uuidStr },
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )) { _ in }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        callbackChannel.onConnectionChanged(deviceId: peripheral.uuid.uuidString, connected: true, error: nil) { _ in }
    }

    private func handlePeripheralDisconnection(deviceId: String, error: Error?) {
        autoConnectDevices.remove(deviceId)
        callbackChannel.onConnectionChanged(deviceId: deviceId, connected: false, error: error?.localizedDescription) { _ in }
        cleanUpConnection(deviceId: deviceId)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        callbackChannel.onConnectionChanged(deviceId: peripheral.uuid.uuidString, connected: false, error: error?.localizedDescription) { _ in }
        cleanUpConnection(deviceId: peripheral.uuid.uuidString)
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: Error?) {
        let deviceId = peripheral.uuid.uuidString
        if isReconnecting {
            return
        }
        handlePeripheralDisconnection(deviceId: deviceId, error: error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let deviceId = peripheral.uuid.uuidString
        handlePeripheralDisconnection(deviceId: deviceId, error: error)
    }

    #if os(iOS)
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        logger.logInfo("Central manager will restore state")

        guard let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] else {
            return
        }

        for peripheral in peripherals {
            peripheral.delegate = self
            peripheral.saveCache()
            let deviceId = peripheral.uuid.uuidString
            if peripheral.state == .connected {
                callbackChannel.onConnectionChanged(deviceId: deviceId, connected: true, error: nil) { _ in }
            }
        }
    }
    #endif

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        activeServiceDiscoveries[peripheral.uuid.uuidString]?.handleDidDiscoverServices(peripheral, error: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        activeServiceDiscoveries[peripheral.uuid.uuidString]?.handleDidDiscoverCharacteristicsFor(peripheral, service: service, error: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        activeServiceDiscoveries[peripheral.uuid.uuidString]?.handleDidDiscoverDescriptorsFor(peripheral, characteristic: characteristic, error: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.uuid.uuidString
        let characteristicId = characteristic.uuid.uuidStr
        let serviceId = characteristic.service?.uuid.uuidStr ?? ""

        let isReadOperation = characteristicReadFutures.contains { future in
            future.deviceId == peripheralId && future.characteristicId == characteristicId && future.serviceId == serviceId
        }

        if let error = error {
            if isReadOperation {
                // This is a read error, handled below
            } else {
                logger.logError("NOTIFY_ERROR <- \(peripheralId) \(characteristicId): \(error.localizedDescription)")
            }
        }

        if characteristic.isNotifying, let characteristicValue = characteristic.value {
            let preview = characteristicValue.prefix(8).map { String(format: "%02X", $0) }.joined()
            logger.logDebug("NOTIFY <- \(peripheralId) \(characteristicId) len=\(characteristicValue.count) data=\(preview)")

            callbackChannel.onValueChanged(
                deviceId: peripheralId,
                characteristicId: characteristicId,
                value: FlutterStandardTypedData(bytes: characteristicValue),
                timestamp: Int64(Date().timeIntervalSince1970 * 1000)
            ) { _ in }
        }

        if characteristicReadFutures.count == 0 {
            return
        }

        characteristicReadFutures.removeAll { future in
            if future.deviceId == peripheralId && future.characteristicId == characteristicId && future.serviceId == serviceId {
                if let flutterError = error?.toFlutterError() {
                    logger.logError("READ_FAILED <- \(peripheralId) \(characteristicId): \(flutterError.message ?? "")")
                    future.result(.failure(flutterError))
                } else {
                    if let value = characteristic.value {
                        future.result(.success(FlutterStandardTypedData(bytes: value)))
                    } else {
                        future.result(.failure(createFlutterError(code: .readFailed, message: "No value")))
                    }
                }
                return true
            }
            return false
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.uuid.uuidString
        let characteristicId = characteristic.uuid.uuidStr
        let serviceId = characteristic.service?.uuid.uuidStr ?? ""

        characteristicWriteFutures.removeAll { future in
            if future.deviceId == peripheralId && future.characteristicId == characteristicId && future.serviceId == serviceId {
                if let flutterError = error?.toFlutterError() {
                    logger.logError("WRITE_FAILED <- \(peripheralId) \(characteristicId): \(flutterError.message ?? "")")
                    future.result(.failure(flutterError))
                } else {
                    future.result(.success(()))
                }
                return true
            }
            return false
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.uuid.uuidString
        let characteristicId = characteristic.uuid.uuidStr
        let serviceId = characteristic.service?.uuid.uuidStr ?? ""

        characteristicNotifyFutures.removeAll { future in
            if future.deviceId == peripheralId && future.characteristicId == characteristicId && future.serviceId == serviceId {
                if let flutterError = error?.toFlutterError() {
                    logger.logError("SET_NOTIFY_FAILED <- \(peripheralId) \(characteristicId): \(flutterError.message ?? "")")
                    future.result(.failure(flutterError))
                } else {
                    future.result(.success(()))
                }
                return true
            }
            return false
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        let peripheralId = peripheral.uuid.uuidString

        rssiReadFutures.removeAll { future in
            if future.deviceId == peripheralId {
                if let flutterError = error?.toFlutterError() {
                    logger.logError("READ_RSSI_FAILED <- \(peripheralId): \(flutterError.message ?? "")")
                    future.result(.failure(flutterError))
                } else {
                    future.result(.success(RSSI.int64Value))
                }
                return true
            }
            return false
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        let peripheralId = peripheral.uuid.uuidString

        characteristicWriteWithoutResponseFutures.removeAll { future in
            if future.deviceId == peripheralId {
                future.result(.success(()))
                return true
            }
            return false
        }
    }

    #if os(iOS)
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        logger.logInfo("Peripheral \(peripheral.uuid) modified services")
    }

    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        logger.logInfo("Peripheral name updated: \(peripheral.uuid)")
    }

    func peripheral(_ peripheral: CBPeripheral, didReadMaximumWriteValueLengthFor maximumWriteValueLength: Int) {
        logger.logDebug("Maximum write value length: \(maximumWriteValueLength)")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateConnectionParameters parameters: CBConnectionParameters) {
        let peripheralId = peripheral.uuid.uuidString
        logger.logDebug("Connection parameters updated for \(peripheralId): interval=\(parameters.interval), latency=\(parameters.latency), supervisionTimeout=\(parameters.supervisionTimeout)")

        let updated = BleConnectionParametersUpdated(
            deviceId: peripheralId,
            interval: Int64(parameters.interval),
            latency: Int64(parameters.latency),
            supervisionTimeout: Int64(parameters.supervisionTimeout),
            status: 0
        )
        callbackChannel.onConnectionParametersUpdated(update: updated) { _ in }
    }
    #endif

    func peripheral(_ peripheral: CBPeripheral, didUpdateMTU mtu: Int) {
        let peripheralId = peripheral.uuid.uuidString

        let updated = BleConnectionParametersUpdated(
            deviceId: peripheralId,
            interval: 0,
            latency: 0,
            supervisionTimeout: 0,
            status: Int64(mtu)
        )
        callbackChannel.onConnectionParametersUpdated(update: updated) { _ in }
    }
}

extension CBPeripheral {
    func saveCache() {
        discoveredPeripherals[uuid.uuidString] = self
    }
}

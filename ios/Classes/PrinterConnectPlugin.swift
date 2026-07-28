import Flutter
import CoreBluetooth

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public class PrinterConnectPlugin: NSObject, FlutterPlugin {

    private var bleCentral: BleCentralDarwin?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PrinterConnectPlugin()
        instance.setup(with: registrar)
    }

    private func setup(with registrar: FlutterPluginRegistrar) {
        let binaryMessenger = registrar.messenger()
        let central = BleCentralDarwin()
        bleCentral = central

        let callbackChannel = UniversalBleCallbackChannel(binaryMessenger: binaryMessenger)
        central.setupCallbackChannels(callbackChannel: callbackChannel)

        UniversalBlePlatformChannelSetup.setUp(binaryMessenger: binaryMessenger, api: central)

        #if os(iOS)
        central.activateStateRestoration()
        #endif
    }
}

private var discoveredPeripherals = [String: CBPeripheral]()
private var advertisementNameCache = [String: String]()

class BleCentralDarwin: NSObject, UniversalBlePlatformChannel, CBCentralManagerDelegate, CBPeripheralDelegate {

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

    var callbackChannel: UniversalBleCallbackChannel?
    private let logger = PrinterConnectLogger.shared
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

    override init() {
        super.init()
    }

    func setupCallbackChannels(callbackChannel: UniversalBleCallbackChannel) {
        self.callbackChannel = callbackChannel
    }

    #if os(iOS)
    func activateStateRestoration() {
        guard Self.hasBluetoothCentralBackgroundMode, Self.hasBluetoothPermission else { return }
        _ = manager
    }
    #endif

    private func saveCache(_ peripheral: CBPeripheral) {
        discoveredPeripherals[peripheral.uuid] = peripheral
    }

    private func getPeripheral(_ peripheralId: String) -> CBPeripheral? {
        if let peripheral = discoveredPeripherals[peripheralId] {
            return peripheral
        }
        if let uuid = UUID(uuidString: peripheralId) {
            let peripherals = manager.retrievePeripherals(withIdentifiers: [uuid])
            if let peripheral = peripherals.first {
                saveCache(peripheral)
                return peripheral
            }
        }
        return nil
    }

    private func findPeripheral(_ peripheralId: String) -> CBPeripheral? {
        return getPeripheral(peripheralId)
    }

    private func sendAvailabilityChanged(_ state: AvailabilityState) {
        callbackChannel?.onAvailabilityChanged(state: state) { _ in }
    }

    private func sendScanResult(_ result: UniversalBleScanResult) {
        callbackChannel?.onScanResult(result: result) { _ in }
    }

    private func sendValueChanged(deviceId: String, characteristicId: String, value: FlutterStandardTypedData, timestamp: Int64?) {
        callbackChannel?.onValueChanged(deviceId: deviceId, characteristicId: characteristicId, value: value, timestamp: timestamp) { _ in }
    }

    private func sendConnectionChanged(deviceId: String, connected: Bool, error: String?) {
        callbackChannel?.onConnectionChanged(deviceId: deviceId, connected: connected, error: error) { _ in }
    }

    private func sendConnectionParametersUpdated(_ result: BleConnectionParametersUpdated) {
        callbackChannel?.onConnectionParametersUpdated(update: result) { _ in }
    }

    func getBluetoothAvailabilityState(completion: @escaping (Result<AvailabilityState, Error>) -> Void) {
        #if os(iOS)
        if Self.hasBluetoothCentralBackgroundMode, !Self.hasBluetoothPermission {
            completion(.success(Self.availabilityStateFromAuthorization))
            return
        }
        #endif
        if manager.state != .unknown {
            completion(.success(manager.state.toAvailabilityState))
        } else {
            availabilityStateUpdateHandlers.append(completion)
            _ = manager
        }
    }

    func hasPermissions(withAndroidFineLocation: Bool) throws -> Bool {
        return CBCentralManager.authorization == .allowedAlways
    }

    func requestPermissions(withAndroidFineLocation: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
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
            completion(.failure(createFlutterError(code: "bluetoothUnauthorized", message: "Not authorized to access Bluetooth")))
        case .unsupported:
            completion(.failure(createFlutterError(code: "notSupported", message: "Bluetooth is not supported")))
        default:
            completion(.success(()))
        }
    }

    func enableBluetooth(completion: @escaping (Result<Bool, Error>) -> Void) {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            completion(.failure(createFlutterError(code: "settingsError", message: "Unable to open settings")))
            return
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #endif
        completion(.success(true))
    }

    func disableBluetooth(completion: @escaping (Result<Bool, Error>) -> Void) {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            completion(.failure(createFlutterError(code: "settingsError", message: "Unable to open settings")))
            return
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #endif
        completion(.success(true))
    }

    func startScan(filter: UniversalScanFilter?, config: UniversalScanConfig?) throws {
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
        manager.scanForPeripherals(withServices: withServices.isEmpty ? nil : withServices, options: options)
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

    func connect(deviceId: String, autoConnect: Bool?, platformConfig: ConnectionPlatformConfig?) throws {
        guard let peripheral = findPeripheral(deviceId) else {
            throw createFlutterError(code: "deviceNotFound", message: "Unknown deviceId:\(deviceId)")
        }

        peripheral.delegate = self

        let shouldAutoConnect = autoConnect ?? false
        var options: [String: Any] = [:]

        #if os(iOS)
        if let appleOptions = platformConfig?.apple {
            if let notifyOnConnection = appleOptions.notifyOnConnection, notifyOnConnection {
                options[CBConnectPeripheralOptionNotifyOnConnectionKey] = true
            }
            if let notifyOnDisconnection = appleOptions.notifyOnDisconnection, notifyOnDisconnection {
                options[CBConnectPeripheralOptionNotifyOnDisconnectionKey] = true
            }
            if let notifyOnNotification = appleOptions.notifyOnNotification, notifyOnNotification {
                options[CBConnectPeripheralOptionNotifyOnNotificationKey] = true
            }
        }

        if shouldAutoConnect {
            autoConnectDevices.insert(deviceId)
            if #available(iOS 17.0, *) {
                options[CBConnectPeripheralOptionEnableAutoReconnect] = true
            } else {
                logger.logInfo("autoConnect requested for device \(deviceId), but automatic reconnection via CBConnectPeripheralOptionEnableAutoReconnect is only available on iOS 17+. On this OS version, reconnections must be handled manually.")
            }
        } else {
            autoConnectDevices.remove(deviceId)
        }
        #elseif os(macOS)
        if let appleOptions = platformConfig?.apple {
            if let notifyOnConnection = appleOptions.notifyOnConnection, notifyOnConnection {
                options[CBConnectPeripheralOptionNotifyOnConnectionKey] = true
            }
            if let notifyOnDisconnection = appleOptions.notifyOnDisconnection, notifyOnDisconnection {
                options[CBConnectPeripheralOptionNotifyOnDisconnectionKey] = true
            }
            if let notifyOnNotification = appleOptions.notifyOnNotification, notifyOnNotification {
                options[CBConnectPeripheralOptionNotifyOnNotificationKey] = true
            }
        }

        if shouldAutoConnect {
            autoConnectDevices.insert(deviceId)
            if #available(macOS 14.0, *) {
                options[CBConnectPeripheralOptionEnableAutoReconnect] = true
            } else {
                logger.logInfo("autoConnect requested for device \(deviceId), but automatic reconnection via CBConnectPeripheralOptionEnableAutoReconnect is only available on macOS 14+. On this OS version, reconnections must be handled manually.")
            }
        } else {
            autoConnectDevices.remove(deviceId)
        }
        #endif

        manager.connect(peripheral, options: options.isEmpty ? nil : options)
    }

    func disconnect(deviceId: String) throws {
        autoConnectDevices.remove(deviceId)

        guard let peripheral = findPeripheral(deviceId) else {
            sendConnectionChanged(deviceId: deviceId, connected: false, error: nil)
            cleanUpConnection(deviceId: deviceId)
            return
        }

        if peripheral.state != .disconnected {
            manager.cancelPeripheralConnection(peripheral)
        }
        cleanUpConnection(deviceId: deviceId)
    }

    private func cleanUpConnection(deviceId: String) {
        characteristicReadFutures.removeAll { future in
            if future.deviceId == deviceId {
                future.result(.failure(createFlutterError(code: "deviceDisconnected", message: "Device Disconnected")))
                return true
            }
            return false
        }

        characteristicWriteFutures.removeAll { future in
            if future.deviceId == deviceId {
                future.result(.failure(createFlutterError(code: "deviceDisconnected", message: "Device Disconnected")))
                return true
            }
            return false
        }

        characteristicNotifyFutures.removeAll { future in
            if future.deviceId == deviceId {
                future.result(.failure(createFlutterError(code: "deviceDisconnected", message: "Device Disconnected")))
                return true
            }
            return false
        }

        discoverServicesFutures.removeAll { future in
            if future.deviceId == deviceId {
                future.result(.failure(createFlutterError(code: "deviceDisconnected", message: "Device Disconnected")))
                return true
            }
            return false
        }

        rssiReadFutures.removeAll { future in
            if future.deviceId == deviceId {
                future.result(.failure(createFlutterError(code: "deviceDisconnected", message: "Device Disconnected")))
                return true
            }
            return false
        }

        activeServiceDiscoveries[deviceId]?.cleanup()
        activeServiceDiscoveries[deviceId] = nil
    }

    func setNotifiable(deviceId: String, service: String, characteristic: String, bleInputProperty: BleInputProperty, completion: @escaping (Result<Void, Error>) -> Void) {
        logger.logDebug("SET_NOTIFY -> \(deviceId) \(service) \(characteristic) input=\(bleInputProperty)")

        guard let peripheral = findPeripheral(deviceId) else {
            completion(.failure(createFlutterError(code: "deviceNotFound", message: "Unknown deviceId:\(deviceId)")))
            return
        }

        guard let gattCharacteristic = peripheral.getCharacteristic(characteristic, of: service) else {
            completion(.failure(createFlutterError(code: "characteristicNotFound", message: "Unknown characteristic:\(characteristic)")))
            return
        }

        if bleInputProperty == .notification && !gattCharacteristic.properties.contains(.notify) {
            completion(.failure(createFlutterError(code: "characteristicDoesNotSupportNotify", message: "Characteristic does not support notify")))
            return
        }

        if bleInputProperty == .indication && !gattCharacteristic.properties.contains(.indicate) {
            completion(.failure(createFlutterError(code: "characteristicDoesNotSupportIndicate", message: "Characteristic does not support indicate")))
            return
        }

        let shouldNotify = bleInputProperty != .disabled
        peripheral.setNotifyValue(shouldNotify, for: gattCharacteristic)
        characteristicNotifyFutures.append(CharacteristicNotifyFuture(
            deviceId: deviceId,
            characteristicId: gattCharacteristic.uuid.uuidStr,
            serviceId: gattCharacteristic.service?.uuid.uuidStr ?? "",
            result: completion
        ))
    }

    func discoverServices(deviceId: String, withDescriptors: Bool, completion: @escaping (Result<[UniversalBleService], Error>) -> Void) {
        guard let peripheral = findPeripheral(deviceId) else {
            completion(.failure(createFlutterError(code: "deviceNotFound", message: "Unknown deviceId:\(deviceId)")))
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

    func readValue(deviceId: String, service: String, characteristic: String, completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
        logger.logDebug("READ -> \(deviceId) \(service) \(characteristic)")

        guard let peripheral = findPeripheral(deviceId) else {
            completion(.failure(createFlutterError(code: "deviceNotFound", message: "Unknown deviceId:\(deviceId)")))
            return
        }

        guard let gattCharacteristic = peripheral.getCharacteristic(characteristic, of: service) else {
            completion(.failure(createFlutterError(code: "characteristicNotFound", message: "Unknown characteristic:\(characteristic)")))
            return
        }

        if !gattCharacteristic.properties.contains(.read) {
            completion(.failure(createFlutterError(code: "characteristicDoesNotSupportRead", message: "Characteristic does not support read")))
            return
        }

        peripheral.readValue(for: gattCharacteristic)
        characteristicReadFutures.append(CharacteristicReadFuture(
            deviceId: deviceId,
            characteristicId: gattCharacteristic.uuid.uuidStr,
            serviceId: gattCharacteristic.service?.uuid.uuidStr ?? "",
            result: completion
        ))
    }

    func requestMtu(deviceId: String, expectedMtu: Int64, completion: @escaping (Result<Int64, Error>) -> Void) {
        logger.logDebug("REQUEST_MTU -> \(deviceId)")

        guard let peripheral = findPeripheral(deviceId) else {
            completion(.failure(createFlutterError(code: "deviceNotFound", message: "Unknown deviceId:\(deviceId)")))
            return
        }

        #if os(iOS)
        guard #available(iOS 13.0, *) else {
            completion(.failure(createFlutterError(code: "notSupported", message: "requestMtu requires iOS 13+")))
            return
        }
        let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
        let mtuResult = Int64(mtu + 3)
        completion(.success(mtuResult))
        #elseif os(macOS)
        let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
        let mtuResult = Int64(mtu + 3)
        completion(.success(mtuResult))
        #endif
    }

    func writeValue(deviceId: String, service: String, characteristic: String, value: FlutterStandardTypedData, bleOutputProperty: BleOutputProperty, completion: @escaping (Result<Void, Error>) -> Void) {
        logger.logDebug("WRITE -> \(deviceId) \(service) \(characteristic) len=\(value.data.count) property=\(bleOutputProperty)")

        guard let peripheral = findPeripheral(deviceId) else {
            completion(.failure(createFlutterError(code: "deviceNotFound", message: "Unknown deviceId:\(deviceId)")))
            return
        }

        guard let gattCharacteristic = peripheral.getCharacteristic(characteristic, of: service) else {
            completion(.failure(createFlutterError(code: "characteristicNotFound", message: "Unknown characteristic:\(characteristic)")))
            return
        }

        let type: CBCharacteristicWriteType
        switch bleOutputProperty {
        case .withResponse:
            type = .withResponse
        case .withoutResponse:
            type = .withoutResponse
        }

        if type == .withResponse {
            if !gattCharacteristic.properties.contains(.write) {
                completion(.failure(createFlutterError(code: "characteristicDoesNotSupportWrite", message: "Characteristic does not support write withResponse")))
                return
            }
        } else {
            if !gattCharacteristic.properties.contains(.writeWithoutResponse) {
                completion(.failure(createFlutterError(code: "characteristicDoesNotSupportWriteWithoutResponse", message: "Characteristic does not support write withoutResponse")))
                return
            }
        }

        peripheral.writeValue(value.data, for: gattCharacteristic, type: type)

        let future = CharacteristicWriteFuture(
            deviceId: deviceId,
            characteristicId: gattCharacteristic.uuid.uuidStr,
            serviceId: gattCharacteristic.service?.uuid.uuidStr ?? "",
            result: completion
        )

        if type == .withResponse {
            characteristicWriteFutures.append(future)
        } else {
            characteristicWriteWithoutResponseFutures.append(future)
        }
    }

    func isPaired(deviceId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let peripheral = findPeripheral(deviceId) else {
            completion(.failure(createFlutterError(code: "deviceNotFound", message: "Unknown deviceId:\(deviceId)")))
            return
        }
        completion(.success(peripheral.state == .connected))
    }

    func pair(deviceId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func unPair(deviceId: String) throws {
        guard let peripheral = findPeripheral(deviceId) else {
            throw createFlutterError(code: "deviceNotFound", message: "Unknown deviceId:\(deviceId)")
        }

        if peripheral.state == .connected {
            autoConnectDevices.remove(deviceId)
            manager.cancelPeripheralConnection(peripheral)
        }
    }

    func getSystemDevices(withServices: [String], completion: @escaping (Result<[UniversalBleScanResult], Error>) -> Void) {
        let services = withServices.compactMap { CBUUID(string: $0) }
        let connected = manager.retrieveConnectedPeripherals(withServices: services.isEmpty ? nil : services)
        var results: [UniversalBleScanResult] = []

        for peripheral in connected {
            saveCache(peripheral)
            let id = peripheral.uuid
            let name = advertisementNameCache[id] ?? discoveredPeripherals[id]?.name ?? peripheral.name ?? ""
            let result = UniversalBleScanResult(
                deviceId: id,
                name: name,
                isPaired: nil,
                rssi: 0,
                manufacturerDataList: nil,
                serviceData: nil,
                services: withServices,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000)
            )
            results.append(result)
        }

        completion(.success(results))
    }

    func getConnectionState(deviceId: String) throws -> BleConnectionState {
        guard let peripheral = findPeripheral(deviceId) else {
            throw createFlutterError(code: "deviceNotFound", message: "Unknown deviceId:\(deviceId)")
        }

        switch peripheral.state {
        case .disconnected: return .disconnected
        case .connecting: return .connecting
        case .connected: return .connected
        case .disconnecting: return .disconnecting
        @unknown default: return .disconnected
        }
    }

    func readRssi(deviceId: String, completion: @escaping (Result<Int64, Error>) -> Void) {
        logger.logDebug("READ_RSSI -> \(deviceId)")

        guard let peripheral = findPeripheral(deviceId) else {
            completion(.failure(createFlutterError(code: "deviceNotFound", message: "Unknown deviceId:\(deviceId)")))
            return
        }

        peripheral.readRSSI()
        rssiReadFutures.append(RssiReadFuture(deviceId: deviceId, result: completion))
    }

    func requestConnectionPriority(deviceId: String, priority: BleConnectionPriority, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let peripheral = findPeripheral(deviceId) else {
            completion(.failure(createFlutterError(code: "deviceNotFound", message: "Unknown deviceId:\(deviceId)")))
            return
        }

        #if os(iOS)
        guard #available(iOS 13.0, *) else {
            completion(.failure(createFlutterError(code: "notSupported", message: "requestConnectionPriority requires iOS 13+")))
            return
        }

        let priorityValue: CBConnectionPriority
        switch priority {
        case .balanced:
            priorityValue = .balanced
        case .highPerformance:
            priorityValue = .high
        case .lowPower:
            priorityValue = .low
        }

        peripheral.requestConnectionPriority(priorityValue)
        completion(.success(()))
        #elseif os(macOS)
        completion(.failure(createFlutterError(code: "notSupported", message: "requestConnectionPriority is not supported on macOS")))
        #endif
    }

    func setLogLevel(logLevel: BleLogLevel) throws {
        logger.setLogLevel(logLevel)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state.toAvailabilityState
        sendAvailabilityChanged(state)

        availabilityStateUpdateHandlers.removeAll { handler in
            handler(.success(state))
            return true
        }

        requestPermissionStateUpdateHandlers.removeAll { handler in
            completePermissionRequest(completion: handler)
            return true
        }

        switch state {
        case .poweredOn:
            logger.logInfo("Bluetooth powered on")
        case .poweredOff:
            logger.logWarning("Bluetooth powered off")
        case .unauthorized:
            logger.logError("Bluetooth unauthorized")
        case .unsupported:
            logger.logError("Bluetooth unsupported")
        case .resetting:
            logger.logWarning("Bluetooth resetting")
        case .unknown:
            logger.logWarning("Bluetooth unknown")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        saveCache(peripheral)

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
        advertisementNameCache[peripheral.uuid] = displayName

        if !printerConnectFilterUtil.filterDevice(name: displayName, manufacturerData: universalManufacturerData, services: services) {
            return
        }

        callbackChannel?.onScanResult(result: UniversalBleScanResult(
            deviceId: peripheral.uuid,
            name: displayName,
            isPaired: nil,
            rssi: RSSI.int64Value,
            manufacturerDataList: manufacturerDataList.isEmpty ? nil : manufacturerDataList,
            serviceData: serviceData,
            services: services?.map { $0.uuidStr },
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )) { _ in }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let peripheralId = peripheral.uuid
        saveCache(peripheral)
        peripheral.delegate = self
        sendConnectionChanged(deviceId: peripheralId, connected: true, error: nil)
    }

    private func handlePeripheralDisconnection(deviceId: String, error: Error?) {
        autoConnectDevices.remove(deviceId)
        sendConnectionChanged(deviceId: deviceId, connected: false, error: error?.localizedDescription)
        cleanUpConnection(deviceId: deviceId)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let peripheralId = peripheral.uuid
        sendConnectionChanged(deviceId: peripheralId, connected: false, error: error?.localizedDescription)
        cleanUpConnection(deviceId: peripheralId)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let peripheralId = peripheral.uuid
        handlePeripheralDisconnection(deviceId: peripheralId, error: error)
    }

    #if os(iOS)
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        logger.logInfo("Central manager will restore state")

        guard let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] else {
            return
        }

        for peripheral in peripherals {
            peripheral.delegate = self
            saveCache(peripheral)
            let deviceId = peripheral.uuid
            if peripheral.state == .connected {
                sendConnectionChanged(deviceId: deviceId, connected: true, error: nil)
            }
        }
    }
    #endif

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let peripheralId = peripheral.uuid

        if let error = error {
            logger.logError("Error discovering services: \(error.localizedDescription)")
            if let discovery = activeServiceDiscoveries[peripheralId] {
                discovery.cleanup()
            }
            activeServiceDiscoveries.removeValue(forKey: peripheralId)
            discoverServicesFutures.removeAll { future in
                if future.deviceId == peripheralId {
                    future.result(.failure(error))
                    return true
                }
                return false
            }
            return
        }

        activeServiceDiscoveries[peripheralId]?.handleDidDiscoverServices(peripheral, error: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let peripheralId = peripheral.uuid

        if let error = error {
            logger.logError("Error discovering characteristics: \(error.localizedDescription)")
            if let discovery = activeServiceDiscoveries[peripheralId] {
                discovery.cleanup()
            }
            activeServiceDiscoveries.removeValue(forKey: peripheralId)
            discoverServicesFutures.removeAll { future in
                if future.deviceId == peripheralId {
                    future.result(.failure(error))
                    return true
                }
                return false
            }
            return
        }

        activeServiceDiscoveries[peripheralId]?.handleDidDiscoverCharacteristicsFor(peripheral, service: service, error: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.uuid

        activeServiceDiscoveries[peripheralId]?.handleDidDiscoverDescriptorsFor(peripheral, characteristic: characteristic, error: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.uuid
        let characteristicId = characteristic.uuid.uuidStr
        let serviceId = characteristic.service?.uuid.uuidStr ?? ""

        let isReadOperation = characteristicReadFutures.contains { future in
            future.deviceId == peripheralId && future.characteristicId == characteristicId && future.serviceId == serviceId
        }

        if let error = error {
            if isReadOperation {
                characteristicReadFutures.removeAll { future in
                    if future.deviceId == peripheralId && future.characteristicId == characteristicId && future.serviceId == serviceId {
                        future.result(.failure(error))
                        return true
                    }
                    return false
                }
            } else {
                logger.logError("NOTIFY_ERROR <- \(peripheralId) \(characteristicId): \(error.localizedDescription)")
            }
            return
        }

        if characteristic.isNotifying, let characteristicValue = characteristic.value {
            let preview = characteristicValue.prefix(8).map { String(format: "%02X", $0) }.joined()
            logger.logDebug("NOTIFY <- \(peripheralId) \(characteristicId) len=\(characteristicValue.count) data=\(preview)")

            callbackChannel?.onValueChanged(
                deviceId: peripheralId,
                characteristicId: characteristicId,
                value: FlutterStandardTypedData(bytes: characteristicValue),
                timestamp: Int64(Date().timeIntervalSince1970 * 1000)
            ) { _ in }
        }

        characteristicReadFutures.removeAll { future in
            if future.deviceId == peripheralId && future.characteristicId == characteristicId && future.serviceId == serviceId {
                if let value = characteristic.value {
                    future.result(.success(FlutterStandardTypedData(bytes: value)))
                } else {
                    future.result(.failure(createFlutterError(code: "readFailed", message: "No value")))
                }
                return true
            }
            return false
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.uuid
        let characteristicId = characteristic.uuid.uuidStr
        let serviceId = characteristic.service?.uuid.uuidStr ?? ""

        characteristicWriteFutures.removeAll { future in
            if future.deviceId == peripheralId && future.characteristicId == characteristicId && future.serviceId == serviceId {
                if let error = error {
                    logger.logError("WRITE_FAILED <- \(peripheralId) \(characteristicId): \(error.localizedDescription)")
                    future.result(.failure(error))
                } else {
                    future.result(.success(()))
                }
                return true
            }
            return false
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.uuid
        let characteristicId = characteristic.uuid.uuidStr
        let serviceId = characteristic.service?.uuid.uuidStr ?? ""

        characteristicNotifyFutures.removeAll { future in
            if future.deviceId == peripheralId && future.characteristicId == characteristicId && future.serviceId == serviceId {
                if let error = error {
                    logger.logError("SET_NOTIFY_FAILED <- \(peripheralId) \(characteristicId): \(error.localizedDescription)")
                    future.result(.failure(error))
                } else {
                    future.result(.success(()))
                }
                return true
            }
            return false
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        let peripheralId = peripheral.uuid

        rssiReadFutures.removeAll { future in
            if future.deviceId == peripheralId {
                if let error = error {
                    logger.logError("READ_RSSI_FAILED <- \(peripheralId): \(error.localizedDescription)")
                    future.result(.failure(error))
                } else {
                    future.result(.success(RSSI.int64Value))
                }
                return true
            }
            return false
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        let peripheralId = peripheral.uuid

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
        let peripheralId = peripheral.uuid
        logger.logDebug("Connection parameters updated for \(peripheralId): interval=\(parameters.interval), latency=\(parameters.latency), supervisionTimeout=\(parameters.supervisionTimeout)")

        let updated = BleConnectionParametersUpdated(
            deviceId: peripheralId,
            interval: Int64(parameters.interval),
            latency: Int64(parameters.latency),
            supervisionTimeout: Int64(parameters.supervisionTimeout),
            status: 0
        )
        sendConnectionParametersUpdated(updated)
    }
    #endif

    func peripheral(_ peripheral: CBPeripheral, didUpdateMTU mtu: Int) {
        let peripheralId = peripheral.uuid

        let updated = BleConnectionParametersUpdated(
            deviceId: peripheralId,
            interval: 0,
            latency: 0,
            supervisionTimeout: 0,
            status: Int64(mtu)
        )
        sendConnectionParametersUpdated(updated)
    }
}
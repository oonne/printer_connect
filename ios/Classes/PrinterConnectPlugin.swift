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
    }
}

class BleCentralDarwin: NSObject, UniversalBlePlatformChannel {

    private var centralManager: CBCentralManager!
    private var peripherals: [String: CBPeripheral] = [:]
    private var scanFilter: UniversalScanFilter?
    private var autoConnectDevices: Set<String> = []

    private var readFutures: [String: CharacteristicReadFuture] = [:]
    private var writeFutures: [String: CharacteristicWriteFuture] = [:]
    private var notifyFutures: [String: CharacteristicNotifyFuture] = [:]
    private var discoverFutures: [String: DiscoverServicesFuture] = [:]
    private var rssiFutures: [String: RssiReadFuture] = [:]
    private var connectionFutures: [String: ConnectionStateFuture] = [:]
    private var mtuFutures: [String: MtuFuture] = [:]
    private var pairedFutures: [String: PairedStateFuture] = [:]

    private var serviceDiscoveries: [String: PrinterConnectAsyncServiceDiscovery] = [:]

    private var callbackChannel: UniversalBleCallbackChannel?
    private let logger = PrinterConnectLogger.shared

    private var lastAvailabilityState: AvailabilityState = .unknown

    override init() {
        super.init()
        #if os(iOS)
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "printer_connect_restoration"])
        #elseif os(macOS)
        centralManager = CBCentralManager(delegate: self, queue: nil)
        #endif
    }

    func setupCallbackChannels(callbackChannel: UniversalBleCallbackChannel) {
        self.callbackChannel = callbackChannel
    }

    private func sendAvailabilityChanged(_ state: AvailabilityState) {
        callbackChannel?.onAvailabilityChanged(state: state) { _ in }
    }

    private func sendPairStateChange(deviceId: String, isPaired: Bool, error: String?) {
        callbackChannel?.onPairStateChange(deviceId: deviceId, isPaired: isPaired, error: error) { _ in }
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

    private func getPeripheral(_ peripheralId: String) -> CBPeripheral? {
        if let peripheral = peripherals[peripheralId] {
            return peripheral
        }
        if let peripheral = centralManager.retrievePeripherals(withIdentifiers: [peripheralId]).first {
            peripherals[peripheralId] = peripheral
            return peripheral
        }
        return nil
    }

    private func getCharacteristic(peripheralId: String, serviceId: String, characteristicId: String) -> CBCharacteristic? {
        guard let peripheral = getPeripheral(peripheralId) else { return nil }
        guard let service = peripheral.services?.first(where: { $0.uuid.uuidString == serviceId }) else { return nil }
        return service.characteristics?.first(where: { $0.uuid.uuidString == characteristicId })
    }

    private func key(_ peripheralId: String, _ serviceId: String, _ characteristicId: String) -> String {
        return "\(peripheralId)_\(serviceId)_\(characteristicId)"
    }

    func getBluetoothAvailabilityState(completion: @escaping (Result<AvailabilityState, Error>) -> Void) {
        let state = centralManager.state.toAvailabilityState
        completion(.success(state))
    }

    func hasPermissions(withAndroidFineLocation: Bool) throws -> Bool {
        #if os(iOS)
        if #available(iOS 13.1, *) {
            let authorization = CBCentralManager.authorization
            return authorization != .denied && authorization != .restricted
        } else {
            let state = centralManager.state
            return state != .unsupported && state != .unauthorized
        }
        #elseif os(macOS)
        let state = centralManager.state
        return state != .unsupported && state != .unauthorized
        #endif
    }

    func requestPermissions(withAndroidFineLocation: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let state = centralManager.state
        switch state {
        case .poweredOn, .poweredOff, .resetting:
            completion(.success(()))
        case .unauthorized:
            completion(.failure(PigeonError(
                code: "permissionsDenied",
                message: "Bluetooth permissions denied",
                details: nil
            )))
        case .unsupported:
            completion(.failure(PigeonError(
                code: "notSupported",
                message: "Bluetooth is not supported on this device",
                details: nil
            )))
        case .unknown:
            completion(.failure(PigeonError(
                code: "unknown",
                message: "Bluetooth state is unknown",
                details: nil
            )))
        @unknown default:
            completion(.failure(PigeonError(
                code: "unknown",
                message: "Bluetooth state is unknown",
                details: nil
            )))
        }
    }

    func enableBluetooth(completion: @escaping (Result<Bool, Error>) -> Void) {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            completion(.failure(PigeonError(
                code: "settingsError",
                message: "Unable to open settings",
                details: nil
            )))
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
            completion(.failure(PigeonError(
                code: "settingsError",
                message: "Unable to open settings",
                details: nil
            )))
            return
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #endif
        completion(.success(true))
    }

    func startScan(filter: UniversalScanFilter?, config: UniversalScanConfig?) throws {
        scanFilter = filter

        guard centralManager.state == .poweredOn else {
            throw PigeonError(
                code: "bluetoothNotReady",
                message: "Bluetooth is not powered on",
                details: nil
            )
        }

        var uuidsToScan: [CBUUID]? = nil
        if let filter = filter {
            if !filter.withServices.isEmpty {
                uuidsToScan = filter.withServices.map { CBUUID(string: $0) }
            }
        }

        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        centralManager.scanForPeripherals(withServices: uuidsToScan, options: options)
    }

    func stopScan() throws {
        centralManager.stopScan()
    }

    func isScanning() throws -> Bool {
        return centralManager.isScanning
    }

    func connect(deviceId: String, autoConnect: Bool?, platformConfig: ConnectionPlatformConfig?) throws {
        guard let peripheral = getPeripheral(deviceId) else {
            throw PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )
        }

        peripheral.delegate = self

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
        if #available(iOS 17.0, *) {
            if autoConnect ?? false {
                options[CBConnectPeripheralOptionEnableAutoReconnect] = true
            }
        } else {
            if autoConnect ?? false {
                logger.logWarning("autoConnect (CBConnectPeripheralOptionEnableAutoReconnect) is only available on iOS 17+")
            }
        }
        #endif

        if autoConnect ?? false {
            autoConnectDevices.insert(deviceId)
        }

        connectionFutures[deviceId] = ConnectionStateFuture { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.sendConnectionChanged(deviceId: deviceId, connected: true, error: nil)
            case .failure(let error):
                self.sendConnectionChanged(deviceId: deviceId, connected: false, error: error.message)
            }
        }

        centralManager.connect(peripheral, options: options)
    }

    func disconnect(deviceId: String) throws {
        autoConnectDevices.remove(deviceId)

        guard let peripheral = getPeripheral(deviceId) else {
            throw PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )
        }

        if peripheral.state != .disconnected {
            connectionFutures[deviceId] = ConnectionStateFuture { [weak self] result in
                guard let self = self else { return }
                self.cleanUpConnection(deviceId)
                switch result {
                case .success:
                    self.sendConnectionChanged(deviceId: deviceId, connected: false, error: nil)
                case .failure(let error):
                    self.sendConnectionChanged(deviceId: deviceId, connected: false, error: error.message)
                }
            }

            centralManager.cancelPeripheralConnection(peripheral)
        } else {
            cleanUpConnection(deviceId)
            sendConnectionChanged(deviceId: deviceId, connected: false, error: nil)
        }
    }

    private func cleanUpConnection(_ peripheralId: String) {
        let error = PigeonError(
            code: "connectionClosed",
            message: "Connection closed",
            details: nil
        )

        for (key, future) in readFutures {
            if key.hasPrefix(peripheralId) {
                future.completion(.failure(error))
            }
        }
        readFutures = readFutures.filter { !$0.key.hasPrefix(peripheralId) }

        for (key, future) in writeFutures {
            if key.hasPrefix(peripheralId) {
                future.completion(.failure(error))
            }
        }
        writeFutures = writeFutures.filter { !$0.key.hasPrefix(peripheralId) }

        for (key, future) in notifyFutures {
            if key.hasPrefix(peripheralId) {
                future.completion(.failure(error))
            }
        }
        notifyFutures = notifyFutures.filter { !$0.key.hasPrefix(peripheralId) }

        if let future = rssiFutures.removeValue(forKey: peripheralId) {
            future.completion(.failure(error))
        }

        if let future = mtuFutures.removeValue(forKey: peripheralId) {
            future.completion(.failure(error))
        }

        if let future = discoverFutures.removeValue(forKey: peripheralId) {
            future.completion(.failure(error))
        }

        if let future = connectionFutures.removeValue(forKey: peripheralId) {
            future.completion(.failure(error))
        }

        if let future = pairedFutures.removeValue(forKey: peripheralId) {
            future.completion(.failure(error))
        }

        serviceDiscoveries.removeValue(forKey: peripheralId)
    }

    func setNotifiable(deviceId: String, service: String, characteristic: String, bleInputProperty: BleInputProperty, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let peripheral = getPeripheral(deviceId) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )))
            return
        }

        let key = key(deviceId, service, characteristic)
        notifyFutures[key] = CharacteristicNotifyFuture { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        guard let characteristicObj = getCharacteristic(deviceId, service, characteristic) else {
            notifyFutures.removeValue(forKey: key)
            completion(.failure(PigeonError(
                code: "characteristicNotFound",
                message: "Characteristic not found: \(characteristic)",
                details: nil
            )))
            return
        }

        let enable: Bool
        switch bleInputProperty {
        case .notification:
            guard characteristicObj.properties.contains(.notify) else {
                notifyFutures.removeValue(forKey: key)
                completion(.failure(PigeonError(
                    code: "notSupported",
                    message: "Characteristic does not support notify",
                    details: nil
                )))
                return
            }
            enable = true
        case .indication:
            guard characteristicObj.properties.contains(.indicate) else {
                notifyFutures.removeValue(forKey: key)
                completion(.failure(PigeonError(
                    code: "notSupported",
                    message: "Characteristic does not support indicate",
                    details: nil
                )))
                return
            }
            enable = true
        case .disabled:
            enable = false
        }

        peripheral.setNotifyValue(enable, for: characteristicObj)
    }

    func discoverServices(deviceId: String, withDescriptors: Bool, completion: @escaping (Result<[UniversalBleService], Error>) -> Void) {
        guard let peripheral = getPeripheral(deviceId) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )))
            return
        }

        peripheral.delegate = self

        let discovery = PrinterConnectAsyncServiceDiscovery(peripheral: peripheral, withDescriptors: withDescriptors) { [weak self] result in
            guard let self = self else { return }
            self.discoverFutures.removeValue(forKey: deviceId)
            self.serviceDiscoveries.removeValue(forKey: deviceId)
            completion(result)
        }

        serviceDiscoveries[deviceId] = discovery
        discoverFutures[deviceId] = DiscoverServicesFuture(completion: completion)

        discovery.startDiscovery()
    }

    func readValue(deviceId: String, service: String, characteristic: String, completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
        guard let peripheral = getPeripheral(deviceId) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )))
            return
        }

        let key = key(deviceId, service, characteristic)
        readFutures[key] = CharacteristicReadFuture { result in
            switch result {
            case .success(let data):
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        guard let characteristicObj = getCharacteristic(deviceId, service, characteristic) else {
            readFutures.removeValue(forKey: key)
            completion(.failure(PigeonError(
                code: "characteristicNotFound",
                message: "Characteristic not found: \(characteristic)",
                details: nil
            )))
            return
        }

        peripheral.readValue(for: characteristicObj)
    }

    func requestMtu(deviceId: String, expectedMtu: Int64, completion: @escaping (Result<Int64, Error>) -> Void) {
        guard let peripheral = getPeripheral(deviceId) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )))
            return
        }

        #if os(iOS)
        guard #available(iOS 13.0, *) else {
            completion(.failure(PigeonError(
                code: "notSupported",
                message: "requestMtu requires iOS 13+",
                details: nil
            )))
            return
        }
        #endif

        mtuFutures[deviceId] = MtuFuture { result in
            switch result {
            case .success(let mtu):
                completion(.success(mtu))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        peripheral.requestMtu()
    }

    func writeValue(deviceId: String, service: String, characteristic: String, value: FlutterStandardTypedData, bleOutputProperty: BleOutputProperty, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let peripheral = getPeripheral(deviceId) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )))
            return
        }

        let key = key(deviceId, service, characteristic)
        writeFutures[key] = CharacteristicWriteFuture { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        guard let characteristicObj = getCharacteristic(deviceId, service, characteristic) else {
            writeFutures.removeValue(forKey: key)
            completion(.failure(PigeonError(
                code: "characteristicNotFound",
                message: "Characteristic not found: \(characteristic)",
                details: nil
            )))
            return
        }

        let data = value.data

        let writeType: CBCharacteristicWriteType
        switch bleOutputProperty {
        case .withResponse:
            writeType = .withResponse
        case .withoutResponse:
            writeType = .withoutResponse
        }

        peripheral.writeValue(data, for: characteristicObj, type: writeType)

        if writeType == .withoutResponse {
            writeFutures.removeValue(forKey: key)
            completion(.success(()))
        }
    }

    func isPaired(deviceId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let peripheral = getPeripheral(deviceId) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )))
            return
        }
        completion(.success(peripheral.state == .connected))
    }

    func pair(deviceId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let peripheral = getPeripheral(deviceId) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )))
            return
        }
        completion(.success(true))
    }

    func unPair(deviceId: String) throws {
        guard let peripheral = getPeripheral(deviceId) else {
            throw PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )
        }

        if peripheral.state == .connected {
            autoConnectDevices.remove(deviceId)
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    func getSystemDevices(withServices: [String], completion: @escaping (Result<[UniversalBleScanResult], Error>) -> Void) {
        let services = withServices.compactMap { CBUUID(string: $0) }
        let connected = centralManager.retrieveConnectedPeripherals(withServices: services.isEmpty ? nil : services)
        var results: [UniversalBleScanResult] = []

        for peripheral in connected {
            let result = UniversalBleScanResult(
                deviceId: peripheral.identifier.uuidString,
                name: peripheral.name,
                isPaired: nil,
                rssi: 0,
                manufacturerDataList: nil,
                serviceData: nil,
                services: withServices,
                timestamp: nil
            )
            results.append(result)
        }

        completion(.success(results))
    }

    func getConnectionState(deviceId: String) throws -> BleConnectionState {
        guard let peripheral = getPeripheral(deviceId) else {
            throw PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )
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
        guard let peripheral = getPeripheral(deviceId) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )))
            return
        }

        rssiFutures[deviceId] = RssiReadFuture { result in
            switch result {
            case .success(let rssi):
                completion(.success(rssi))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        peripheral.readRSSI()
    }

    func requestConnectionPriority(deviceId: String, priority: BleConnectionPriority, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let peripheral = getPeripheral(deviceId) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(deviceId)",
                details: nil
            )))
            return
        }

        #if os(iOS)
        guard #available(iOS 13.0, *) else {
            completion(.failure(PigeonError(
                code: "notSupported",
                message: "requestConnectionPriority requires iOS 13+",
                details: nil
            )))
            return
        }
        #endif

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
    }

    func setLogLevel(logLevel: BleLogLevel) throws {
        logger.setLogLevel(logLevel)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state.toAvailabilityState
        sendAvailabilityChanged(state)

        if state != lastAvailabilityState {
            lastAvailabilityState = state
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
        peripherals[peripheral.identifier.uuidString] = peripheral

        if let result = PrinterConnectFilterUtil.filterDevice(peripheral, advertisementData: advertisementData, rssi: rssi, filter: scanFilter) {
            sendScanResult(result)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let peripheralId = peripheral.identifier.uuidString
        peripherals[peripheralId] = peripheral

        peripheral.delegate = self

        if let future = connectionFutures.removeValue(forKey: peripheralId) {
            future.completion(.success(()))
        } else {
            sendConnectionChanged(deviceId: peripheralId, connected: true, error: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let peripheralId = peripheral.identifier.uuidString

        if let error = error {
            if let future = connectionFutures.removeValue(forKey: peripheralId) {
                future.completion(.failure(error.toPigeonError()))
            } else {
                sendConnectionChanged(deviceId: peripheralId, connected: false, error: error.localizedDescription)
            }
        } else {
            let pigeonError = PigeonError(
                code: "connectionFailed",
                message: "Failed to connect",
                details: nil
            )
            if let future = connectionFutures.removeValue(forKey: peripheralId) {
                future.completion(.failure(pigeonError))
            } else {
                sendConnectionChanged(deviceId: peripheralId, connected: false, error: "Failed to connect")
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let peripheralId = peripheral.identifier.uuidString

        if let future = connectionFutures.removeValue(forKey: peripheralId) {
            if let error = error {
                future.completion(.failure(error.toPigeonError()))
            } else {
                future.completion(.success(()))
            }
        } else {
            cleanUpConnection(peripheralId)
            if let error = error {
                sendConnectionChanged(deviceId: peripheralId, connected: false, error: error.localizedDescription)
            } else {
                sendConnectionChanged(deviceId: peripheralId, connected: false, error: nil)
            }
        }
    }

    #if os(iOS)
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        logger.logInfo("Central manager will restore state")

        if let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in restoredPeripherals {
                peripherals[peripheral.identifier.uuidString] = peripheral
                peripheral.delegate = self
            }
        }
    }
    #endif

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let peripheralId = peripheral.identifier.uuidString

        if let error = error {
            logger.logError("Error discovering services: \(error.localizedDescription)")
            if let discovery = serviceDiscoveries.removeValue(forKey: peripheralId) {
                discovery.cleanup()
            }
            if let future = discoverFutures.removeValue(forKey: peripheralId) {
                future.completion(.failure(error.toPigeonError()))
            }
            return
        }

        guard let discovery = serviceDiscoveries[peripheralId] else {
            let services = peripheral.services ?? []
            let bleServices = services.map { service -> UniversalBleService in
                let characteristics = service.characteristics?.map { char -> UniversalBleCharacteristic in
                    UniversalBleCharacteristic(
                        uuid: char.uuid.uuidString,
                        properties: char.properties.toCharacteristicProperty,
                        descriptors: []
                    )
                } ?? []
                return UniversalBleService(uuid: service.uuid.uuidString, characteristics: characteristics)
            }
            if let future = discoverFutures.removeValue(forKey: peripheralId) {
                future.completion(.success(bleServices))
            }
            return
        }

        discovery.handleDidDiscoverServices(peripheral.services)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let peripheralId = peripheral.identifier.uuidString

        if let error = error {
            logger.logError("Error discovering characteristics: \(error.localizedDescription)")
            if let discovery = serviceDiscoveries.removeValue(forKey: peripheralId) {
                discovery.cleanup()
            }
            if let future = discoverFutures.removeValue(forKey: peripheralId) {
                future.completion(.failure(error.toPigeonError()))
            }
            return
        }

        if let discovery = serviceDiscoveries[peripheralId] {
            discovery.handleDidDiscoverCharacteristicsFor(service.characteristics, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.identifier.uuidString

        if let error = error {
            logger.logError("Error discovering descriptors: \(error.localizedDescription)")
        }

        if let discovery = serviceDiscoveries[peripheralId] {
            discovery.handleDidDiscoverDescriptorsFor(characteristic, error: error)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.identifier.uuidString
        let key = key(peripheralId, characteristic.service?.uuid.uuidString ?? "", characteristic.uuid.uuidString)

        if let error = error {
            if let future = readFutures.removeValue(forKey: key) {
                future.completion(.failure(error.toPigeonError()))
            }
            logger.logError("Error updating value: \(error.localizedDescription)")
            return
        }

        guard let value = characteristic.value else {
            if let future = readFutures.removeValue(forKey: key) {
                future.completion(.failure(PigeonError(
                    code: "unknown",
                    message: "Characteristic value is nil",
                    details: nil
                )))
            }
            return
        }

        let flutterData = FlutterStandardTypedData(bytes: value)

        if let future = readFutures.removeValue(forKey: key) {
            future.completion(.success(flutterData))
        }

        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        sendValueChanged(
            deviceId: peripheralId,
            characteristicId: characteristic.uuid.uuidString,
            value: flutterData,
            timestamp: timestamp
        )
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.identifier.uuidString
        let key = key(peripheralId, characteristic.service?.uuid.uuidString ?? "", characteristic.uuid.uuidString)

        if let error = error {
            if let future = writeFutures.removeValue(forKey: key) {
                future.completion(.failure(error.toPigeonError()))
            }
            logger.logError("Error writing value: \(error.localizedDescription)")
            return
        }

        if let future = writeFutures.removeValue(forKey: key) {
            future.completion(.success(()))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.identifier.uuidString
        let key = key(peripheralId, characteristic.service?.uuid.uuidString ?? "", characteristic.uuid.uuidString)

        if let error = error {
            if let future = notifyFutures.removeValue(forKey: key) {
                future.completion(.failure(error.toPigeonError()))
            }
            logger.logError("Error updating notification state: \(error.localizedDescription)")
            return
        }

        if let future = notifyFutures.removeValue(forKey: key) {
            future.completion(.success(()))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        let peripheralId = peripheral.identifier.uuidString

        if let error = error {
            if let future = rssiFutures.removeValue(forKey: peripheralId) {
                future.completion(.failure(error.toPigeonError()))
            }
            return
        }

        if let future = rssiFutures.removeValue(forKey: peripheralId) {
            future.completion(.success(RSSI.int64Value))
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
    }

    #if os(iOS)
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        logger.logInfo("Peripheral \(peripheral.identifier.uuidString) modified services")
    }

    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        logger.logInfo("Peripheral name updated: \(peripheral.identifier.uuidString)")
    }

    func peripheral(_ peripheral: CBPeripheral, didReadMaximumWriteValueLengthFor maximumWriteValueLength: Int) {
        logger.logDebug("Maximum write value length: \(maximumWriteValueLength)")
    }
    #endif

    func peripheral(_ peripheral: CBPeripheral, didUpdateMTU mtu: Int) {
        let peripheralId = peripheral.identifier.uuidString

        if let future = mtuFutures.removeValue(forKey: peripheralId) {
            future.completion(.success(Int64(mtu)))
        }

        let updated = BleConnectionParametersUpdated(
            deviceId: peripheralId,
            interval: 0,
            latency: 0,
            supervisionTimeout: 0,
            status: 0
        )
        sendConnectionParametersUpdated(updated)
    }

    #if os(iOS)
    func peripheral(_ peripheral: CBPeripheral, didUpdateConnectionParameters parameters: CBConnectionParameters) {
        let peripheralId = peripheral.identifier.uuidString
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
}
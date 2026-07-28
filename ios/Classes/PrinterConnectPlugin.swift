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

class BleCentralDarwin: NSObject, UniversalBlePlatformChannelProtocol {

    private var centralManager: CBCentralManager!
    private var peripherals: [String: CBPeripheral] = [:]
    private var scanFilter: UniversalScanFilter?
    private var isScanningActive: Bool = false
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

    private func sendPairStateChange(peripheralId: String, isPaired: Bool) {
        callbackChannel?.onPairStateChange(peripheralId: peripheralId, isPaired: isPaired) { _ in }
    }

    private func sendScanResult(_ result: UniversalBleScanResult) {
        callbackChannel?.onScanResult(result: result) { _ in }
    }

    private func sendValueChanged(peripheralId: String, serviceId: String, characteristicId: String, value: [Int64]) {
        callbackChannel?.onValueChanged(peripheralId: peripheralId, serviceId: serviceId, characteristicId: characteristicId, value: value) { _ in }
    }

    private func sendConnectionChanged(peripheralId: String, state: BleConnectionState) {
        callbackChannel?.onConnectionChanged(peripheralId: peripheralId, state: state) { _ in }
    }

    private func sendConnectionParametersUpdated(_ result: BleConnectionParametersUpdated) {
        callbackChannel?.onConnectionParametersUpdated(result: result) { _ in }
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

    func getBluetoothAvailabilityState(completion: @escaping (Result<AvailabilityState, PigeonError>) -> Void) {
        let state = centralManager.state.toAvailabilityState
        completion(.success(state))
    }

    func hasPermissions(completion: @escaping (Result<Bool, PigeonError>) -> Void) {
        #if os(iOS)
        if #available(iOS 13.1, *) {
            let authorization = CBCentralManager.authorization
            let hasPermissions = authorization != .denied && authorization != .restricted
            completion(.success(hasPermissions))
        } else {
            let state = centralManager.state
            let hasPermissions = state != .unsupported && state != .unauthorized
            completion(.success(hasPermissions))
        }
        #elseif os(macOS)
        let state = centralManager.state
        let hasPermissions = state != .unsupported && state != .unauthorized
        completion(.success(hasPermissions))
        #endif
    }

    func requestPermissions(completion: @escaping (Result<Bool, PigeonError>) -> Void) {
        let state = centralManager.state
        switch state {
        case .poweredOn, .poweredOff, .resetting:
            completion(.success(true))
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

    func enableBluetooth(completion: @escaping (Result<Void, PigeonError>) -> Void) {
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
        completion(.success(()))
    }

    func disableBluetooth(completion: @escaping (Result<Void, PigeonError>) -> Void) {
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
        completion(.success(()))
    }

    func startScan(filters filtersArg: [UniversalScanFilter], androidOptions androidOptionsArg: AndroidOptions, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        scanFilter = filtersArg.isEmpty ? nil : filtersArg
        isScanningActive = true

        guard centralManager.state == .poweredOn else {
            isScanningActive = false
            completion(.failure(PigeonError(
                code: "bluetoothNotReady",
                message: "Bluetooth is not powered on",
                details: nil
            )))
            return
        }

        var uuidsToScan: [CBUUID]? = nil
        if let filters = scanFilter {
            var allServices: Set<String> = []
            for filter in filters {
                if let services = filter.withServices {
                    for service in services {
                        allServices.insert(service)
                    }
                }
            }
            if !allServices.isEmpty {
                uuidsToScan = Array(allServices.map { CBUUID(string: $0) })
            }
        }

        centralManager.scanForPeripherals(withServices: uuidsToScan, options: nil)
        completion(.success(()))
    }

    func stopScan(completion: @escaping (Result<Void, PigeonError>) -> Void) {
        centralManager.stopScan()
        isScanningActive = false
        completion(.success(()))
    }

    func isScanning(completion: @escaping (Result<Bool, PigeonError>) -> Void) {
        completion(.success(isScanningActive))
    }

    func connect(peripheralId peripheralIdArg: String, config configArg: ConnectionPlatformConfig, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
                details: nil
            )))
            return
        }

        peripheral.delegate = self

        var options: [String: Any] = [:]
        #if os(iOS)
        if let appleOptions = configArg.apple {
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
            options[CBConnectPeripheralOptionEnableAutoReconnect] = true
        } else {
            logger.logWarning("autoConnect (CBConnectPeripheralOptionEnableAutoReconnect) is only available on iOS 17+")
        }
        #endif

        autoConnectDevices.insert(peripheralIdArg)

        connectionFutures[peripheralIdArg] = ConnectionStateFuture { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        centralManager.connect(peripheral, options: options)
    }

    func disconnect(peripheralId peripheralIdArg: String, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        autoConnectDevices.remove(peripheralIdArg)

        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
                details: nil
            )))
            return
        }

        guard peripheral.state != .disconnected else {
            cleanUpConnection(peripheralIdArg)
            completion(.success(()))
            return
        }

        connectionFutures[peripheralIdArg] = ConnectionStateFuture { result in
            switch result {
            case .success:
                self.cleanUpConnection(peripheralIdArg)
                completion(.success(()))
            case .failure(let error):
                self.cleanUpConnection(peripheralIdArg)
                completion(.failure(error))
            }
        }

        centralManager.cancelPeripheralConnection(peripheral)
    }

    private func cleanUpConnection(_ peripheralId: String) {
        readFutures.removeValue(forKey: peripheralId)
        writeFutures.removeValue(forKey: peripheralId)
        notifyFutures.removeValue(forKey: peripheralId)
        rssiFutures.removeValue(forKey: peripheralId)
        mtuFutures.removeValue(forKey: peripheralId)
        discoverFutures.removeValue(forKey: peripheralId)
        serviceDiscoveries.removeValue(forKey: peripheralId)
    }

    func setNotifiable(peripheralId peripheralIdArg: String, serviceId serviceIdArg: String, characteristicId characteristicIdArg: String, value valueArg: BleInputProperty, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
                details: nil
            )))
            return
        }

        let key = key(peripheralIdArg, serviceIdArg, characteristicIdArg)
        notifyFutures[key] = CharacteristicNotifyFuture { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        guard let characteristic = getCharacteristic(peripheralIdArg, serviceIdArg, characteristicIdArg) else {
            notifyFutures.removeValue(forKey: key)
            completion(.failure(PigeonError(
                code: "characteristicNotFound",
                message: "Characteristic not found: \(characteristicIdArg)",
                details: nil
            )))
            return
        }

        let enable: Bool
        switch valueArg {
        case .notification, .indication:
            enable = true
        case .disabled:
            enable = false
        }

        peripheral.setNotifyValue(enable, for: characteristic)
    }

    func discoverServices(peripheralId peripheralIdArg: String, completion: @escaping (Result<[UniversalBleService], PigeonError>) -> Void) {
        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
                details: nil
            )))
            return
        }

        peripheral.delegate = self

        let discovery = PrinterConnectAsyncServiceDiscovery(peripheral: peripheral) { [weak self] result in
            guard let self = self else { return }
            self.discoverFutures.removeValue(forKey: peripheralIdArg)
            self.serviceDiscoveries.removeValue(forKey: peripheralIdArg)
            completion(result)
        }

        serviceDiscoveries[peripheralIdArg] = discovery
        discoverFutures[peripheralIdArg] = DiscoverServicesFuture(completion: completion)

        discovery.startDiscovery()
    }

    func readValue(peripheralId peripheralIdArg: String, serviceId serviceIdArg: String, characteristicId characteristicIdArg: String, completion: @escaping (Result<UniversalBleCharacteristic, PigeonError>) -> Void) {
        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
                details: nil
            )))
            return
        }

        let key = key(peripheralIdArg, serviceIdArg, characteristicIdArg)
        readFutures[key] = CharacteristicReadFuture { result in
            switch result {
            case .success(let characteristic):
                completion(.success(characteristic))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        guard let characteristic = getCharacteristic(peripheralIdArg, serviceIdArg, characteristicIdArg) else {
            readFutures.removeValue(forKey: key)
            completion(.failure(PigeonError(
                code: "characteristicNotFound",
                message: "Characteristic not found: \(characteristicIdArg)",
                details: nil
            )))
            return
        }

        peripheral.readValue(for: characteristic)
    }

    func requestMtu(peripheralId peripheralIdArg: String, mtu mtuArg: Int64, completion: @escaping (Result<Int64, PigeonError>) -> Void) {
        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
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

        mtuFutures[peripheralIdArg] = MtuFuture { result in
            switch result {
            case .success(let mtu):
                completion(.success(mtu))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        peripheral.requestMtu()
    }

    func writeValue(peripheralId peripheralIdArg: String, serviceId serviceIdArg: String, characteristicId characteristicIdArg: String, value valueArg: [Int64], bleOutputProperty bleOutputPropertyArg: BleOutputProperty, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
                details: nil
            )))
            return
        }

        let key = key(peripheralIdArg, serviceIdArg, characteristicIdArg)
        writeFutures[key] = CharacteristicWriteFuture { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        guard let characteristic = getCharacteristic(peripheralIdArg, serviceIdArg, characteristicIdArg) else {
            writeFutures.removeValue(forKey: key)
            completion(.failure(PigeonError(
                code: "characteristicNotFound",
                message: "Characteristic not found: \(characteristicIdArg)",
                details: nil
            )))
            return
        }

        let data = Data(int64List: valueArg)

        let writeType: CBCharacteristicWriteType
        switch bleOutputPropertyArg {
        case .writeWithoutResponse:
            writeType = .withoutResponse
        case .write:
            writeType = .withResponse
        case .none:
            writeType = .withResponse
        }

        peripheral.writeValue(data, for: characteristic, type: writeType)

        if writeType == .withoutResponse {
            writeFutures.removeValue(forKey: key)
            completion(.success(()))
        }
    }

    func isPaired(peripheralId peripheralIdArg: String, completion: @escaping (Result<Bool, PigeonError>) -> Void) {
        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
                details: nil
            )))
            return
        }
        completion(.success(peripheral.state == .connected))
    }

    func pair(peripheralId peripheralIdArg: String, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
                details: nil
            )))
            return
        }
        completion(.success(()))
    }

    func unPair(peripheralId peripheralIdArg: String, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
                details: nil
            )))
            return
        }

        if peripheral.state == .connected {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        completion(.success(()))
    }

    func getSystemDevices(withServices withServicesArg: [String]?, completion: @escaping (Result<[UniversalBleScanResult], PigeonError>) -> Void) {
        let services = withServicesArg?.compactMap { CBUUID(string: $0) } ?? []
        let connected = centralManager.retrieveConnectedPeripherals(withServices: services.isEmpty ? nil : services)
        var results: [UniversalBleScanResult] = []

        for peripheral in connected {
            let result = UniversalBleScanResult(
                peripheralId: peripheral.identifier.uuidString,
                name: peripheral.name,
                rssi: 0,
                manufacturerData: nil,
                serviceData: nil,
                serviceUuids: withServicesArg,
                txPowerLevel: nil
            )
            results.append(result)
        }

        completion(.success(results))
    }

    func getConnectionState(peripheralId peripheralIdArg: String, completion: @escaping (Result<BleConnectionState, PigeonError>) -> Void) {
        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
                details: nil
            )))
            return
        }

        let state: BleConnectionState
        switch peripheral.state {
        case .disconnected: state = .disconnected
        case .connecting: state = .connecting
        case .connected: state = .connected
        case .disconnecting: state = .disconnecting
        @unknown default: state = .disconnected
        }

        completion(.success(state))
    }

    func readRssi(peripheralId peripheralIdArg: String, completion: @escaping (Result<Int64, PigeonError>) -> Void) {
        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
                details: nil
            )))
            return
        }

        rssiFutures[peripheralIdArg] = RssiReadFuture { result in
            switch result {
            case .success(let rssi):
                completion(.success(rssi))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        peripheral.readRSSI()
    }

    func requestConnectionPriority(peripheralId peripheralIdArg: String, priority priorityArg: BleConnectionPriority, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        guard let peripheral = getPeripheral(peripheralIdArg) else {
            completion(.failure(PigeonError(
                code: "peripheralNotFound",
                message: "Peripheral not found: \(peripheralIdArg)",
                details: nil
            )))
            return
        }

        #if os(iOS)
        guard #available(iOS 13.0, *) else {
            completion(.success(()))
            return
        }
        #endif

        let priorityValue: CBConnectionPriority
        switch priorityArg {
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

    func setLogLevel(level levelArg: BleLogLevel, completion: @escaping (Result<Void, PigeonError>) -> Void) {
        logger.setLogLevel(levelArg)
        completion(.success(()))
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

        if let result = PrinterConnectFilterUtil.filterDevice(peripheral, advertisementData: advertisementData, rssi: rssi, filters: scanFilter) {
            sendScanResult(result)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let peripheralId = peripheral.identifier.uuidString
        peripherals[peripheralId] = peripheral

        peripheral.delegate = self

        sendConnectionChanged(peripheralId: peripheralId, state: .connected)

        if let future = connectionFutures.removeValue(forKey: peripheralId) {
            future.completion(.success(()))
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let peripheralId = peripheral.identifier.uuidString

        sendConnectionChanged(peripheralId: peripheralId, state: .disconnected)

        if let error = error {
            if let future = connectionFutures.removeValue(forKey: peripheralId) {
                future.completion(.failure(error.toPigeonError()))
            }
        } else {
            if let future = connectionFutures.removeValue(forKey: peripheralId) {
                future.completion(.failure(PigeonError(
                    code: "connectionFailed",
                    message: "Failed to connect",
                    details: nil
                )))
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let peripheralId = peripheral.identifier.uuidString

        sendConnectionChanged(peripheralId: peripheralId, state: .disconnected)

        if let future = connectionFutures.removeValue(forKey: peripheralId) {
            if let error = error {
                future.completion(.failure(error.toPigeonError()))
            } else {
                future.completion(.success(()))
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
            let bleServices = services.map { UniversalBleService(uuid: $0.uuid.uuidString, isPrimary: $0.isPrimary) }
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

        let valueList = characteristic.value?.toInt64List() ?? []

        let bleCharacteristic = UniversalBleCharacteristic(
            uuid: characteristic.uuid.uuidString,
            properties: characteristic.properties.toCharacteristicProperty,
            value: valueList
        )

        if let future = readFutures.removeValue(forKey: key) {
            future.completion(.success(bleCharacteristic))
        }

        sendValueChanged(
            peripheralId: peripheralId,
            serviceId: characteristic.service?.uuid.uuidString ?? "",
            characteristicId: characteristic.uuid.uuidString,
            value: valueList
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
            mtu: Int64(mtu),
            deviceId: peripheralId,
            interval: nil,
            latency: nil,
            supervisionTimeout: nil,
            status: nil
        )
        sendConnectionParametersUpdated(updated)
    }

    #if os(iOS)
    func peripheral(_ peripheral: CBPeripheral, didUpdateConnectionParameters parameters: CBConnectionParameters) {
        let peripheralId = peripheral.identifier.uuidString
        logger.logDebug("Connection parameters updated for \(peripheralId): interval=\(parameters.interval), latency=\(parameters.latency), supervisionTimeout=\(parameters.supervisionTimeout)")

        let updated = BleConnectionParametersUpdated(
            mtu: Int64(peripheral.maximumWriteValueLength(for: .withResponse)),
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
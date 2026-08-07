import CoreBluetooth

#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import AppKit
import FlutterMacOS
#endif

/// Flutter BLE 打印机连接插件主入口。
/// 负责注册 Flutter 插件通道（PlatformChannel / CallbackChannel），
/// 并初始化底层蓝牙中央管理器（CBCentralManager）。
public class PrinterConnectPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let binaryMessenger = registrar.messenger()
        let callbackChannel = UniversalBleCallbackChannel(binaryMessenger: binaryMessenger)
        let api = BleCentralDarwin(callbackChannel: callbackChannel)
        UniversalBlePlatformChannelSetup.setUp(binaryMessenger: binaryMessenger, api: api)
        #if os(iOS)
        // 当宿主 App 声明了 `bluetooth-central` 后台模式时，在启动时构建管理器，
        // 这样 CoreBluetooth 才能在后台重启后通过 willRestoreState: 恢复状态
        // （见 activateStateRestoration 方法）。
        api.activateStateRestoration()
        #endif
    }
}

// 已发现的外设缓存表（key: 设备 UUID 字符串, value: CBPeripheral 实例）
private var discoveredPeripherals = [String: CBPeripheral]()

// 缓存外设最后一次广播的本地名称
// 因为 iOS 和 macOS 不会为系统设备自动缓存该名称
private var advertisementNameCache = [String: String]()

/// 蓝牙中央管理器核心实现类。
///
/// 负责管理 CBCentralManager 的完整生命周期，包括：
/// - 蓝牙设备扫描与发现
/// - 连接管理（自动重连、断开处理）
/// - GATT 服务发现、特征值读写、通知订阅
/// - 状态恢复机制（iOS 后台模式）
/// - 通过 Flutter 通道将事件回调传递给 Dart 层
private class BleCentralDarwin: NSObject, UniversalBlePlatformChannel, CBCentralManagerDelegate, CBPeripheralDelegate {

    /// 状态恢复标识符，用于 CoreBluetooth 后台恢复机制
    static let stateRestorationIdentifier = "com.printerconnect.central.restoration"

    #if os(iOS)
    /// 检测宿主 App 是否配置了 bluetooth-central 后台模式
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
        // 如果开启了后台模式，使用带恢复标识符的配置创建管理器，
        // 以便 App 从后台恢复时能重建已连接的外设状态
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

    /// 蓝牙可用性状态变更等待队列
    private var availabilityStateUpdateHandlers: [(Result<AvailabilityState, Error>) -> Void] = []
    /// 蓝牙权限请求等待队列
    private var requestPermissionStateUpdateHandlers: [(Result<Void, Error>) -> Void] = []

    /// 当前正在进行的异步服务发现任务表（key: 设备 UUID）
    private var activeServiceDiscoveries: [String: PrinterConnectAsyncServiceDiscovery] = [:]

    // MARK: - Future 回调存储（用于异步操作结果匹配）

    /// 特征值读取操作的 Future 数组
    private var characteristicReadFutures = [CharacteristicReadFuture]()
    /// 特征值写入操作（带响应）的 Future 数组
    private var characteristicWriteFutures = [CharacteristicWriteFuture]()
    /// 特征值写入操作（无响应）的 Future 数组
    private var characteristicWriteWithoutResponseFutures = [CharacteristicWriteFuture]()
    /// 特征值通知/指示订阅操作的 Future 数组
    private var characteristicNotifyFutures = [CharacteristicNotifyFuture]()
    /// 服务发现操作的 Future 数组
    private var discoverServicesFutures = [DiscoverServicesFuture]()
    /// RSSI 读取操作的 Future 数组
    private var rssiReadFutures = [RssiReadFuture]()

    /// 标记是否由插件主动管理扫描状态
    private var isManageScanning = false
    /// 需要自动重连的设备集合（iOS 17+ 使用系统自动重连，旧版本手动处理）
    private var autoConnectDevices = Set<String>()

    private let logger = PrinterConnectLogger.shared

    init(callbackChannel: UniversalBleCallbackChannel) {
        self.callbackChannel = callbackChannel
        super.init()
    }

    #if os(iOS)
    /// 激活状态恢复机制。
    /// 当宿主 App 声明了 bluetooth-central 后台模式且已获得蓝牙权限时，
    /// 强制初始化 CBCentralManager 以触发状态恢复流程。
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

    func startScan(filter: UniversalScanFilter?, config _: UniversalScanConfig?) throws {
        let usesCustomFilters = filter?.usesCustomFilters ?? false

        var withServices: [CBUUID] = try (filter?.withServices ?? []).toCBUUID()

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

    /// 建立与指定外设的连接。
    /// - Parameters:
    ///   - deviceId: 目标设备的 UUID
    ///   - autoConnect: 是否启用自动重连（iOS 17+ 通过系统选项实现，旧版本仅记录意图）
    ///   - platformConfig: 平台特定的连接配置（通知开关等）
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

    /// 断开与指定外设的连接。
    /// 取消自动重连标记、调用系统断开 API，并清理所有挂起的 Future。
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

    /// 清理指定设备的所有挂起 Future 和服务发现任务。
    /// 当设备断开连接时调用，确保所有等待中的异步操作收到失败回调。
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

    /// 开始异步服务发现流程。
    /// 如果已有进行中的发现任务，将新请求排入等待队列，待当前任务完成后一并回调。
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

    /// 设置特征值的通知或指示订阅。
    /// 会先校验特征值是否支持对应的属性，再调用系统 API 并注册 Future 等待回调。
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

    /// 读取指定特征值的值。
    /// 校验特征值 read 属性后，发起读取请求并注册 Future 等待 didUpdateValueFor 回调。
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

    /// 向指定特征值写入数据。
    /// 根据写入类型（withResponse / withoutResponse）选择对应的 Future 数组，
    /// withResponse 等待 didWriteValueFor 回调，withoutResponse 等待 peripheralIsReady 回调。
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

    // MARK: - CBCentralManagerDelegate 回调

    /// 蓝牙中央管理器状态变更回调。
    /// 当系统蓝牙状态改变时触发，将新状态通知 Flutter 层，
    /// 并处理所有等待状态的权限/可用性请求。
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

    /// 发现外设回调。
    /// 解析广播数据中的制造商数据、服务数据、本地名称等，
    /// 经过自定义过滤器筛选后通过 CallbackChannel 上报给 Dart 层。
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
            rssi: RSSI as? Int64,
            manufacturerDataList: manufacturerDataList,
            serviceData: serviceData,
            services: services?.map { $0.uuidStr },
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )) { _ in }
    }

    /// 外设连接成功回调
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        callbackChannel.onConnectionChanged(deviceId: peripheral.uuid.uuidString, connected: true, error: nil) { _ in }
    }

    /// 统一处理外设断开事件（从各种断开回调中调用）。
    /// 清理自动重连标记、通知 Flutter 层、清理所有挂起 Future。
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

    // MARK: - CBPeripheralDelegate 回调

    /// 服务发现回调 —— 转发给异步服务发现处理器
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        activeServiceDiscoveries[peripheral.uuid.uuidString]?.handleDidDiscoverServices(peripheral, error: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        activeServiceDiscoveries[peripheral.uuid.uuidString]?.handleDidDiscoverCharacteristicsFor(peripheral, service: service, error: error)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        activeServiceDiscoveries[peripheral.uuid.uuidString]?.handleDidDiscoverDescriptorsFor(peripheral, characteristic: characteristic, error: error)
    }

    /// 特征值更新回调（处理读取结果和通知/指示数据）。
    /// 通过匹配 deviceId + characteristicId + serviceId 来区分是读取操作还是通知事件：
    /// - 如果匹配到 ReadFuture，将结果回调给等待中的读取操作
    /// - 如果特征值处于 isNotifying 状态，将数据通过 CallbackChannel 推送给 Dart 层
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.uuid.uuidString
        let characteristicId = characteristic.uuid.uuidStr
        let serviceId = characteristic.service?.uuid.uuidStr

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

    /// 特征值写入完成回调（带响应写入）。
    /// 匹配对应的 WriteFuture 并回调写入结果。
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.uuid.uuidString
        let characteristicId = characteristic.uuid.uuidStr
        let serviceId = characteristic.service?.uuid.uuidStr

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

    /// 通知/指示状态变更回调。
    /// 匹配对应的 NotifyFuture 并回调订阅结果（成功或失败）。
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let peripheralId = peripheral.uuid.uuidString
        let characteristicId = characteristic.uuid.uuidStr
        let serviceId = characteristic.service?.uuid.uuidStr

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

    /// 外设准备好发送无响应写入数据回调。
    /// 匹配对应的 WriteWithoutResponseFuture 并回调成功结果。
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
        logger.logDebug("MTU updated for \(peripheralId): mtu=\(mtu)")
        // MTU 变更通过 requestMtu 的完成处理器返回，
        // 不通过 onConnectionParametersUpdated 回调传递
    }
}

// MARK: - CBPeripheral 扩展

extension CBPeripheral {
    /// 将外设缓存到全局 discoveredPeripherals 字典中，便于后续通过 UUID 查找
    func saveCache() {
        discoveredPeripherals[uuid.uuidString] = self
    }
}

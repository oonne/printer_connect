package com.example.printer_connect

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterError
import java.util.concurrent.ConcurrentHashMap

enum class UniversalBleErrorCode(val raw: Int) {
    UNKNOWN_ERROR(0),
    BLUETOOTH_NOT_AVAILABLE(1),
    BLUETOOTH_NOT_AUTHORIZED(2),
    BLUETOOTH_PERMISSION_DENIED(3),
    BLUETOOTH_DISABLED(4),
    BLUETOOTH_INVALID_STATE(5),
    CONNECTION_FAILED(6),
    CONNECTION_TIMEOUT(7),
    CONNECTION_LOST(8),
    CONNECTION_NOT_ESTABLISHED(9),
    DISCONNECTION_FAILED(10),
    WRITE_FAILED(11),
    READ_FAILED(12),
    DISCOVER_SERVICES_FAILED(13),
    SET_NOTIFY_FAILED(14),
    SET_INDICATE_FAILED(15),
    SCAN_FAILED(16),
    SCAN_TIMEOUT(17),
    DEVICE_NOT_FOUND(18),
    SERVICE_NOT_FOUND(19),
    CHARACTERISTIC_NOT_FOUND(20),
    DESCRIPTOR_NOT_FOUND(21),
    INVALID_VALUE(22),
    INVALID_DEVICE_ID(23),
    OPERATION_CANCELLED(24),
    OPERATION_NOT_SUPPORTED(25),
    MTU_REQUEST_FAILED(26),
    PAIRING_FAILED(27),
    UNPAIR_FAILED(28),
    SECURITY_ERROR(29),
    STREAM_ALREADY_LISTENING(30),
    STREAM_NOT_LISTENING(31),
    TRANSACTION_IN_PROGRESS(32),
    INVALID_TRANSACTION_ID(33),
    BLUETOOTH_NOT_ENABLED(34),
    BLUETOOTH_NOT_ALLOWED(35),
    NOT_PAIRED(36),
    WRITE_NOT_PERMITTED(37),
    WRITE_REQUEST_BUSY(38),
    NOT_IMPLEMENTED(39),
    NOT_SUPPORTED(40),
    READ_NOT_PERMITTED(41),
    INSUFFICIENT_AUTHENTICATION(42),
    INSUFFICIENT_AUTHORIZATION(43),
    INSUFFICIENT_ENCRYPTION(44),
    INVALID_OFFSET(45),
    INVALID_ATTRIBUTE_LENGTH(46),
    INVALID_HANDLE(47),
    INVALID_PDU(48),
    INSUFFICIENT_KEY_SIZE(49),
    FAILED(50),
    OPERATION_IN_PROGRESS(51),
    CONNECTION_IN_PROGRESS(52),
    DEVICE_DISCONNECTED(53),
    CHARACTERISTIC_DOES_NOT_SUPPORT_WRITE(54),
    CHARACTERISTIC_DOES_NOT_SUPPORT_WRITE_WITHOUT_RESPONSE(55)
}

fun Int.parseHciErrorCode(): String? {
    return when (this) {
        BluetoothGatt.GATT_SUCCESS -> null
        0x01 -> "Unknown HCI Command"
        0x02 -> "Unknown Connection Identifier"
        0x03 -> "Hardware Failure"
        0x04 -> "Page Timeout"
        0x05 -> "Authentication Failure"
        0x06 -> "PIN or Key Missing"
        0x07 -> "Memory Capacity Exceeded"
        0x08 -> "Connection Timeout"
        0x09 -> "Connection Limit Exceeded"
        0x0A -> "Synchronous Connection Limit To A Device Exceeded"
        0x0B -> "Connection Already Exists"
        0x0C -> "Command Disallowed"
        0x0D -> "Connection Rejected due to Limited Resources"
        0x0E -> "Connection Rejected Due To Security Reasons"
        0x0F -> "Connection Rejected due to Unacceptable BD_ADDR"
        0x10 -> "Connection Accept Timeout Exceeded"
        0x11 -> "Unsupported Feature or Parameter Value"
        0x12 -> "Invalid HCI Command Parameters"
        0x13 -> "Remote User Terminated Connection"
        0x14 -> "Remote Device Terminated Connection due to Low Resources"
        0x15 -> "Remote Device Terminated Connection due to Power Off"
        0x16 -> "Connection Terminated By Local Host"
        0x17 -> "Repeated Attempts"
        0x18 -> "Pairing Not Allowed"
        0x19 -> "Unknown LMP PDU"
        0x1A -> "Unsupported Remote Feature / Unsupported LMP Feature"
        0x1B -> "SCO Offset Rejected"
        0x1C -> "SCO Interval Rejected"
        0x1D -> "SCO Air Mode Rejected"
        0x1E -> "Invalid LMP Parameters / Invalid LL Parameters"
        0x1F -> "Unspecified Error"
        0x20 -> "Unsupported LMP Parameter Value / Unsupported LL Parameter Value"
        0x21 -> "Role Change Not Allowed"
        0x22 -> "Unsupported Remote Feature"
        0x23 -> "Unsupported LMP Parameter Value"
        0x24 -> "Unsupported LL Parameter Value"
        0x25 -> "Invalid LMP Parameters / Invalid LL Parameters"
        0x26 -> "Unknown Error"
        else -> "Unknown Error"
    }
}

@SuppressLint("MissingPermission")
class PrinterConnectPlugin : FlutterPlugin, BluetoothGattCallback(), ActivityAware,
    UniversalBlePlatformChannel {

    private lateinit var binaryMessenger: BinaryMessenger
    private var activityBinding: ActivityPluginBinding? = null
    private var context: Context? = null

    private var callbackChannel: UniversalBleCallbackChannel? = null

    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var safeScanner: SafeScanner? = null

    private var scanCallback: ScanCallback? = null
    private var isScanning: Boolean = false
    private var pendingScanFilter: UniversalScanFilter? = null
    private var pendingScanConfig: UniversalScanConfig? = null

    private val scanResults = mutableMapOf<String, UniversalBleScanResult>()
    private val cachedServices = ConcurrentHashMap<String, List<UniversalBleService>>()
    private val autoConnectDevices = mutableSetOf<String>()

    private val readFutures = ConcurrentHashMap<String, (Result<ByteArray>) -> Unit>()
    private val writeFutures = ConcurrentHashMap<String, (Result<Unit>) -> Unit>()
    private val discoverFutures = ConcurrentHashMap<String, MutableList<(Result<List<UniversalBleService>>) -> Unit>>()
    private val rssiFutures = ConcurrentHashMap<String, (Result<Long>) -> Unit>()
    private val mtuFutures = ConcurrentHashMap<String, (Result<Long>) -> Unit>()
    private val descriptorWriteFutures = ConcurrentHashMap<String, (Result<Unit>) -> Unit>()
    private val descriptorReadFutures = ConcurrentHashMap<String, (Result<ByteArray>) -> Unit>()
    private val subscriptionFutures = ConcurrentHashMap<String, (Result<Unit>) -> Unit>()

    private val handler = Handler(Looper.getMainLooper())

    private var permissionLauncher: androidx.activity.result.ActivityResultLauncher<Array<String>>? = null
    private var pendingPermissionResult: ((Boolean) -> Unit)? = null

    private var enableBluetoothLauncher: androidx.activity.result.ActivityResultLauncher<Intent>? = null
    private var pendingEnableResult: ((Boolean) -> Unit)? = null

    private val pendingPairResults = ConcurrentHashMap<String, (Result<Boolean>) -> Unit>()

    private val broadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            when (action) {
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                    val availabilityState = state.toAvailabilityState()
                    handler.post {
                        callbackChannel?.onAvailabilityChanged(availabilityState) { _ -> }
                    }
                    PrinterConnectLogger.logDebug("Bluetooth state changed: $availabilityState")
                }
                BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                    val bondStateChange = intent.getBondStateChange() ?: return
                    val deviceAddress = bondStateChange.device.address
                    val bondState = bondStateChange.state
                    val isPaired = bondState == BluetoothDevice.BOND_BONDED
                    handler.post {
                        callbackChannel?.onPairStateChange(deviceAddress, isPaired, null) { _ -> }
                    }
                    PrinterConnectLogger.logDebug("Bond state changed for $deviceAddress: bondState=$bondState, bonded=$isPaired")

                    val pendingCallback = pendingPairResults.remove(deviceAddress)
                    if (pendingCallback != null) {
                        when {
                            isPaired -> {
                                handler.post { pendingCallback.invoke(Result.success(true)) }
                            }
                            bondState == BluetoothDevice.BOND_NONE -> {
                                handler.post { pendingCallback.invoke(Result.failure(createFlutterError(UniversalBleErrorCode.PAIRING_FAILED, "Pairing failed for $deviceAddress"))) }
                            }
                            bondState == BluetoothDevice.BOND_BONDING -> {
                                PrinterConnectLogger.logDebug("Bonding in progress for $deviceAddress")
                            }
                        }
                    }
                }
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.binaryMessenger = binding.binaryMessenger
        this.context = binding.applicationContext

        bluetoothManager = context?.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
        safeScanner = SafeScanner(bluetoothManager!!)

        callbackChannel = UniversalBleCallbackChannel(binaryMessenger)
        UniversalBlePlatformChannel.setUp(binaryMessenger, this)

        registerBroadcastReceiver()

        PrinterConnectLogger.logInfo("PrinterConnectPlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        unregisterBroadcastReceiver()
        stopScanInternal()
        closeAllGattConnections()
        UniversalBlePlatformChannel.setUp(binaryMessenger, null)
        callbackChannel = null
        PrinterConnectLogger.logInfo("PrinterConnectPlugin detached from engine")
    }

    private fun postToMainLooper(action: () -> Unit) {
        handler.post(action)
    }

    private fun sendConnectionChanged(deviceId: String, connected: Boolean, error: String?) {
        handler.post {
            callbackChannel?.onConnectionChanged(deviceId, connected, error) { _ -> }
        }
    }

    private fun sendConnectionParametersUpdated(result: BleConnectionParametersUpdated) {
        handler.post {
            callbackChannel?.onConnectionParametersUpdated(result) { _ -> }
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activityBinding = binding
        setupPermissionLauncher(binding)
        setupEnableBluetoothLauncher(binding)
        PrinterConnectLogger.logDebug("Activity attached")
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
        PrinterConnectLogger.logDebug("Activity detached")
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.activityBinding = binding
        setupPermissionLauncher(binding)
        setupEnableBluetoothLauncher(binding)
        PrinterConnectLogger.logDebug("Activity reattached for config changes")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
        PrinterConnectLogger.logDebug("Activity detached for config changes")
    }

    private fun setupPermissionLauncher(binding: ActivityPluginBinding) {
        val componentActivity = binding.activity as? androidx.activity.ComponentActivity
        if (componentActivity == null) {
            PrinterConnectLogger.logError("Cannot register permission launcher: activity is not a ComponentActivity")
            return
        }
        permissionLauncher = componentActivity.registerForActivityResult(
            androidx.activity.result.contract.ActivityResultContracts.RequestMultiplePermissions()
        ) { grants: Map<String, Boolean> ->
            val allGranted = grants.values.all { it }
            pendingPermissionResult?.invoke(allGranted)
            pendingPermissionResult = null
            PrinterConnectLogger.logDebug("Permission result: $allGranted")
        }
    }

    private fun setupEnableBluetoothLauncher(binding: ActivityPluginBinding) {
        val componentActivity = binding.activity as? androidx.activity.ComponentActivity
        if (componentActivity == null) {
            PrinterConnectLogger.logError("Cannot register enable bluetooth launcher: activity is not a ComponentActivity")
            return
        }
        enableBluetoothLauncher = componentActivity.registerForActivityResult(
            androidx.activity.result.contract.ActivityResultContracts.StartActivityForResult()
        ) { result ->
            val success = result.resultCode == android.app.Activity.RESULT_OK
            pendingEnableResult?.invoke(success)
            pendingEnableResult = null
            PrinterConnectLogger.logDebug("Enable Bluetooth result: $success")
        }
    }

    private fun registerBroadcastReceiver() {
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        filter.addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        context?.registerReceiverCompat(broadcastReceiver, filter, exported = true)
    }

    private fun unregisterBroadcastReceiver() {
        try {
            context?.unregisterReceiver(broadcastReceiver)
        } catch (_: Exception) {}
    }

    private fun closeAllGattConnections() {
        for ((_, gatt) in knownGatts) {
            try {
                gatt.close()
            } catch (_: Exception) {}
        }
        knownGatts.clear()
        cachedServices.clear()
        clearAllFutures()
    }

    private fun clearFuturesForDevice(deviceAddress: String) {
        discoverFutures.remove(deviceAddress)
        mtuFutures.remove(deviceAddress)
        rssiFutures.remove(deviceAddress)
        val keysToRemove = mutableListOf<String>()
        for (key in readFutures.keys) {
            if (key.startsWith("$deviceAddress/")) keysToRemove.add(key)
        }
        for (key in keysToRemove) readFutures.remove(key)
        val keysToRemoveWrite = mutableListOf<String>()
        for (key in writeFutures.keys) {
            if (key.startsWith("$deviceAddress/")) keysToRemoveWrite.add(key)
        }
        for (key in keysToRemoveWrite) writeFutures.remove(key)
        val keysToRemoveDesc = mutableListOf<String>()
        for (key in descriptorWriteFutures.keys) {
            if (key.startsWith("$deviceAddress/")) keysToRemoveDesc.add(key)
        }
        for (key in keysToRemoveDesc) descriptorWriteFutures.remove(key)
        val keysToRemoveDescRead = mutableListOf<String>()
        for (key in descriptorReadFutures.keys) {
            if (key.startsWith("$deviceAddress/")) keysToRemoveDescRead.add(key)
        }
        for (key in keysToRemoveDescRead) descriptorReadFutures.remove(key)
        val keysToRemoveSub = mutableListOf<String>()
        for (key in subscriptionFutures.keys) {
            if (key.startsWith("$deviceAddress/")) keysToRemoveSub.add(key)
        }
        for (key in keysToRemoveSub) subscriptionFutures.remove(key)
    }

    private fun clearAllFutures() {
        readFutures.clear()
        writeFutures.clear()
        discoverFutures.clear()
        rssiFutures.clear()
        mtuFutures.clear()
        descriptorWriteFutures.clear()
        descriptorReadFutures.clear()
        subscriptionFutures.clear()
    }

    private fun completeFuturesForDevice(deviceId: String, error: FlutterError) {
        val deviceDisconnectedError = error

        discoverFutures.remove(deviceId)?.forEach { callback ->
            handler.post { callback.invoke(Result.failure(deviceDisconnectedError)) }
        }

        mtuFutures.remove(deviceId)?.let { callback ->
            handler.post { callback.invoke(Result.failure(deviceDisconnectedError)) }
        }

        rssiFutures.remove(deviceId)?.let { callback ->
            handler.post { callback.invoke(Result.failure(deviceDisconnectedError)) }
        }

        val readKeysToRemove = mutableListOf<String>()
        for (key in readFutures.keys) {
            if (key.startsWith("$deviceId/")) {
                readKeysToRemove.add(key)
                readFutures[key]?.let { callback ->
                    handler.post { callback.invoke(Result.failure(deviceDisconnectedError)) }
                }
            }
        }
        for (key in readKeysToRemove) readFutures.remove(key)

        val writeKeysToRemove = mutableListOf<String>()
        for (key in writeFutures.keys) {
            if (key.startsWith("$deviceId/")) {
                writeKeysToRemove.add(key)
                writeFutures[key]?.let { callback ->
                    handler.post { callback.invoke(Result.failure(deviceDisconnectedError)) }
                }
            }
        }
        for (key in writeKeysToRemove) writeFutures.remove(key)

        val descWriteKeysToRemove = mutableListOf<String>()
        for (key in descriptorWriteFutures.keys) {
            if (key.startsWith("$deviceId/")) {
                descWriteKeysToRemove.add(key)
                descriptorWriteFutures[key]?.let { callback ->
                    handler.post { callback.invoke(Result.failure(deviceDisconnectedError)) }
                }
            }
        }
        for (key in descWriteKeysToRemove) descriptorWriteFutures.remove(key)

        val descReadKeysToRemove = mutableListOf<String>()
        for (key in descriptorReadFutures.keys) {
            if (key.startsWith("$deviceId/")) {
                descReadKeysToRemove.add(key)
                descriptorReadFutures[key]?.let { callback ->
                    handler.post { callback.invoke(Result.failure(deviceDisconnectedError)) }
                }
            }
        }
        for (key in descReadKeysToRemove) descriptorReadFutures.remove(key)

        val subKeysToRemove = mutableListOf<String>()
        for (key in subscriptionFutures.keys) {
            if (key.startsWith("$deviceId/")) {
                subKeysToRemove.add(key)
                subscriptionFutures[key]?.let { callback ->
                    handler.post { callback.invoke(Result.failure(deviceDisconnectedError)) }
                }
            }
        }
        for (key in subKeysToRemove) subscriptionFutures.remove(key)
    }

    private fun cleanUpConnection(deviceId: String) {
        val deviceDisconnectedError = createFlutterError(
            UniversalBleErrorCode.DEVICE_DISCONNECTED,
            "Device Disconnected",
        )
        completeFuturesForDevice(deviceId, deviceDisconnectedError)
    }

    @SuppressLint("MissingPermission")
    private fun cleanConnection(gatt: BluetoothGatt) {
        gatt.removeCache()
        gatt.disconnect()
        cleanUpConnection(gatt.device.address)
    }

    private fun isBluetoothAvailable(): Boolean {
        val manager = bluetoothManager ?: return false
        return manager.isBluetoothEnabled()
    }

    override fun getBluetoothAvailabilityState(callback: (Result<AvailabilityState>) -> Unit) {
        val manager = bluetoothManager
        if (manager == null) {
            callback(Result.success(AvailabilityState.UNSUPPORTED))
            return
        }
        callback(Result.success(manager.adapter?.state?.toAvailabilityState() ?: AvailabilityState.UNKNOWN))
    }

    override fun hasPermissions(withAndroidFineLocation: Boolean): Boolean {
        val ctx = context
        if (ctx == null) return false
        val permissions = PermissionHandler.getRequiredPermissions(ctx, forScan = true)
        return PermissionHandler.hasPermissions(ctx, permissions)
    }

    override fun requestPermissions(withAndroidFineLocation: Boolean, callback: (Result<Unit>) -> Unit) {
        val ctx = context
        val act = activityBinding?.activity
        if (ctx == null || act == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.FAILED, "Activity is required for permissions")))
            return
        }

        val permissions = PermissionHandler.getRequiredPermissions(ctx, forScan = true)
        if (PermissionHandler.hasPermissions(ctx, permissions)) {
            callback(Result.success(Unit))
            return
        }

        pendingPermissionResult = { granted ->
            handler.post {
                if (granted) {
                    callback(Result.success(Unit))
                } else {
                    callback(Result.failure(createFlutterError(UniversalBleErrorCode.BLUETOOTH_PERMISSION_DENIED, "Permissions denied")))
                }
            }
        }
        permissionLauncher?.launch(permissions.toTypedArray())
            ?: callback(Result.failure(createFlutterError(UniversalBleErrorCode.FAILED, "Cannot launch permission request")))
    }

    override fun enableBluetooth(callback: (Result<Boolean>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.BLUETOOTH_NOT_AVAILABLE, "Bluetooth adapter not available")))
            return
        }
        if (adapter.isEnabled) {
            callback(Result.success(true))
            return
        }

        val act = activityBinding?.activity
        if (act == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.FAILED, "Activity is required to enable Bluetooth")))
            return
        }

        pendingEnableResult = { success ->
            handler.post { callback(Result.success(success)) }
        }
        val enableIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
        enableBluetoothLauncher?.launch(enableIntent)
            ?: callback(Result.failure(createFlutterError(UniversalBleErrorCode.FAILED, "Cannot launch Bluetooth enable intent")))
    }

    override fun disableBluetooth(callback: (Result<Boolean>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.BLUETOOTH_NOT_AVAILABLE, "Bluetooth adapter not available")))
            return
        }
        if (!adapter.isEnabled) {
            callback(Result.success(true))
            return
        }

        try {
            val success = adapter.disable()
            if (success) {
                callback(Result.success(true))
            } else {
                callback(Result.failure(createFlutterError(UniversalBleErrorCode.FAILED, "Failed to disable Bluetooth")))
            }
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Failed to disable Bluetooth: ${e.message}")
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.FAILED, e.message ?: "Unknown error")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun startScan(filter: UniversalScanFilter?, config: UniversalScanConfig?) {
        if (!isBluetoothAvailable()) {
            throw createFlutterError(
                UniversalBleErrorCode.BLUETOOTH_NOT_ENABLED,
                "Bluetooth not enabled"
            )
        }

        val ctx = context
        val adapter = bluetoothAdapter
        if (ctx == null || adapter == null) {
            throw createFlutterError(
                UniversalBleErrorCode.BLUETOOTH_NOT_AVAILABLE,
                "Context or Bluetooth adapter unavailable"
            )
        }

        pendingScanFilter = filter
        pendingScanConfig = config

        val androidOptions = config?.android
        val builder = ScanSettings.Builder()

        androidOptions?.scanMode?.parse()?.let { scanMode ->
            builder.setScanMode(scanMode)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            androidOptions?.reportDelayMillis?.let { delay ->
                builder.setReportDelay(delay)
            }
            val legacy = androidOptions?.legacy
            if (legacy != null) {
                if (legacy) {
                    builder.setLegacy(true)
                } else {
                    builder.setPhy(ScanSettings.PHY_LE_ALL_SUPPORTED)
                    builder.setLegacy(false)
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            androidOptions?.callbackType?.let { types ->
                var combinedType = 0
                for (type in types) {
                    combinedType = combinedType or (type.parse() ?: 0)
                }
                if (combinedType != 0) {
                    builder.setCallbackType(combinedType)
                }
            }

            androidOptions?.matchMode?.parse()?.let { builder.setMatchMode(it) }
            androidOptions?.numOfMatches?.parse()?.let { builder.setNumOfMatches(it) }
        }

        val scanSettings = builder.build()

        val usesCustomFilters = filter?.usesCustomFilters() ?: false
        val scanCallbackInner = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                handleScanResult(result)
            }

            override fun onBatchScanResults(results: List<ScanResult>) {
                for (result in results) {
                    handleScanResult(result)
                }
            }

            override fun onScanFailed(errorCode: Int) {
                PrinterConnectLogger.logError("Scan failed with error code: ${errorCode.parseScanErrorMessage()}")
                handler.post {
                    callbackChannel?.onScanResult(
                        UniversalBleScanResult(
                            deviceId = "",
                            name = null,
                            isPaired = null,
                            rssi = null,
                            manufacturerDataList = null,
                            serviceData = null,
                            services = null,
                            timestamp = System.currentTimeMillis()
                        )
                    ) { _ -> }
                }
            }
        }
        scanCallback = scanCallbackInner

        try {
            val filterServices = filter?.withServices?.toUUIDList() ?: emptyList()
            if (usesCustomFilters) {
                PrinterConnectFilterUtil.scanFilter = filter
                PrinterConnectFilterUtil.serviceFilterUUIDS = filterServices
                safeScanner?.startScan(emptyList(), scanSettings, scanCallbackInner)
            } else {
                PrinterConnectFilterUtil.scanFilter = null
                val scanFilters = filter?.toScanFilters(filterServices) ?: emptyList()
                safeScanner?.startScan(scanFilters, scanSettings, scanCallbackInner)
            }
            isScanning = true
            PrinterConnectLogger.logInfo("Scan started (usesCustomFilters=$usesCustomFilters)")
        } catch (e: SecurityException) {
            PrinterConnectLogger.logError("SecurityException starting scan: ${e.message}")
            throw createFlutterError(
                UniversalBleErrorCode.SCAN_FAILED,
                "Security exception: ${e.message}"
            )
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error starting scan: ${e.message}")
            throw createFlutterError(
                UniversalBleErrorCode.SCAN_FAILED,
                "Failed to start scan: ${e.message}"
            )
        }
    }

    @SuppressLint("MissingPermission")
    private fun handleScanResult(result: ScanResult) {
        val filter = pendingScanFilter
        if (!result.isDeviceMatchingFilter(filter)) {
            return
        }

        val device = result.device
        val address = device.address
        val name = result.resolvedDeviceName
        val isPaired = try {
            device.isBonded()
        } catch (_: Exception) {
            false
        }
        val timestamp = System.currentTimeMillis()

        val serviceUuids = mutableListOf<java.util.UUID>()
        try {
            device.uuids?.forEach { serviceUuids.add(it.uuid) }
        } catch (_: SecurityException) {}
        result.scanRecord?.serviceUuids?.forEach {
            if (!serviceUuids.contains(it.uuid)) {
                serviceUuids.add(it.uuid)
            }
        }

        val deviceServices = serviceUuids.map { it.toString() }
        val scanResult = UniversalBleScanResult(
            deviceId = address,
            name = name,
            isPaired = isPaired,
            rssi = result.rssi.toLong(),
            manufacturerDataList = result.manufacturerDataList(),
            serviceData = result.serviceData(),
            services = deviceServices,
            timestamp = timestamp
        )

        scanResults[address] = scanResult
        handler.post {
            callbackChannel?.onScanResult(scanResult) { _ -> }
        }
        PrinterConnectLogger.logVerbose("Scan result: $address, rssi=${result.rssi}")
    }

    @SuppressLint("MissingPermission")
    private fun stopScanInternal() {
        if (!(safeScanner?.isScanning() ?: false)) return
        val adapter = bluetoothAdapter ?: return
        val scanner = adapter.bluetoothLeScanner ?: return

        try {
            scanner.stopScan(scanCallback)
            PrinterConnectLogger.logInfo("Scan stopped")
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error stopping scan: ${e.message}")
        }

        isScanning = false
        scanCallback = null
        pendingScanFilter = null
        pendingScanConfig = null
    }

    override fun stopScan() {
        if (!isBluetoothAvailable()) {
            throw createFlutterError(
                UniversalBleErrorCode.BLUETOOTH_NOT_ENABLED,
                "Bluetooth not enabled"
            )
        }
        stopScanInternal()
    }

    override fun isScanning(): Boolean {
        return safeScanner?.isScanning() ?: false
    }

    @SuppressLint("MissingPermission")
    override fun connect(
        deviceId: String,
        autoConnect: Boolean?,
        platformConfig: ConnectionPlatformConfig?
    ) {
        val ctx = context
        if (ctx == null) {
            throw createFlutterError(UniversalBleErrorCode.FAILED, "Context unavailable")
        }
        val adapter = bluetoothAdapter
        if (adapter == null) {
            throw createFlutterError(UniversalBleErrorCode.BLUETOOTH_NOT_AVAILABLE, "Bluetooth adapter unavailable")
        }

        deviceId.findGatt()?.let {
            val currentState = bluetoothManager?.getConnectionState(it.device, BluetoothProfile.GATT)
                ?: BluetoothProfile.STATE_DISCONNECTED
            if (currentState == BluetoothProfile.STATE_CONNECTED) {
                PrinterConnectLogger.logDebug("$deviceId Already connected")
                handler.post {
                    callbackChannel?.onConnectionChanged(deviceId, true, null) { _ -> }
                }
                return
            } else if (currentState == BluetoothProfile.STATE_CONNECTING) {
                throw createFlutterError(
                    UniversalBleErrorCode.CONNECTION_IN_PROGRESS,
                    "Connection already in progress"
                )
            }
        }

        val shouldAutoConnect = autoConnect ?: false
        if (shouldAutoConnect) {
            autoConnectDevices.add(deviceId)
        } else {
            autoConnectDevices.remove(deviceId)
        }

        val device = try {
            adapter.getRemoteDevice(deviceId)
        } catch (e: Exception) {
            throw createFlutterError(UniversalBleErrorCode.DEVICE_NOT_FOUND, "Invalid device address: $deviceId")
        }

        try {
            val gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(ctx, shouldAutoConnect, this, BluetoothDevice.TRANSPORT_LE)
            } else {
                device.connectGatt(ctx, shouldAutoConnect, this)
            }
            if (gatt != null) {
                gatt.saveCacheIfNeeded()
                PrinterConnectLogger.logInfo("Connecting to $deviceId (autoConnect=$shouldAutoConnect)")
            } else {
                throw createFlutterError(UniversalBleErrorCode.CONNECTION_FAILED, "Failed to create GATT connection")
            }
        } catch (e: SecurityException) {
            PrinterConnectLogger.logError("SecurityException connecting to $deviceId: ${e.message}")
            throw createFlutterError(UniversalBleErrorCode.CONNECTION_FAILED, e.message ?: "Security exception")
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error connecting to $deviceId: ${e.message}")
            throw createFlutterError(UniversalBleErrorCode.CONNECTION_FAILED, e.message ?: "Unknown error")
        }
    }

    @SuppressLint("MissingPermission")
    override fun disconnect(deviceId: String) {
        autoConnectDevices.remove(deviceId)
        val gatt = deviceId.findGatt()
        if (gatt == null) {
            cleanUpConnection(deviceId)
            handler.post {
                callbackChannel?.onConnectionChanged(deviceId, false, null) { _ -> }
            }
        } else {
            cleanConnection(gatt)
        }
    }

    override fun getConnectionState(deviceId: String): BleConnectionState {
        return try {
            val connectionState = bluetoothManager?.getConnectionState(
                deviceId.toBluetoothGatt().device,
                BluetoothProfile.GATT
            ) ?: BluetoothProfile.STATE_DISCONNECTED
            if (deviceId.isKnownGatt() || connectionState == BluetoothProfile.STATE_DISCONNECTED || connectionState == BluetoothProfile.STATE_DISCONNECTING) {
                connectionState.toBleConnectionState()
            } else {
                PrinterConnectLogger.logError("Device might be connected but not known to this app")
                BleConnectionState.DISCONNECTED
            }
        } catch (_: Exception) {
            BleConnectionState.DISCONNECTED
        }
    }

    override fun setLogLevel(logLevel: BleLogLevel) {
        PrinterConnectLogger.setLogLevel(logLevel)
    }

    @SuppressLint("MissingPermission")
    override fun discoverServices(
        deviceId: String,
        withDescriptors: Boolean,
        callback: (Result<List<UniversalBleService>>) -> Unit
    ) {
        val gatt = deviceId.findGatt()
        if (gatt == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.DEVICE_NOT_FOUND, "No GATT connection for $deviceId")))
            return
        }

        val wrappedCallback: (Result<List<UniversalBleService>>) -> Unit = { result ->
            callback(result.map { services ->
                if (withDescriptors) {
                    services
                } else {
                    services.map { service ->
                        service.copy(
                            characteristics = service.characteristics?.map { char ->
                                char.copy(descriptors = listOf())
                            }
                        )
                    }
                }
            })
        }

        cachedServices[deviceId]?.let { services ->
            handler.post { wrappedCallback(Result.success(services)) }
            return
        }

        try {
            val pendingList = discoverFutures.getOrPut(deviceId) { mutableListOf() }
            pendingList.add(wrappedCallback)

            if (pendingList.size == 1) {
                val success = gatt.discoverServices()
                if (!success) {
                    discoverFutures.remove(deviceId)
                    callback(Result.failure(createFlutterError(UniversalBleErrorCode.DISCOVER_SERVICES_FAILED, "Failed to discover services")))
                    return
                }
            }
        } catch (e: Exception) {
            discoverFutures.remove(deviceId)
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.DISCOVER_SERVICES_FAILED, e.message ?: "Unknown error")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun setNotifiable(
        deviceId: String,
        service: String,
        characteristic: String,
        bleInputProperty: BleInputProperty,
        callback: (Result<Unit>) -> Unit
    ) {
        val gatt = deviceId.findGatt()
        if (gatt == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.DEVICE_NOT_FOUND, "No GATT connection for $deviceId")))
            return
        }

        val gattCharacteristic = gatt.getCharacteristic(service, characteristic)
        if (gattCharacteristic == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.CHARACTERISTIC_NOT_FOUND, "Characteristic not found: $characteristic")))
            return
        }

        try {
            val enable = when (bleInputProperty) {
                BleInputProperty.NOTIFICATION -> true
                BleInputProperty.INDICATION -> true
                BleInputProperty.DISABLED -> false
            }

            val ccdValue = when (bleInputProperty) {
                BleInputProperty.NOTIFICATION -> BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                BleInputProperty.INDICATION -> BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                else -> BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
            }

            val descriptor = gattCharacteristic.getDescriptor(ccdCharacteristic)

            if (descriptor != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val status = gatt.writeDescriptor(descriptor, ccdValue)
                    if (status != BluetoothStatusCodes.SUCCESS) {
                        callback(Result.failure(createFlutterError(status.parseBluetoothStatusCodeError()
                            ?: UniversalBleErrorCode.SET_NOTIFY_FAILED, "Failed to update descriptor")))
                        return
                    }
                } else {
                    descriptor.value = ccdValue
                    @Suppress("DEPRECATION")
                    if (!gatt.writeDescriptor(descriptor)) {
                        callback(Result.failure(createFlutterError(UniversalBleErrorCode.SET_NOTIFY_FAILED, "Failed to write descriptor")))
                        return
                    }
                }
            } else {
                PrinterConnectLogger.logDebug("CCCD Descriptor not found for $characteristic")
            }

            if (gatt.setCharacteristicNotification(gattCharacteristic, enable)) {
                if (descriptor != null) {
                    val subKey = "$deviceId/$service/$characteristic"
                    subscriptionFutures[subKey] = callback
                } else {
                    callback(Result.success(Unit))
                }
            } else {
                callback(Result.failure(createFlutterError(UniversalBleErrorCode.SET_NOTIFY_FAILED, "Failed to set notification")))
            }
            PrinterConnectLogger.logDebug("Set notifiable for $characteristic: enable=$enable")
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error setting notifiable: ${e.message}")
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.SET_NOTIFY_FAILED, e.message ?: "Unknown error")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun readValue(
        deviceId: String,
        service: String,
        characteristic: String,
        callback: (Result<ByteArray>) -> Unit
    ) {
        val gatt = deviceId.findGatt()
        if (gatt == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.DEVICE_NOT_FOUND, "No GATT connection for $deviceId")))
            return
        }

        val gattCharacteristic = gatt.getCharacteristic(service, characteristic)
        if (gattCharacteristic == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.CHARACTERISTIC_NOT_FOUND, "Characteristic not found: $characteristic")))
            return
        }

        if (gattCharacteristic.properties and BluetoothGattCharacteristic.PROPERTY_READ == 0) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.CHARACTERISTIC_DOES_NOT_SUPPORT_READ, "Characteristic does not support read")))
            return
        }

        try {
            val key = "$deviceId/$service/$characteristic"
            readFutures[key] = callback
            if (!gatt.readCharacteristic(gattCharacteristic)) {
                readFutures.remove(key)
                callback(Result.failure(createFlutterError(UniversalBleErrorCode.READ_FAILED, "Failed to initiate read")))
            }
        } catch (e: Exception) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.READ_FAILED, e.message ?: "Unknown error")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun writeValue(
        deviceId: String,
        service: String,
        characteristic: String,
        value: ByteArray,
        bleOutputProperty: BleOutputProperty,
        callback: (Result<Unit>) -> Unit
    ) {
        val gatt = deviceId.findGatt()
        if (gatt == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.DEVICE_NOT_FOUND, "No GATT connection for $deviceId")))
            return
        }

        val gattCharacteristic = gatt.getCharacteristic(service, characteristic)
        if (gattCharacteristic == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.CHARACTERISTIC_NOT_FOUND, "Characteristic not found: $characteristic")))
            return
        }

        try {
            var writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            if (bleOutputProperty == BleOutputProperty.WITH_RESPONSE) {
                if (gattCharacteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE == 0) {
                    callback(Result.failure(createFlutterError(UniversalBleErrorCode.CHARACTERISTIC_DOES_NOT_SUPPORT_WRITE, "Characteristic does not support write withResponse")))
                    return
                }
            } else if (bleOutputProperty == BleOutputProperty.WITHOUT_RESPONSE) {
                if (gattCharacteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE == 0) {
                    callback(Result.failure(createFlutterError(UniversalBleErrorCode.CHARACTERISTIC_DOES_NOT_SUPPORT_WRITE_WITHOUT_RESPONSE, "Characteristic does not support write withoutResponse")))
                    return
                }
                writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            }

            val key = "$deviceId/$service/$characteristic"
            synchronized(writeFutures) {
                writeFutures[key] = callback
            }

            val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeCharacteristic(gattCharacteristic, value, writeType)
            } else {
                @Suppress("DEPRECATION")
                gattCharacteristic.value = value
                gattCharacteristic.writeType = writeType
                @Suppress("DEPRECATION")
                val success = gatt.writeCharacteristic(gattCharacteristic)
                if (success) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_FAILURE
            }

            if (result != BluetoothGatt.GATT_SUCCESS) {
                synchronized(writeFutures) {
                    writeFutures.remove(key)
                }
                callback(Result.failure(createFlutterError(gattStatusToPrinterConnectErrorCode(result), "Failed to write", result.toString())))
            }
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error writing value: ${e.message}")
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.WRITE_FAILED, e.message ?: "Unknown error")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun requestMtu(deviceId: String, expectedMtu: Long, callback: (Result<Long>) -> Unit) {
        val gatt = deviceId.findGatt()
        if (gatt == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.DEVICE_NOT_FOUND, "No GATT connection for $deviceId")))
            return
        }

        try {
            mtuFutures[deviceId] = callback
            gatt.requestMtu(expectedMtu.toInt())
        } catch (e: Exception) {
            mtuFutures.remove(deviceId)
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.MTU_REQUEST_FAILED, e.message ?: "Unknown error")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun readRssi(deviceId: String, callback: (Result<Long>) -> Unit) {
        val gatt = deviceId.findGatt()
        if (gatt == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.DEVICE_NOT_FOUND, "No GATT connection for $deviceId")))
            return
        }

        try {
            rssiFutures[deviceId] = callback
            if (!gatt.readRemoteRssi()) {
                rssiFutures.remove(deviceId)
                callback(Result.failure(createFlutterError(UniversalBleErrorCode.READ_FAILED, "Failed to read RSSI")))
            }
        } catch (e: Exception) {
            rssiFutures.remove(deviceId)
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.READ_FAILED, e.message ?: "Unknown error")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun requestConnectionPriority(
        deviceId: String,
        priority: BleConnectionPriority,
        callback: (Result<Unit>) -> Unit
    ) {
        val gatt = deviceId.findGatt()
        if (gatt == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.DEVICE_NOT_FOUND, "No GATT connection for $deviceId")))
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.NOT_SUPPORTED, "requestConnectionPriority requires API 23+")))
            return
        }

        try {
            val connectionPriority = when (priority) {
                BleConnectionPriority.BALANCED -> BluetoothGatt.CONNECTION_PRIORITY_BALANCED
                BleConnectionPriority.HIGH_PERFORMANCE -> BluetoothGatt.CONNECTION_PRIORITY_HIGH
                BleConnectionPriority.LOW_POWER -> BluetoothGatt.CONNECTION_PRIORITY_LOW_POWER
            }
            val success = gatt.requestConnectionPriority(connectionPriority)
            if (success) {
                callback(Result.success(Unit))
            } else {
                callback(Result.failure(createFlutterError(UniversalBleErrorCode.FAILED, "requestConnectionPriority returned false")))
            }
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error requesting connection priority: ${e.message}")
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.FAILED, e.message ?: "Unknown error")))
        }
    }

    override fun isPaired(deviceId: String, callback: (Result<Boolean>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.success(false))
            return
        }
        return try {
            val device = adapter.getRemoteDevice(deviceId)
            callback(Result.success(device.isBonded()))
        } catch (e: Exception) {
            callback(Result.success(false))
        }
    }

    @SuppressLint("MissingPermission")
    override fun pair(deviceId: String, callback: (Result<Boolean>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.BLUETOOTH_NOT_AVAILABLE, "Bluetooth adapter unavailable")))
            return
        }

        try {
            val device = adapter.getRemoteDevice(deviceId)
            if (device.isBonded()) {
                callback(Result.success(true))
                return
            }

            val pendingFuture = pendingPairResults[deviceId]
            if (pendingFuture != null) {
                callback(Result.failure(createFlutterError(UniversalBleErrorCode.OPERATION_IN_PROGRESS, "Pairing already in progress")))
                return
            }

            if (device.createBond()) {
                pendingPairResults[deviceId] = callback
            } else {
                callback(Result.failure(createFlutterError(UniversalBleErrorCode.PAIRING_FAILED, "Failed to pair")))
            }
        } catch (e: Exception) {
            pendingPairResults.remove(deviceId)
            PrinterConnectLogger.logError("Error pairing: ${e.message}")
            callback(Result.failure(createFlutterError(UniversalBleErrorCode.FAILED, e.toString())))
        }
    }

    @SuppressLint("MissingPermission")
    override fun unPair(deviceId: String) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            return
        }

        try {
            val device = adapter.getRemoteDevice(deviceId)
            if (device.isBonded()) {
                device.removeBond()
                PrinterConnectLogger.logInfo("Unpairing from $deviceId")
            }
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error unpairing: ${e.message}")
        }
    }

    @SuppressLint("MissingPermission")
    override fun getSystemDevices(withServices: List<String>, callback: (Result<List<UniversalBleScanResult>>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.success(emptyList()))
            return
        }

        val context = this.context
        if (context == null) {
            callback(Result.success(emptyList()))
            return
        }

        val connectedDevices = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                bluetoothManager?.getConnectedDevices(BluetoothProfile.GATT)
                    ?: emptyList<BluetoothDevice>()
            } else {
                @Suppress("DEPRECATION")
                adapter.bondedDevices.toList()
            }
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error getting connected devices: ${e.message}")
            emptyList<BluetoothDevice>()
        }

        val results = connectedDevices.mapNotNull { device ->
            val deviceServices = getDeviceServiceUuids(device)
            val matchesFilter = withServices.isEmpty() || deviceServices.isEmpty() || deviceServices.containsAll(withServices)

            if (!matchesFilter) return@mapNotNull null

            UniversalBleScanResult(
                deviceId = device.address,
                name = device.name,
                isPaired = device.isBonded(),
                rssi = null,
                manufacturerDataList = null,
                serviceData = null,
                services = deviceServices,
                timestamp = System.currentTimeMillis()
            )
        }
        callback(Result.success(results))
    }

    @SuppressLint("MissingPermission")
    private fun getDeviceServiceUuids(device: BluetoothDevice): List<String> {
        val gatt = device.address.findGatt()
        if (gatt != null) {
            return try {
                gatt.services.map { it.uuid.toString() }
            } catch (_: Exception) {
                emptyList()
            }
        }
        return cachedServices[device.address]?.map { it.uuid } ?: emptyList()
    }

    override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
        val deviceAddress = gatt.device.address
        PrinterConnectLogger.logDebug("GATT connection state changed: $deviceAddress, status=$status, newState=$newState")

        if (newState == BluetoothProfile.STATE_CONNECTED) {
            gatt.saveCacheIfNeeded()
            PrinterConnectLogger.logInfo("Connected to $deviceAddress")
            postToMainLooper {
                callbackChannel?.onConnectionChanged(
                    deviceAddress, true, status.parseHciErrorCode()
                ) { _ -> }
            }
        } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
            val shouldAutoConnect = autoConnectDevices.contains(deviceAddress)

            cleanUpConnection(deviceAddress)

            postToMainLooper {
                callbackChannel?.onConnectionChanged(
                    deviceAddress, false, status.parseHciErrorCode()
                ) { _ -> }
            }

            if (!shouldAutoConnect) {
                gatt.removeCache()
                gatt.disconnect()
                PrinterConnectLogger.logDebug("Closing gatt for ${gatt.device.name}")
                gatt.close()
            } else {
                PrinterConnectLogger.logDebug("Keeping GATT open for auto-reconnect on $deviceAddress")
            }
        }
    }

    override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
        val deviceAddress = gatt.device.address
        PrinterConnectLogger.logDebug("Services discovered for $deviceAddress, status=$status")

        val pendingList = discoverFutures.remove(deviceAddress)
        if (pendingList.isNullOrEmpty()) {
            PrinterConnectLogger.logWarning("No pending discoverServices for $deviceAddress")
            return
        }

        if (status != BluetoothGatt.GATT_SUCCESS) {
            PrinterConnectLogger.logError("Service discovery failed for $deviceAddress with status: $status")
            val error = Result.failure<List<UniversalBleService>>(
                createFlutterError(UniversalBleErrorCode.DISCOVER_SERVICES_FAILED, "Service discovery failed with status: $status")
            )
            for (callback in pendingList) {
                handler.post { callback.invoke(error) }
            }
            return
        }

        gatt.saveCacheIfNeeded()
        val services = gatt.services.map { service ->
            val characteristics = service.characteristics.map { char ->
                val descriptors = char.descriptors.map { desc ->
                    UniversalBleDescriptor(uuid = desc.uuid.toString())
                }
                UniversalBleCharacteristic(
                    uuid = char.uuid.toString(),
                    properties = char.getPropertiesList(),
                    descriptors = descriptors
                )
            }
            UniversalBleService(
                uuid = service.uuid.toString(),
                characteristics = characteristics
            )
        }
        cachedServices[deviceAddress] = services
        for (callback in pendingList) {
            handler.post { callback.invoke(Result.success(services)) }
        }
    }

    override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
        val deviceAddress = gatt.device.address
        val serviceUuid = characteristic.service.uuid.toString()
        val charUuid = characteristic.uuid.toString()
        PrinterConnectLogger.logDebug("Characteristic read for $deviceAddress/$serviceUuid/$charUuid, status=$status")

        val key = "$deviceAddress/$serviceUuid/$charUuid"
        synchronized(readFutures) {
            val future = readFutures.remove(key)
            if (future != null) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    handler.post { future.invoke(Result.success(value)) }
                } else {
                    handler.post { future.invoke(Result.failure(createFlutterError(gattStatusToPrinterConnectErrorCode(status), "Read failed with status: $status"))) }
                }
            }
        }
    }

    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
        onCharacteristicRead(gatt, characteristic, characteristic.value ?: ByteArray(0), status)
    }

    override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
        val deviceAddress = gatt.device.address
        val serviceUuid = characteristic.service.uuid.toString()
        val charUuid = characteristic.uuid.toString()
        PrinterConnectLogger.logDebug("Characteristic write for $deviceAddress/$serviceUuid/$charUuid, status=$status")

        val key = "$deviceAddress/$serviceUuid/$charUuid"
        val future: ((Result<Unit>) -> Unit)?
        synchronized(writeFutures) {
            future = writeFutures.remove(key)
        }
        if (future != null) {
            postToMainLooper {
                try {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        future.invoke(Result.success(Unit))
                    } else {
                        future.invoke(Result.failure(createFlutterError(gattStatusToPrinterConnectErrorCode(status), "Write failed with status: $status")))
                    }
                } catch (e: Exception) {
                    PrinterConnectLogger.logError("Write completion delivery failed: $e")
                }
            }
        }
    }

    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
        val deviceAddress = gatt.device.address
        val charUuid = characteristic.uuid.toString()
        val timestamp = System.currentTimeMillis()
        PrinterConnectLogger.logDebug("Characteristic changed for $deviceAddress/$charUuid")
        postToMainLooper {
            callbackChannel?.onValueChanged(deviceAddress, charUuid, value, timestamp) { _ -> }
        }
    }

    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
        onCharacteristicChanged(gatt, characteristic, characteristic.value ?: ByteArray(0))
    }

    override fun onDescriptorRead(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
        val deviceAddress = gatt.device.address
        val descUuid = descriptor.uuid.toString()
        PrinterConnectLogger.logDebug("Descriptor read for $deviceAddress/$descUuid, status=$status")

        val key = "$deviceAddress/$descUuid"
        val future = descriptorReadFutures.remove(key)
        if (future != null) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val valueBytes = descriptor.value ?: ByteArray(0)
                handler.post { future.invoke(Result.success(valueBytes)) }
            } else {
                handler.post { future.invoke(Result.failure(createFlutterError(UniversalBleErrorCode.READ_FAILED, "Descriptor read failed with status: $status"))) }
            }
        }
    }

    override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
        val deviceAddress = gatt.device.address
        val descUuid = descriptor.uuid.toString()
        PrinterConnectLogger.logDebug("Descriptor write for $deviceAddress/$descUuid, status=$status")

        if (descriptor.uuid == ccdCharacteristic) {
            val charUuid = descriptor.characteristic?.uuid?.toString() ?: return
            val serviceUuid = descriptor.characteristic?.service?.uuid?.toString() ?: return
            val subKey = "$deviceAddress/$serviceUuid/$charUuid"

            val future = subscriptionFutures.remove(subKey)
            if (future != null) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    handler.post { future.invoke(Result.success(Unit)) }
                } else {
                    handler.post { future.invoke(Result.failure(createFlutterError(gattStatusToPrinterConnectErrorCode(status), "Failed to update subscription state"))) }
                }
            }
        } else {
            val key = "$deviceAddress/$descUuid"
            val future = descriptorWriteFutures.remove(key)
            if (future != null) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    handler.post { future.invoke(Result.success(Unit)) }
                } else {
                    handler.post { future.invoke(Result.failure(createFlutterError(gattStatusToPrinterConnectErrorCode(status), "Descriptor write failed with status: $status"))) }
                }
            }
        }
    }

    override fun onMtuChanged(gatt: BluetoothGatt?, mtu: Int, status: Int) {
        val deviceAddress = gatt?.device?.address ?: return
        PrinterConnectLogger.logDebug("MTU changed for $deviceAddress: mtu=$mtu, status=$status")

        val future = mtuFutures.remove(deviceAddress)
        if (future != null) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val updated = BleConnectionParametersUpdated(
                    deviceId = deviceAddress,
                    interval = 0L,
                    latency = 0L,
                    supervisionTimeout = 0L,
                    status = mtu.toLong()
                )
                postToMainLooper {
                    callbackChannel?.onConnectionParametersUpdated(updated) { _ -> }
                }
                handler.post { future.invoke(Result.success(mtu.toLong())) }
            } else {
                handler.post { future.invoke(Result.failure(createFlutterError(UniversalBleErrorCode.MTU_REQUEST_FAILED, "MTU change failed with status: $status"))) }
            }
        }
    }

    @Suppress("unused")
    fun onConnectionUpdated(
        gatt: BluetoothGatt?,
        interval: Int,
        latency: Int,
        timeout: Int,
        status: Int
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val deviceAddress = gatt?.device?.address ?: return
        PrinterConnectLogger.logDebug(
            "Connection updated for $deviceAddress: interval=$interval, latency=$latency, timeout=$timeout, status=$status"
        )

        val updated = BleConnectionParametersUpdated(
            deviceId = deviceAddress,
            interval = interval.toLong(),
            latency = latency.toLong(),
            supervisionTimeout = timeout.toLong(),
            status = status.toLong()
        )
        postToMainLooper {
            callbackChannel?.onConnectionParametersUpdated(updated) { _ -> }
        }
    }

    override fun onReadRemoteRssi(gatt: BluetoothGatt, rssi: Int, status: Int) {
        val deviceAddress = gatt.device.address
        PrinterConnectLogger.logDebug("RSSI read for $deviceAddress: rssi=$rssi, status=$status")

        val future = rssiFutures.remove(deviceAddress)
        if (future != null) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                handler.post { future.invoke(Result.success(rssi.toLong())) }
            } else {
                handler.post { future.invoke(Result.failure(createFlutterError(UniversalBleErrorCode.READ_FAILED, "RSSI read failed with status: $status"))) }
            }
        }
    }
}
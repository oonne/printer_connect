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
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import java.util.concurrent.ConcurrentHashMap

class PrinterConnectPlugin : FlutterPlugin, ActivityAware, UniversalBlePlatformChannel {

    private lateinit var binaryMessenger: BinaryMessenger
    private var activityBinding: ActivityPluginBinding? = null
    private var context: Context? = null

    private var callbackChannel: UniversalBleCallbackChannel? = null

    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null

    private var scanCallback: ScanCallback? = null
    private var isScanning: Boolean = false
    private var pendingScanFilters: List<UniversalScanFilter>? = null

    private val gattServers = ConcurrentHashMap<String, BluetoothGatt>()
    private val scanResults = mutableMapOf<String, UniversalBleScanResult>()

    private val handler = Handler(Looper.getMainLooper())

    private var permissionLauncher: ActivityResultLauncher<String>? = null
    private var pendingPermissionResult: ((Boolean) -> Unit)? = null

    private var enableBluetoothLauncher: ActivityResultLauncher<Intent>? = null
    private var pendingEnableResult: ((Boolean) -> Unit)? = null

    private val bondStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val bondStateChange = intent?.getBondStateChange() ?: return
            val deviceAddress = bondStateChange.deviceAddress
            val isPaired = bondStateChange.bondState == BluetoothDevice.BOND_BONDED
            sendPairStateChange(deviceAddress, isPaired)
            PrinterConnectLogger.logDebug("Bond state changed for $deviceAddress: bonded=$isPaired")
        }
    }

    private val bluetoothStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            if (action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                val availabilityState = state.toAvailabilityState()
                sendAvailabilityChanged(availabilityState)
                PrinterConnectLogger.logDebug("Bluetooth state changed: $availabilityState")
            }
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val deviceAddress = gatt.device.address
            PrinterConnectLogger.logDebug("GATT connection state changed: $deviceAddress, status=$status, newState=$newState")

            if (status != BluetoothGatt.GATT_SUCCESS) {
                PrinterConnectLogger.logError("Connection failed for $deviceAddress with status: $status")
                gatt.close()
                gattServers.remove(deviceAddress)
                sendConnectionChanged(deviceAddress, BleConnectionState.DISCONNECTED)
                return
            }

            val bleState = newState.toBleConnectionState()
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    gattServers[deviceAddress] = gatt
                    PrinterConnectLogger.logInfo("Connected to $deviceAddress")
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    gatt.close()
                    gattServers.remove(deviceAddress)
                    PrinterConnectLogger.logInfo("Disconnected from $deviceAddress")
                }
            }
            sendConnectionChanged(deviceAddress, bleState)
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val deviceAddress = gatt.device.address
            PrinterConnectLogger.logDebug("Services discovered for $deviceAddress, status=$status")

            if (status != BluetoothGatt.GATT_SUCCESS) {
                PrinterConnectLogger.logError("Service discovery failed for $deviceAddress with status: $status")
                return
            }

            gatt.saveCacheIfNeeded()
        }

        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            val deviceAddress = gatt.device.address
            val serviceUuid = characteristic.service.uuid.toString()
            val charUuid = characteristic.uuid.toString()
            PrinterConnectLogger.logDebug("Characteristic read for $deviceAddress/$serviceUuid/$charUuid, status=$status")

            if (status == BluetoothGatt.GATT_SUCCESS) {
                val valueBytes = characteristic.value
                val valueList = valueBytes?.map { it.toLong() and 0xFFL } ?: emptyList()
                PrinterConnectLogger.logVerbose("Read value: $valueList")
            }
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            val deviceAddress = gatt.device.address
            val serviceUuid = characteristic.service.uuid.toString()
            val charUuid = characteristic.uuid.toString()
            PrinterConnectLogger.logDebug("Characteristic write for $deviceAddress/$serviceUuid/$charUuid, status=$status")
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            val deviceAddress = gatt.device.address
            val serviceUuid = characteristic.service.uuid.toString()
            val charUuid = characteristic.uuid.toString()
            val valueBytes = characteristic.value
            val valueList = valueBytes?.map { it.toLong() and 0xFFL } ?: emptyList()
            PrinterConnectLogger.logDebug("Characteristic changed for $deviceAddress/$serviceUuid/$charUuid")
            sendValueChanged(deviceAddress, serviceUuid, charUuid, valueList)
        }

        override fun onDescriptorRead(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            val deviceAddress = gatt.device.address
            val descUuid = descriptor.uuid.toString()
            PrinterConnectLogger.logDebug("Descriptor read for $deviceAddress/$descUuid, status=$status")
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            val deviceAddress = gatt.device.address
            val descUuid = descriptor.uuid.toString()
            PrinterConnectLogger.logDebug("Descriptor write for $deviceAddress/$descUuid, status=$status")
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            val deviceAddress = gatt.device.address
            PrinterConnectLogger.logDebug("MTU changed for $deviceAddress: mtu=$mtu, status=$status")
            if (status == BluetoothGatt.GATT_SUCCESS) {
                sendConnectionParametersUpdated(BleConnectionParametersUpdated(mtu.toLong()))
            }
        }

        override fun onReadRemoteRssi(gatt: BluetoothGatt, rssi: Int, status: Int) {
            val deviceAddress = gatt.device.address
            PrinterConnectLogger.logDebug("RSSI read for $deviceAddress: rssi=$rssi, status=$status")
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.binaryMessenger = binding.binaryMessenger
        this.context = binding.applicationContext

        bluetoothManager = context?.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter

        callbackChannel = UniversalBleCallbackChannel(binaryMessenger)
        UniversalBlePlatformChannel.setUp(binaryMessenger, this)

        registerBluetoothStateReceiver()
        registerBondStateReceiver()

        PrinterConnectLogger.logInfo("PrinterConnectPlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        unregisterBluetoothStateReceiver()
        unregisterBondStateReceiver()
        stopScanInternal()
        closeAllGattConnections()
        UniversalBlePlatformChannel.setUp(binaryMessenger, null)
        callbackChannel = null
        PrinterConnectLogger.logInfo("PrinterConnectPlugin detached from engine")
    }

    private fun sendAvailabilityChanged(state: AvailabilityState) {
        callbackChannel?.onAvailabilityChanged(state) { _ -> }
    }

    private fun sendPairStateChange(peripheralId: String, isPaired: Boolean) {
        callbackChannel?.onPairStateChange(peripheralId, isPaired) { _ -> }
    }

    private fun sendScanResult(result: UniversalBleScanResult) {
        callbackChannel?.onScanResult(result) { _ -> }
    }

    private fun sendValueChanged(peripheralId: String, serviceId: String, characteristicId: String, value: List<Long>) {
        callbackChannel?.onValueChanged(peripheralId, serviceId, characteristicId, value) { _ -> }
    }

    private fun sendConnectionChanged(peripheralId: String, state: BleConnectionState) {
        callbackChannel?.onConnectionChanged(peripheralId, state) { _ -> }
    }

    private fun sendConnectionParametersUpdated(result: BleConnectionParametersUpdated) {
        callbackChannel?.onConnectionParametersUpdated(result) { _ -> }
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
        permissionLauncher = binding.activity.registerForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions()
        ) { grants ->
            val allGranted = grants.values.all { it }
            pendingPermissionResult?.invoke(allGranted)
            pendingPermissionResult = null
            PrinterConnectLogger.logDebug("Permission result: $allGranted")
        }
    }

    private fun setupEnableBluetoothLauncher(binding: ActivityPluginBinding) {
        enableBluetoothLauncher = binding.activity.registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { result ->
            val success = result.resultCode == android.app.Activity.RESULT_OK
            pendingEnableResult?.invoke(success)
            pendingEnableResult = null
            PrinterConnectLogger.logDebug("Enable Bluetooth result: $success")
        }
    }

    private fun registerBluetoothStateReceiver() {
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        context?.registerReceiverCompat(bluetoothStateReceiver, filter)
    }

    private fun unregisterBluetoothStateReceiver() {
        try {
            context?.unregisterReceiver(bluetoothStateReceiver)
        } catch (_: Exception) {}
    }

    private fun registerBondStateReceiver() {
        val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        context?.registerReceiverCompat(bondStateReceiver, filter)
    }

    private fun unregisterBondStateReceiver() {
        try {
            context?.unregisterReceiver(bondStateReceiver)
        } catch (_: Exception) {}
    }

    private fun closeAllGattConnections() {
        for ((_, gatt) in gattServers) {
            try {
                gatt.close()
            } catch (_: Exception) {}
        }
        gattServers.clear()
    }

    override fun getBluetoothAvailabilityState(callback: (Result<AvailabilityState>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.success(AvailabilityState.UNSUPPORTED))
            return
        }
        callback(Result.success(adapter.state.toAvailabilityState()))
    }

    override fun hasPermissions(callback: (Result<Boolean>) -> Unit) {
        val ctx = context
        if (ctx == null) {
            callback(Result.success(false))
            return
        }
        val permissions = PermissionHandler.getRequiredPermissions(ctx, forScan = true)
        callback(Result.success(PermissionHandler.hasPermissions(ctx, permissions)))
    }

    override fun requestPermissions(callback: (Result<Boolean>) -> Unit) {
        val ctx = context
        val act = activityBinding?.activity
        if (ctx == null || act == null) {
            callback(Result.success(false))
            return
        }

        val permissions = PermissionHandler.getRequiredPermissions(ctx, forScan = true)
        if (PermissionHandler.hasPermissions(ctx, permissions)) {
            callback(Result.success(true))
            return
        }

        pendingPermissionResult = { granted ->
            handler.post { callback(Result.success(granted)) }
        }
        permissionLauncher?.launch(permissions.toTypedArray())
            ?: callback(Result.success(false))
    }

    override fun enableBluetooth(callback: (Result<Unit>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.failure(FlutterError("bluetooth_unavailable", "Bluetooth adapter not available", null)))
            return
        }
        if (adapter.isEnabled) {
            callback(Result.success(Unit))
            return
        }

        val act = activityBinding?.activity
        if (act == null) {
            callback(Result.failure(FlutterError("no_activity", "Activity is required to enable Bluetooth", null)))
            return
        }

        pendingEnableResult = { success ->
            handler.post {
                if (success) {
                    callback(Result.success(Unit))
                } else {
                    callback(Result.failure(FlutterError("enable_failed", "Failed to enable Bluetooth", null)))
                }
            }
        }
        val enableIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
        enableBluetoothLauncher?.launch(enableIntent)
            ?: callback(Result.failure(FlutterError("launch_failed", "Cannot launch Bluetooth enable intent", null)))
    }

    override fun disableBluetooth(callback: (Result<Unit>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.failure(FlutterError("bluetooth_unavailable", "Bluetooth adapter not available", null)))
            return
        }
        if (!adapter.isEnabled) {
            callback(Result.success(Unit))
            return
        }

        try {
            val success = adapter.disable()
            if (success) {
                callback(Result.success(Unit))
            } else {
                callback(Result.failure(FlutterError("disable_failed", "Failed to disable Bluetooth", null)))
            }
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Failed to disable Bluetooth: ${e.message}")
            callback(Result.failure(FlutterError("disable_error", e.message ?: "Unknown error", null)))
        }
    }

    @SuppressLint("MissingPermission")
    override fun startScan(
        filters: List<UniversalScanFilter>,
        androidOptions: AndroidOptions,
        callback: (Result<Unit>) -> Unit
    ) {
        val ctx = context
        val adapter = bluetoothAdapter
        if (ctx == null || adapter == null) {
            callback(Result.failure(FlutterError("no_context", "Context or Bluetooth adapter unavailable", null)))
            return
        }

        if (!adapter.isEnabled) {
            PrinterConnectLogger.logWarning("Bluetooth is not enabled, cannot start scan")
            callback(Result.failure(FlutterError("bluetooth_off", "Bluetooth is not enabled", null)))
            return
        }

        if (!SafeScanner.getInstance().canStartScan()) {
            val waitTime = SafeScanner.getInstance().getTimeUntilNextScanMs()
            PrinterConnectLogger.logWarning("Scan frequency limit reached. Waiting ${waitTime}ms")
            handler.postDelayed({
                startScan(filters, androidOptions, callback)
            }, waitTime)
            return
        }

        SafeScanner.getInstance().recordScanStart()
        pendingScanFilters = filters

        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            PrinterConnectLogger.logError("Cannot get BluetoothLeScanner")
            pendingScanFilters = null
            callback(Result.failure(FlutterError("scanner_unavailable", "BluetoothLeScanner unavailable", null)))
            return
        }

        val scanSettings = buildScanSettings(androidOptions)
        val scanFilters = buildScanFilters(filters)

        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                handleScanResult(result)
            }

            override fun onBatchScanResults(results: List<ScanResult>) {
                for (result in results) {
                    handleScanResult(result)
                }
            }

            override fun onScanFailed(errorCode: Int) {
                PrinterConnectLogger.logError("Scan failed with error code: $errorCode")
                isScanning = false
                handler.post {
                    callback(Result.failure(FlutterError("scan_failed", "Scan failed with error code: $errorCode", errorCode)))
                }
            }
        }

        try {
            if (scanFilters.isNotEmpty()) {
                scanner.startScan(scanFilters, scanSettings, scanCallback)
            } else {
                scanner.startScan(null, scanSettings, scanCallback)
            }
            isScanning = true
            PrinterConnectLogger.logInfo("Scan started with ${scanFilters.size} filters")
            callback(Result.success(Unit))
        } catch (e: SecurityException) {
            PrinterConnectLogger.logError("SecurityException starting scan: ${e.message}")
            isScanning = false
            callback(Result.failure(FlutterError("security_error", e.message ?: "Security exception", null)))
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error starting scan: ${e.message}")
            isScanning = false
            callback(Result.failure(FlutterError("scan_error", e.message ?: "Unknown error", null)))
        }
    }

    @SuppressLint("MissingPermission")
    private fun handleScanResult(result: ScanResult) {
        val filters = pendingScanFilters
        if (!PrinterConnectFilterUtil.filterDevice(result, filters)) {
            return
        }

        val device = result.device
        val address = device.address
        val name = device.name

        val scanResult = UniversalBleScanResult(
            peripheralId = address,
            name = name,
            rssi = result.rssi.toLong(),
            manufacturerData = result.manufacturerDataList(),
            serviceData = result.serviceData(),
            serviceUuids = result.serviceUuids(),
            txPowerLevel = result.scanRecord?.txPowerLevel?.toLong()
        )

        scanResults[address] = scanResult
        sendScanResult(scanResult)
        PrinterConnectLogger.logVerbose("Scan result: $address, rssi=${result.rssi}")
    }

    private fun buildScanSettings(options: AndroidOptions): ScanSettings {
        val builder = ScanSettings.Builder()

        options.scanMode?.let { mode ->
            val scanMode = when (mode) {
                AndroidScanMode.LOW_POWERED -> ScanSettings.SCAN_MODE_LOW_POWER
                AndroidScanMode.BALANCED -> ScanSettings.SCAN_MODE_BALANCED
                AndroidScanMode.LOW_LATENCY -> ScanSettings.SCAN_MODE_LOW_LATENCY
            }
            builder.setScanMode(scanMode)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            options.callbackType?.let { type ->
                val callbackType = when (type) {
                    AndroidScanCallbackType.DEFAULT_ -> ScanSettings.CALLBACK_TYPE_DEFAULT
                    AndroidScanCallbackType.FIRST_MATCH -> ScanSettings.CALLBACK_TYPE_FIRST_MATCH
                    AndroidScanCallbackType.LOSE -> ScanSettings.CALLBACK_TYPE_MATCH_LOST
                    AndroidScanCallbackType.MATCHED -> ScanSettings.CALLBACK_TYPE_MATCHED
                }
                builder.setCallbackType(callbackType)
            }

            options.matchMode?.let { mode ->
                val matchMode = when (mode) {
                    AndroidScanMatchMode.DEFAULT_ -> ScanSettings.MATCH_MODE_AGGRESSIVE
                    AndroidScanMatchMode.STICKY -> ScanSettings.MATCH_MODE_STICKY
                }
                builder.setMatchMode(matchMode)
            }

            options.numOfMatches?.let { num ->
                val numOfMatches = when (num) {
                    AndroidScanNumOfMatches.ONE -> ScanSettings.MATCH_NUM_ONE_ADVERTISEMENT
                    AndroidScanNumOfMatches.FEW -> ScanSettings.MATCH_NUM_FEW_ADVERTISEMENT
                    AndroidScanNumOfMatches.MANY -> ScanSettings.MATCH_NUM_MANY_ADVERTISEMENTS
                }
                builder.setNumOfMatches(numOfMatches)
            }
        }

        return builder.build()
    }

    private fun buildScanFilters(filters: List<UniversalScanFilter>): List<android.bluetooth.le.ScanFilter> {
        return filters.toScanFilters()
    }

    @SuppressLint("MissingPermission")
    private fun stopScanInternal() {
        if (!isScanning) return
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
        pendingScanFilters = null
    }

    override fun stopScan(callback: (Result<Unit>) -> Unit) {
        stopScanInternal()
        callback(Result.success(Unit))
    }

    override fun isScanning(callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(isScanning))
    }

    @SuppressLint("MissingPermission")
    override fun connect(
        peripheralId: String,
        config: ConnectionPlatformConfig,
        callback: (Result<Unit>) -> Unit
    ) {
        val ctx = context
        if (ctx == null) {
            callback(Result.failure(FlutterError("no_context", "Context unavailable", null)))
            return
        }
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.failure(FlutterError("no_adapter", "Bluetooth adapter unavailable", null)))
            return
        }

        val device = try {
            adapter.getRemoteDevice(peripheralId)
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Invalid device address: $peripheralId")
            callback(Result.failure(FlutterError("invalid_device", "Invalid device address: $peripheralId", null)))
            return
        }

        try {
            val gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(ctx, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
            } else {
                device.connectGatt(ctx, false, gattCallback)
            }
            if (gatt != null) {
                gattServers[peripheralId] = gatt
                PrinterConnectLogger.logInfo("Connecting to $peripheralId")
                callback(Result.success(Unit))
            } else {
                PrinterConnectLogger.logError("Failed to create GATT connection to $peripheralId")
                callback(Result.failure(FlutterError("connect_failed", "Failed to create GATT connection", null)))
            }
        } catch (e: SecurityException) {
            PrinterConnectLogger.logError("SecurityException connecting to $peripheralId: ${e.message}")
            callback(Result.failure(FlutterError("security_error", e.message ?: "Security exception", null)))
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error connecting to $peripheralId: ${e.message}")
            callback(Result.failure(FlutterError("connect_error", e.message ?: "Unknown error", null)))
        }
    }

    @SuppressLint("MissingPermission")
    override fun disconnect(peripheralId: String, callback: (Result<Unit>) -> Unit) {
        val gatt = gattServers[peripheralId]
        if (gatt != null) {
            try {
                gatt.disconnect()
                PrinterConnectLogger.logInfo("Disconnecting from $peripheralId")
            } catch (e: Exception) {
                PrinterConnectLogger.logError("Error disconnecting from $peripheralId: ${e.message}")
            }
        } else {
            PrinterConnectLogger.logWarning("No GATT connection found for $peripheralId")
        }
        callback(Result.success(Unit))
    }

    @SuppressLint("MissingPermission")
    override fun discoverServices(
        peripheralId: String,
        callback: (Result<List<UniversalBleService>>) -> Unit
    ) {
        val gatt = gattServers[peripheralId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $peripheralId", "")))
            return
        }

        try {
            val success = gatt.discoverServices()
            if (!success) {
                callback(Result.failure(FlutterError("discover_failed", "Failed to discover services", "")))
                return
            }

            handler.postDelayed({
                val services = gatt.services.map { service ->
                    UniversalBleService(
                        uuid = service.uuid.toString(),
                        isPrimary = service.isPrimary
                    )
                }
                callback(Result.success(services))
            }, 500)
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("discover_error", e.message ?: "Unknown error", "")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun setNotifiable(
        peripheralId: String,
        serviceId: String,
        characteristicId: String,
        value: BleInputProperty,
        callback: (Result<Unit>) -> Unit
    ) {
        val gatt = gattServers[peripheralId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $peripheralId", "")))
            return
        }

        val characteristic = gatt.getCharacteristic(serviceId, characteristicId)
        if (characteristic == null) {
            callback(Result.failure(FlutterError("no_characteristic", "Characteristic not found: $characteristicId", "")))
            return
        }

        try {
            val enable = when (value) {
                BleInputProperty.NOTIFICATION -> true
                BleInputProperty.INDICATION -> true
                BleInputProperty.DISABLED -> false
            }

            val success = gatt.setCharacteristicNotification(characteristic, enable)
            if (success && enable) {
                val descriptor = characteristic.getDescriptor(ccdCharacteristic)
                if (descriptor != null) {
                    val ccdValue = if (value == BleInputProperty.INDICATION) {
                        BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                    } else {
                        BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    }
                    descriptor.value = ccdValue
                    gatt.writeDescriptor(descriptor)
                }
            }
            PrinterConnectLogger.logDebug("Set notifiable for $characteristicId: enable=$enable")
            callback(Result.success(Unit))
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error setting notifiable: ${e.message}")
            callback(Result.failure(FlutterError("set_notifiable_error", e.message ?: "Unknown error", "")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun readValue(
        peripheralId: String,
        serviceId: String,
        characteristicId: String,
        callback: (Result<UniversalBleCharacteristic>) -> Unit
    ) {
        val gatt = gattServers[peripheralId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $peripheralId", "")))
            return
        }

        val characteristic = gatt.getCharacteristic(serviceId, characteristicId)
        if (characteristic == null) {
            callback(Result.failure(FlutterError("no_characteristic", "Characteristic not found: $characteristicId", "")))
            return
        }

        try {
            gatt.readCharacteristic(characteristic)
            handler.postDelayed({
                val valueBytes = characteristic.value
                val valueList = valueBytes?.map { it.toLong() and 0xFFL } ?: emptyList()
                val properties = characteristic.getPropertiesList()
                callback(Result.success(UniversalBleCharacteristic(characteristicId, properties, valueList)))
            }, 500)
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("read_error", e.message ?: "Unknown error", "")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun writeValue(
        peripheralId: String,
        serviceId: String,
        characteristicId: String,
        value: List<Long>,
        bleOutputProperty: BleOutputProperty,
        callback: (Result<Unit>) -> Unit
    ) {
        val gatt = gattServers[peripheralId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $peripheralId", "")))
            return
        }

        val characteristic = gatt.getCharacteristic(serviceId, characteristicId)
        if (characteristic == null) {
            callback(Result.failure(FlutterError("no_characteristic", "Characteristic not found: $characteristicId", "")))
            return
        }

        try {
            val valueBytes = value.map { it.toInt().toByte() }.toByteArray()
            characteristic.value = valueBytes

            val writeType = when (bleOutputProperty) {
                BleOutputProperty.WRITE_WITHOUT_RESPONSE -> BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                BleOutputProperty.WRITE -> BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                BleOutputProperty.NONE -> BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            }

            characteristic.writeType = writeType
            gatt.writeCharacteristic(characteristic)
            PrinterConnectLogger.logDebug("Written ${value.size} bytes to $characteristicId")
            callback(Result.success(Unit))
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error writing value: ${e.message}")
            callback(Result.failure(FlutterError("write_error", e.message ?: "Unknown error", "")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun requestMtu(peripheralId: String, mtu: Long, callback: (Result<Long>) -> Unit) {
        val gatt = gattServers[peripheralId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $peripheralId", "")))
            return
        }

        try {
            val success = gatt.requestMtu(mtu.toInt())
            if (!success) {
                callback(Result.failure(FlutterError("mtu_request_failed", "MTU request failed", "")))
                return
            }

            handler.postDelayed({
                callback(Result.success(mtu))
            }, 500)
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("mtu_error", e.message ?: "Unknown error", "")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun readRssi(peripheralId: String, callback: (Result<Long>) -> Unit) {
        val gatt = gattServers[peripheralId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $peripheralId", "")))
            return
        }

        try {
            gatt.readRemoteRssi()
            handler.postDelayed({
                val rssi = gatt.device.rssi
                callback(Result.success(rssi.toLong()))
            }, 500)
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("rssi_error", e.message ?: "Unknown error", "")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun requestConnectionPriority(
        peripheralId: String,
        priority: BleConnectionPriority,
        callback: (Result<Unit>) -> Unit
    ) {
        val gatt = gattServers[peripheralId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $peripheralId", "")))
            return
        }

        try {
            val connectionPriority = when (priority) {
                BleConnectionPriority.BALANCED -> BluetoothGatt.CONNECTION_PRIORITY_BALANCED
                BleConnectionPriority.HIGH_PERFORMANCE -> BluetoothGatt.CONNECTION_PRIORITY_HIGH
                BleConnectionPriority.LOW_POWER -> BluetoothGatt.CONNECTION_PRIORITY_LOW_POWER
            }
            gatt.requestConnectionPriority(connectionPriority)
            PrinterConnectLogger.logDebug("Requested connection priority for $peripheralId: $priority")
            callback(Result.success(Unit))
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error requesting connection priority: ${e.message}")
            callback(Result.failure(FlutterError("priority_error", e.message ?: "Unknown error", "")))
        }
    }

    override fun isPaired(peripheralId: String, callback: (Result<Boolean>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.success(false))
            return
        }
        return try {
            val device = adapter.getRemoteDevice(peripheralId)
            callback(Result.success(device.isBonded()))
        } catch (e: Exception) {
            callback(Result.success(false))
        }
    }

    @SuppressLint("MissingPermission")
    override fun pair(peripheralId: String, callback: (Result<Unit>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.failure(FlutterError("no_adapter", "Bluetooth adapter unavailable", null)))
            return
        }

        try {
            val device = adapter.getRemoteDevice(peripheralId)
            if (device.isBonded()) {
                callback(Result.success(Unit))
                return
            }

            device.createBond()
            PrinterConnectLogger.logInfo("Pairing with $peripheralId")
            callback(Result.success(Unit))
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error pairing: ${e.message}")
            callback(Result.failure(FlutterError("pair_error", e.message ?: "Unknown error", null)))
        }
    }

    @SuppressLint("MissingPermission")
    override fun unPair(peripheralId: String, callback: (Result<Unit>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.failure(FlutterError("no_adapter", "Bluetooth adapter unavailable", null)))
            return
        }

        try {
            val device = adapter.getRemoteDevice(peripheralId)
            if (!device.isBonded()) {
                callback(Result.success(Unit))
                return
            }

            device.removeBond()
            PrinterConnectLogger.logInfo("Unpairing from $peripheralId")
            callback(Result.success(Unit))
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error unpairing: ${e.message}")
            callback(Result.failure(FlutterError("unpair_error", e.message ?: "Unknown error", null)))
        }
    }

    @SuppressLint("MissingPermission")
    override fun getSystemDevices(callback: (Result<List<UniversalBleScanResult>>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.success(emptyList()))
            return
        }

        val devices = adapter.bondedDevices
        val results = devices.map { device ->
            UniversalBleScanResult(
                peripheralId = device.address,
                name = device.name,
                rssi = 0L,
                manufacturerData = null,
                serviceData = null,
                serviceUuids = null,
                txPowerLevel = null
            )
        }
        callback(Result.success(results))
    }

    override fun getConnectionState(peripheralId: String, callback: (Result<BleConnectionState>) -> Unit) {
        val gatt = gattServers[peripheralId]
        if (gatt == null) {
            callback(Result.success(BleConnectionState.DISCONNECTED))
            return
        }
        return try {
            val state = gatt.device.getProfileConnectionState(BluetoothProfile.GATT)
            callback(Result.success(state.toBleConnectionState()))
        } catch (e: Exception) {
            callback(Result.success(BleConnectionState.DISCONNECTED))
        }
    }

    override fun setLogLevel(level: BleLogLevel, callback: (Result<Unit>) -> Unit) {
        PrinterConnectLogger.setLogLevel(level)
        callback(Result.success(Unit))
    }

    companion object {
        private const val PERMISSION_REQUEST_CODE = 1001
        private const val ENABLE_BLUETOOTH_REQUEST_CODE = 1002
    }
}

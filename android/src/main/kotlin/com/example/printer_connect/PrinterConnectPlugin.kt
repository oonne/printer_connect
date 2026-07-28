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
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.RequiresApi
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
    private var pendingScanFilter: UniversalScanFilter? = null
    private var pendingScanConfig: UniversalScanConfig? = null

    private val gattServers = ConcurrentHashMap<String, BluetoothGatt>()
    private val scanResults = mutableMapOf<String, UniversalBleScanResult>()
    private val cachedServices = ConcurrentHashMap<String, List<UniversalBleService>>()
    private val connectingDevices = ConcurrentHashMap.newKeySet<String>()

    private val readFutures = ConcurrentHashMap<String, (Result<ByteArray>) -> Unit>()
    private val writeFutures = ConcurrentHashMap<String, (Result<Unit>) -> Unit>()
    private val discoverFutures = ConcurrentHashMap<String, MutableList<(Result<List<UniversalBleService>>) -> Unit>>()
    private val rssiFutures = ConcurrentHashMap<String, (Result<Long>) -> Unit>()
    private val mtuFutures = ConcurrentHashMap<String, (Result<Long>) -> Unit>()
    private val descriptorWriteFutures = ConcurrentHashMap<String, (Result<Unit>) -> Unit>()
    private val descriptorReadFutures = ConcurrentHashMap<String, (Result<ByteArray>) -> Unit>()

    private val handler = Handler(Looper.getMainLooper())

    private var permissionLauncher: ActivityResultLauncher<Array<String>>? = null
    private var pendingPermissionResult: ((Boolean) -> Unit)? = null

    private var enableBluetoothLauncher: ActivityResultLauncher<Intent>? = null
    private var pendingEnableResult: ((Boolean) -> Unit)? = null

    private val pendingPairResults = ConcurrentHashMap<String, (Result<Boolean>) -> Unit>()
    private val bondingDevices = ConcurrentHashMap.newKeySet<String>()

    private val bondStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val bondStateChange = intent?.getBondStateChange() ?: return
            val deviceAddress = bondStateChange.deviceAddress
            val bondState = bondStateChange.bondState
            val isPaired = bondState == BluetoothDevice.BOND_BONDED
            sendPairStateChange(deviceAddress, isPaired, null)
            PrinterConnectLogger.logDebug("Bond state changed for $deviceAddress: bondState=$bondState, bonded=$isPaired")

            val pendingCallback = pendingPairResults[deviceAddress]
            if (pendingCallback != null) {
                when {
                    isPaired -> {
                        bondingDevices.remove(deviceAddress)
                        handler.post { pendingCallback.invoke(Result.success(true)) }
                    }
                    bondState == BluetoothDevice.BOND_NONE -> {
                        bondingDevices.remove(deviceAddress)
                        handler.post { pendingCallback.invoke(Result.failure(FlutterError("pair_failed", "Pairing failed for $deviceAddress", null))) }
                    }
                    bondState == BluetoothDevice.BOND_BONDING -> {
                        bondingDevices.add(deviceAddress)
                    }
                }
            }
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
                cachedServices.remove(deviceAddress)
                connectingDevices.remove(deviceAddress)
                clearFuturesForDevice(deviceAddress)
                sendConnectionChanged(deviceAddress, false, "Connection failed with status: $status")
                return
            }

            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    gattServers[deviceAddress] = gatt
                    connectingDevices.remove(deviceAddress)
                    PrinterConnectLogger.logInfo("Connected to $deviceAddress")
                    sendConnectionChanged(deviceAddress, true, null)
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    gatt.close()
                    gattServers.remove(deviceAddress)
                    cachedServices.remove(deviceAddress)
                    connectingDevices.remove(deviceAddress)
                    clearFuturesForDevice(deviceAddress)
                    PrinterConnectLogger.logInfo("Disconnected from $deviceAddress")
                    sendConnectionChanged(deviceAddress, false, null)
                }
                BluetoothProfile.STATE_CONNECTING -> {
                    connectingDevices.add(deviceAddress)
                    sendConnectionChanged(deviceAddress, false, null)
                }
                BluetoothProfile.STATE_DISCONNECTING -> {
                    sendConnectionChanged(deviceAddress, false, null)
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
                    FlutterError("discover_failed", "Service discovery failed with status: $status", "")
                )
                for (callback in pendingList) {
                    callback.invoke(error)
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
                callback.invoke(Result.success(services))
            }
        }

        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            val deviceAddress = gatt.device.address
            val serviceUuid = characteristic.service.uuid.toString()
            val charUuid = characteristic.uuid.toString()
            PrinterConnectLogger.logDebug("Characteristic read for $deviceAddress/$serviceUuid/$charUuid, status=$status")

            val key = "$deviceAddress/$serviceUuid/$charUuid"
            val future = readFutures.remove(key)
            if (future != null) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    val valueBytes = characteristic.value ?: ByteArray(0)
                    future.invoke(Result.success(valueBytes))
                } else {
                    future.invoke(Result.failure(FlutterError("read_failed", "Read failed with status: $status", "")))
                }
            }
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            val deviceAddress = gatt.device.address
            val serviceUuid = characteristic.service.uuid.toString()
            val charUuid = characteristic.uuid.toString()
            PrinterConnectLogger.logDebug("Characteristic write for $deviceAddress/$serviceUuid/$charUuid, status=$status")

            val key = "$deviceAddress/$serviceUuid/$charUuid"
            val future = writeFutures.remove(key)
            if (future != null) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    future.invoke(Result.success(Unit))
                } else {
                    future.invoke(Result.failure(FlutterError("write_failed", "Write failed with status: $status", "")))
                }
            }
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            val deviceAddress = gatt.device.address
            val charUuid = characteristic.uuid.toString()
            val valueBytes = characteristic.value ?: ByteArray(0)
            val timestamp = System.currentTimeMillis()
            PrinterConnectLogger.logDebug("Characteristic changed for $deviceAddress/$charUuid")
            sendValueChanged(deviceAddress, charUuid, valueBytes, timestamp)
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
                    future.invoke(Result.success(valueBytes))
                } else {
                    future.invoke(Result.failure(FlutterError("descriptor_read_failed", "Descriptor read failed with status: $status", "")))
                }
            }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            val deviceAddress = gatt.device.address
            val descUuid = descriptor.uuid.toString()
            PrinterConnectLogger.logDebug("Descriptor write for $deviceAddress/$descUuid, status=$status")

            val key = "$deviceAddress/$descUuid"
            val future = descriptorWriteFutures.remove(key)
            if (future != null) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    future.invoke(Result.success(Unit))
                } else {
                    future.invoke(Result.failure(FlutterError("descriptor_write_failed", "Descriptor write failed with status: $status", "")))
                }
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            val deviceAddress = gatt.device.address
            PrinterConnectLogger.logDebug("MTU changed for $deviceAddress: mtu=$mtu, status=$status")

            val future = mtuFutures.remove(deviceAddress)
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val updated = BleConnectionParametersUpdated(
                    deviceId = deviceAddress,
                    interval = 0L,
                    latency = 0L,
                    supervisionTimeout = 0L,
                    status = status.toLong()
                )
                sendConnectionParametersUpdated(updated)
                future?.invoke(Result.success(mtu.toLong()))
            } else {
                future?.invoke(Result.failure(FlutterError("mtu_failed", "MTU change failed with status: $status", "")))
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
            handler.post {
                sendConnectionParametersUpdated(updated)
            }
        }

        override fun onReadRemoteRssi(gatt: BluetoothGatt, rssi: Int, status: Int) {
            val deviceAddress = gatt.device.address
            PrinterConnectLogger.logDebug("RSSI read for $deviceAddress: rssi=$rssi, status=$status")

            val future = rssiFutures.remove(deviceAddress)
            if (future != null) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    future.invoke(Result.success(rssi.toLong()))
                } else {
                    future.invoke(Result.failure(FlutterError("rssi_failed", "RSSI read failed with status: $status", "")))
                }
            }
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
        stopScan()
        closeAllGattConnections()
        UniversalBlePlatformChannel.setUp(binaryMessenger, null)
        callbackChannel = null
        PrinterConnectLogger.logInfo("PrinterConnectPlugin detached from engine")
    }

    private fun sendAvailabilityChanged(state: AvailabilityState) {
        callbackChannel?.onAvailabilityChanged(state) { _ -> }
    }

    private fun sendPairStateChange(deviceId: String, isPaired: Boolean, error: String?) {
        callbackChannel?.onPairStateChange(deviceId, isPaired, error) { _ -> }
    }

    private fun sendScanResult(result: UniversalBleScanResult) {
        callbackChannel?.onScanResult(result) { _ -> }
    }

    private fun sendValueChanged(deviceId: String, characteristicId: String, value: ByteArray, timestamp: Long?) {
        callbackChannel?.onValueChanged(deviceId, characteristicId, value, timestamp) { _ -> }
    }

    private fun sendConnectionChanged(deviceId: String, connected: Boolean, error: String?) {
        callbackChannel?.onConnectionChanged(deviceId, connected, error) { _ -> }
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
        val componentActivity = binding.activity as? ComponentActivity
        if (componentActivity == null) {
            PrinterConnectLogger.logError("Cannot register permission launcher: activity is not a ComponentActivity")
            return
        }
        permissionLauncher = componentActivity.registerForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions()
        ) { grants: Map<String, Boolean> ->
            val allGranted = grants.values.all { it }
            pendingPermissionResult?.invoke(allGranted)
            pendingPermissionResult = null
            PrinterConnectLogger.logDebug("Permission result: $allGranted")
        }
    }

    private fun setupEnableBluetoothLauncher(binding: ActivityPluginBinding) {
        val componentActivity = binding.activity as? ComponentActivity
        if (componentActivity == null) {
            PrinterConnectLogger.logError("Cannot register enable bluetooth launcher: activity is not a ComponentActivity")
            return
        }
        enableBluetoothLauncher = componentActivity.registerForActivityResult(
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
    }

    private fun clearAllFutures() {
        readFutures.clear()
        writeFutures.clear()
        discoverFutures.clear()
        rssiFutures.clear()
        mtuFutures.clear()
        descriptorWriteFutures.clear()
        descriptorReadFutures.clear()
    }

    @SuppressLint("MissingPermission")
    private fun cleanConnection(gatt: BluetoothGatt) {
        val deviceAddress = gatt.device.address
        try {
            gatt.close()
        } catch (_: Exception) {}
        gattServers.remove(deviceAddress)
        cachedServices.remove(deviceAddress)
        connectingDevices.remove(deviceAddress)
        clearFuturesForDevice(deviceAddress)
    }

    private fun cleanUpConnection(deviceId: String) {
        gattServers.remove(deviceId)
        cachedServices.remove(deviceId)
        connectingDevices.remove(deviceId)
        clearFuturesForDevice(deviceId)
    }

    override fun getBluetoothAvailabilityState(callback: (Result<AvailabilityState>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.success(AvailabilityState.UNSUPPORTED))
            return
        }
        callback(Result.success(adapter.state.toAvailabilityState()))
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
            callback(Result.failure(FlutterError("no_activity", "Activity is required for permissions", null)))
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
                    callback(Result.failure(FlutterError("permission_denied", "Permissions denied", null)))
                }
            }
        }
        permissionLauncher?.launch(permissions.toTypedArray())
            ?: callback(Result.failure(FlutterError("launch_failed", "Cannot launch permission request", null)))
    }

    override fun enableBluetooth(callback: (Result<Boolean>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.failure(FlutterError("bluetooth_unavailable", "Bluetooth adapter not available", null)))
            return
        }
        if (adapter.isEnabled) {
            callback(Result.success(true))
            return
        }

        val act = activityBinding?.activity
        if (act == null) {
            callback(Result.failure(FlutterError("no_activity", "Activity is required to enable Bluetooth", null)))
            return
        }

        pendingEnableResult = { success ->
            handler.post { callback(Result.success(success)) }
        }
        val enableIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
        enableBluetoothLauncher?.launch(enableIntent)
            ?: callback(Result.failure(FlutterError("launch_failed", "Cannot launch Bluetooth enable intent", null)))
    }

    override fun disableBluetooth(callback: (Result<Boolean>) -> Unit) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            callback(Result.failure(FlutterError("bluetooth_unavailable", "Bluetooth adapter not available", null)))
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
                callback(Result.failure(FlutterError("disable_failed", "Failed to disable Bluetooth", null)))
            }
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Failed to disable Bluetooth: ${e.message}")
            callback(Result.failure(FlutterError("disable_error", e.message ?: "Unknown error", null)))
        }
    }

    @SuppressLint("MissingPermission")
    override fun startScan(filter: UniversalScanFilter?, config: UniversalScanConfig?) {
        val ctx = context
        val adapter = bluetoothAdapter
        if (ctx == null || adapter == null) {
            handler.post {
                PrinterConnectLogger.logError("Context or Bluetooth adapter unavailable")
            }
            return
        }

        if (!adapter.isEnabled) {
            PrinterConnectLogger.logWarning("Bluetooth is not enabled, cannot start scan")
            return
        }

        if (!SafeScanner.getInstance().canStartScan()) {
            val waitTime = SafeScanner.getInstance().getTimeUntilNextScanMs()
            PrinterConnectLogger.logWarning("Scan frequency limit reached. Waiting ${waitTime}ms")
            handler.postDelayed({
                startScan(filter, config)
            }, waitTime)
            return
        }

        SafeScanner.getInstance().recordScanStart()
        pendingScanFilter = filter
        pendingScanConfig = config

        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            PrinterConnectLogger.logError("Cannot get BluetoothLeScanner")
            pendingScanFilter = null
            pendingScanConfig = null
            return
        }

        val androidOptions = config?.android
        val scanSettings = buildScanSettings(androidOptions)
        val scanFilters = buildScanFilters(listOfNotNull(filter))

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
        } catch (e: SecurityException) {
            PrinterConnectLogger.logError("SecurityException starting scan: ${e.message}")
            isScanning = false
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error starting scan: ${e.message}")
            isScanning = false
        }
    }

    @SuppressLint("MissingPermission")
    private fun handleScanResult(result: ScanResult) {
        val filter = pendingScanFilter
        if (!PrinterConnectFilterUtil.filterDevice(result, filter)) {
            return
        }

        val device = result.device
        val address = device.address
        val name = device.name
        val isPaired = try {
            device.isBonded()
        } catch (_: Exception) {
            false
        }
        val timestamp = System.currentTimeMillis()

        val scanResult = UniversalBleScanResult(
            deviceId = address,
            name = name,
            isPaired = isPaired,
            rssi = result.rssi.toLong(),
            manufacturerDataList = result.manufacturerDataList(),
            serviceData = result.serviceData(),
            services = result.serviceUuids(),
            timestamp = timestamp
        )

        scanResults[address] = scanResult
        sendScanResult(scanResult)
        PrinterConnectLogger.logVerbose("Scan result: $address, rssi=${result.rssi}")
    }

    private fun buildScanSettings(options: AndroidOptions?): ScanSettings {
        val builder = ScanSettings.Builder()

        options?.scanMode?.let { mode ->
            val scanMode = when (mode) {
                AndroidScanMode.LOW_POWER -> ScanSettings.SCAN_MODE_LOW_POWER
                AndroidScanMode.BALANCED -> ScanSettings.SCAN_MODE_BALANCED
                AndroidScanMode.LOW_LATENCY -> ScanSettings.SCAN_MODE_LOW_LATENCY
                AndroidScanMode.OPPORTUNISTIC -> ScanSettings.SCAN_MODE_OPPORTUNISTIC
            }
            builder.setScanMode(scanMode)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            options?.reportDelayMillis?.let { delay ->
                builder.setReportDelay(delay)
            }
            val legacy = options?.legacy
            if (legacy != null) {
                if (legacy) {
                    builder.setLegacy(true)
                } else {
                    builder.setPhy(android.bluetooth.le.ScanSettings.PHY_LE_ALL_SUPPORTED)
                    builder.setLegacy(false)
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            options?.callbackType?.let { types ->
                var combinedType = 0
                for (type in types) {
                    combinedType = combinedType or when (type) {
                        AndroidScanCallbackType.ALL_MATCHES -> ScanSettings.CALLBACK_TYPE_ALL_MATCHES
                        AndroidScanCallbackType.FIRST_MATCH -> ScanSettings.CALLBACK_TYPE_FIRST_MATCH
                        AndroidScanCallbackType.MATCH_LOST -> ScanSettings.CALLBACK_TYPE_MATCH_LOST
                        AndroidScanCallbackType.ALL_MATCHES_AUTO_BATCH -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                ScanSettings.CALLBACK_TYPE_ALL_MATCHES_AUTO_BATCH
                            } else {
                                ScanSettings.CALLBACK_TYPE_ALL_MATCHES
                            }
                        }
                    }
                }
                builder.setCallbackType(combinedType)
            }

            options?.matchMode?.let { mode ->
                val matchMode = when (mode) {
                    AndroidScanMatchMode.AGGRESSIVE -> ScanSettings.MATCH_MODE_AGGRESSIVE
                    AndroidScanMatchMode.STICKY -> ScanSettings.MATCH_MODE_STICKY
                }
                builder.setMatchMode(matchMode)
            }

            options?.numOfMatches?.let { num ->
                val numOfMatches = when (num) {
                    AndroidScanNumOfMatches.ONE -> 1
                    AndroidScanNumOfMatches.FEW -> 2
                    AndroidScanNumOfMatches.MAX -> 3
                }
                builder.setNumOfMatches(numOfMatches)
            }
        }

        return builder.build()
    }

    private fun buildScanFilters(filters: List<UniversalScanFilter>): List<android.bluetooth.le.ScanFilter> {
        return PrinterConnectFilterUtil.run { filters.toScanFilters() }
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
        pendingScanFilter = null
        pendingScanConfig = null
    }

    override fun stopScan() {
        stopScanInternal()
    }

    override fun isScanning(): Boolean {
        return isScanning
    }

    @SuppressLint("MissingPermission")
    override fun connect(
        deviceId: String,
        autoConnect: Boolean?,
        platformConfig: ConnectionPlatformConfig?
    ) {
        val ctx = context
        if (ctx == null) {
            PrinterConnectLogger.logError("Context unavailable")
            sendConnectionChanged(deviceId, false, "Context unavailable")
            return
        }
        val adapter = bluetoothAdapter
        if (adapter == null) {
            PrinterConnectLogger.logError("Bluetooth adapter unavailable")
            sendConnectionChanged(deviceId, false, "Bluetooth adapter unavailable")
            return
        }

        if (connectingDevices.contains(deviceId)) {
            PrinterConnectLogger.logDebug("Already connecting to $deviceId")
            handler.post {
                sendConnectionChanged(deviceId, false, null)
            }
            return
        }

        val existingGatt = gattServers[deviceId]
        if (existingGatt != null) {
            val state = try {
                bluetoothManager?.getConnectionState(existingGatt.device, BluetoothProfile.GATT)
                    ?: BluetoothProfile.STATE_DISCONNECTED
            } catch (_: Exception) {
                BluetoothProfile.STATE_DISCONNECTED
            }
            if (state == BluetoothProfile.STATE_CONNECTED || state == BluetoothProfile.STATE_CONNECTING) {
                PrinterConnectLogger.logDebug("Already connected/connecting to $deviceId")
                handler.post {
                    sendConnectionChanged(deviceId, state == BluetoothProfile.STATE_CONNECTED, null)
                }
                return
            }
        }

        val device = try {
            adapter.getRemoteDevice(deviceId)
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Invalid device address: $deviceId")
            sendConnectionChanged(deviceId, false, "Invalid device address: $deviceId")
            return
        }

        try {
            val connectAuto = autoConnect ?: false
            val gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(ctx, connectAuto, gattCallback, BluetoothDevice.TRANSPORT_LE)
            } else {
                device.connectGatt(ctx, connectAuto, gattCallback)
            }
            if (gatt != null) {
                gattServers[deviceId] = gatt
                connectingDevices.add(deviceId)
                PrinterConnectLogger.logInfo("Connecting to $deviceId (autoConnect=$connectAuto)")
            } else {
                PrinterConnectLogger.logError("Failed to create GATT connection to $deviceId")
                sendConnectionChanged(deviceId, false, "Failed to create GATT connection")
            }
        } catch (e: SecurityException) {
            PrinterConnectLogger.logError("SecurityException connecting to $deviceId: ${e.message}")
            sendConnectionChanged(deviceId, false, e.message ?: "Security exception")
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error connecting to $deviceId: ${e.message}")
            sendConnectionChanged(deviceId, false, e.message ?: "Unknown error")
        }
    }

    @SuppressLint("MissingPermission")
    override fun disconnect(deviceId: String) {
        connectingDevices.remove(deviceId)
        val gatt = gattServers[deviceId]
        if (gatt != null) {
            try {
                gatt.disconnect()
                PrinterConnectLogger.logInfo("Disconnecting from $deviceId")
            } catch (e: Exception) {
                PrinterConnectLogger.logError("Error disconnecting from $deviceId: ${e.message}")
            }
        } else {
            PrinterConnectLogger.logWarning("No GATT connection found for $deviceId")
            cleanUpConnection(deviceId)
            handler.post {
                sendConnectionChanged(deviceId, false, null)
            }
        }
    }

    @SuppressLint("MissingPermission")
    override fun discoverServices(
        deviceId: String,
        withDescriptors: Boolean,
        callback: (Result<List<UniversalBleService>>) -> Unit
    ) {
        val gatt = gattServers[deviceId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $deviceId", "")))
            return
        }

        cachedServices[deviceId]?.let { services ->
            callback(Result.success(services))
            return
        }

        try {
            val pendingList = discoverFutures.getOrPut(deviceId) { mutableListOf() }
            pendingList.add(callback)

            if (pendingList.size == 1) {
                val success = gatt.discoverServices()
                if (!success) {
                    discoverFutures.remove(deviceId)
                    callback(Result.failure(FlutterError("discover_failed", "Failed to discover services", "")))
                    return
                }
            }
        } catch (e: Exception) {
            discoverFutures.remove(deviceId)
            callback(Result.failure(FlutterError("discover_error", e.message ?: "Unknown error", "")))
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
        val gatt = gattServers[deviceId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $deviceId", "")))
            return
        }

        val gattCharacteristic = gatt.getCharacteristic(service, characteristic)
        if (gattCharacteristic == null) {
            callback(Result.failure(FlutterError("no_characteristic", "Characteristic not found: $characteristic", "")))
            return
        }

        try {
            val enable = when (bleInputProperty) {
                BleInputProperty.NOTIFICATION -> true
                BleInputProperty.INDICATION -> true
                BleInputProperty.DISABLED -> false
            }

            val success = gatt.setCharacteristicNotification(gattCharacteristic, enable)
            if (!enable) {
                if (success) {
                    callback(Result.success(Unit))
                } else {
                    callback(Result.failure(FlutterError("set_notifiable_failed", "Failed to set notification", "")))
                }
                return
            }

            if (success) {
                val descriptor = gattCharacteristic.getDescriptor(ccdCharacteristic)
                if (descriptor != null) {
                    val ccdValue = if (bleInputProperty == BleInputProperty.INDICATION) {
                        BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                    } else {
                        BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    }
                    descriptor.value = ccdValue
                    val descKey = "$deviceId/${descriptor.uuid}"
                    descriptorWriteFutures[descKey] = callback
                    gatt.writeDescriptor(descriptor)
                } else {
                    callback(Result.success(Unit))
                }
            } else {
                callback(Result.failure(FlutterError("set_notifiable_failed", "Failed to set notification", "")))
            }
            PrinterConnectLogger.logDebug("Set notifiable for $characteristic: enable=$enable")
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error setting notifiable: ${e.message}")
            callback(Result.failure(FlutterError("set_notifiable_error", e.message ?: "Unknown error", "")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun readValue(
        deviceId: String,
        service: String,
        characteristic: String,
        callback: (Result<ByteArray>) -> Unit
    ) {
        val gatt = gattServers[deviceId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $deviceId", "")))
            return
        }

        val gattCharacteristic = gatt.getCharacteristic(service, characteristic)
        if (gattCharacteristic == null) {
            callback(Result.failure(FlutterError("no_characteristic", "Characteristic not found: $characteristic", "")))
            return
        }

        try {
            val key = "$deviceId/$service/$characteristic"
            readFutures[key] = callback
            gatt.readCharacteristic(gattCharacteristic)
        } catch (e: Exception) {
            callback(Result.failure(FlutterError("read_error", e.message ?: "Unknown error", "")))
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
        val gatt = gattServers[deviceId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $deviceId", "")))
            return
        }

        val gattCharacteristic = gatt.getCharacteristic(service, characteristic)
        if (gattCharacteristic == null) {
            callback(Result.failure(FlutterError("no_characteristic", "Characteristic not found: $characteristic", "")))
            return
        }

        try {
            gattCharacteristic.value = value

            val writeType = when (bleOutputProperty) {
                BleOutputProperty.WITH_RESPONSE -> BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                BleOutputProperty.WITHOUT_RESPONSE -> BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            }

            gattCharacteristic.writeType = writeType
            val key = "$deviceId/$service/$characteristic"

            if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) {
                val success = gatt.writeCharacteristic(gattCharacteristic)
                if (success) {
                    callback(Result.success(Unit))
                } else {
                    callback(Result.failure(FlutterError("write_failed", "Write failed (no response)", "")))
                }
                PrinterConnectLogger.logDebug("Written ${value.size} bytes to $characteristic (no response, success=$success)")
                return
            }

            writeFutures[key] = callback
            val success = gatt.writeCharacteristic(gattCharacteristic)
            if (!success) {
                writeFutures.remove(key)
                callback(Result.failure(FlutterError("write_failed", "Write failed", "")))
                return
            }
            PrinterConnectLogger.logDebug("Written ${value.size} bytes to $characteristic")
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error writing value: ${e.message}")
            callback(Result.failure(FlutterError("write_error", e.message ?: "Unknown error", "")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun requestMtu(deviceId: String, expectedMtu: Long, callback: (Result<Long>) -> Unit) {
        val gatt = gattServers[deviceId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $deviceId", "")))
            return
        }

        try {
            mtuFutures[deviceId] = callback
            val success = gatt.requestMtu(expectedMtu.toInt())
            if (!success) {
                mtuFutures.remove(deviceId)
                callback(Result.failure(FlutterError("mtu_request_failed", "MTU request failed", "")))
                return
            }
        } catch (e: Exception) {
            mtuFutures.remove(deviceId)
            callback(Result.failure(FlutterError("mtu_error", e.message ?: "Unknown error", "")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun readRssi(deviceId: String, callback: (Result<Long>) -> Unit) {
        val gatt = gattServers[deviceId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $deviceId", "")))
            return
        }

        try {
            rssiFutures[deviceId] = callback
            gatt.readRemoteRssi()
        } catch (e: Exception) {
            rssiFutures.remove(deviceId)
            callback(Result.failure(FlutterError("rssi_error", e.message ?: "Unknown error", "")))
        }
    }

    @SuppressLint("MissingPermission")
    override fun requestConnectionPriority(
        deviceId: String,
        priority: BleConnectionPriority,
        callback: (Result<Unit>) -> Unit
    ) {
        val gatt = gattServers[deviceId]
        if (gatt == null) {
            callback(Result.failure(FlutterError("no_connection", "No GATT connection for $deviceId", "")))
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            PrinterConnectLogger.logWarning("requestConnectionPriority requires API 23+")
            callback(Result.failure(FlutterError("not_supported", "requestConnectionPriority requires API 23+", "")))
            return
        }

        try {
            val connectionPriority = when (priority) {
                BleConnectionPriority.BALANCED -> BluetoothGatt.CONNECTION_PRIORITY_BALANCED
                BleConnectionPriority.HIGH_PERFORMANCE -> BluetoothGatt.CONNECTION_PRIORITY_HIGH
                BleConnectionPriority.LOW_POWER -> BluetoothGatt.CONNECTION_PRIORITY_LOW_POWER
            }
            gatt.requestConnectionPriority(connectionPriority)
            PrinterConnectLogger.logDebug("Requested connection priority for $deviceId: $priority")
            callback(Result.success(Unit))
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Error requesting connection priority: ${e.message}")
            callback(Result.failure(FlutterError("priority_error", e.message ?: "Unknown error", "")))
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
            callback(Result.failure(FlutterError("no_adapter", "Bluetooth adapter unavailable", null)))
            return
        }

        try {
            val device = adapter.getRemoteDevice(deviceId)
            if (device.isBonded()) {
                callback(Result.success(true))
                return
            }

            val bondState = device.bondState
            if (bondState == BluetoothDevice.BOND_BONDING) {
                PrinterConnectLogger.logDebug("Already bonding to $deviceId, waiting for state change")
                pendingPairResults[deviceId] = callback
                return
            }

            pendingPairResults[deviceId] = callback
            bondingDevices.add(deviceId)
            device.createBond()
            PrinterConnectLogger.logInfo("Pairing with $deviceId")
        } catch (e: Exception) {
            pendingPairResults.remove(deviceId)
            bondingDevices.remove(deviceId)
            PrinterConnectLogger.logError("Error pairing: ${e.message}")
            callback(Result.failure(FlutterError("pair_error", e.message ?: "Unknown error", null)))
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
            if (!device.isBonded()) {
                return
            }

            device.removeBond()
            PrinterConnectLogger.logInfo("Unpairing from $deviceId")
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

        val context = context
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
            val matchesFilter = withServices.isEmpty() || deviceServices.containsAll(withServices)

            if (!matchesFilter) return@mapNotNull null

            UniversalBleScanResult(
                deviceId = device.address,
                name = device.name,
                isPaired = device.isBonded(),
                rssi = 0L,
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
        val gatt = gattServers[device.address]
        if (gatt != null) {
            return try {
                gatt.services.map { it.uuid.toString() }
            } catch (_: Exception) {
                emptyList()
            }
        }
        return cachedServices[device.address]?.map { it.uuid } ?: emptyList()
    }

    override fun getConnectionState(deviceId: String): BleConnectionState {
        if (connectingDevices.contains(deviceId)) {
            return BleConnectionState.CONNECTING
        }
        val gatt = gattServers[deviceId]
        if (gatt == null) {
            return BleConnectionState.DISCONNECTED
        }
        return try {
            val state = bluetoothManager?.getConnectionState(gatt.device, BluetoothProfile.GATT)
                ?: BluetoothProfile.STATE_DISCONNECTED
            state.toBleConnectionState()
        } catch (e: Exception) {
            BleConnectionState.DISCONNECTED
        }
    }

    override fun setLogLevel(logLevel: BleLogLevel) {
        PrinterConnectLogger.setLogLevel(logLevel)
    }

    companion object {
        private const val PERMISSION_REQUEST_CODE = 1001
        private const val ENABLE_BLUETOOTH_REQUEST_CODE = 1002
    }
}
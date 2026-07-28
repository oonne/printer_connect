package com.example.printer_connect

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

val ccdCharacteristic: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

val knownGatts: ConcurrentHashMap<String, BluetoothGatt> = ConcurrentHashMap()

data class BondStateChange(
    val deviceAddress: String,
    val bondState: Int
)

fun Int.toBleConnectionState(): BleConnectionState {
    return when (this) {
        BluetoothProfile.STATE_DISCONNECTED -> BleConnectionState.DISCONNECTED
        BluetoothProfile.STATE_CONNECTING -> BleConnectionState.CONNECTING
        BluetoothProfile.STATE_CONNECTED -> BleConnectionState.CONNECTED
        BluetoothProfile.STATE_DISCONNECTING -> BleConnectionState.DISCONNECTING
        else -> BleConnectionState.DISCONNECTED
    }
}

fun Int.toAvailabilityState(): AvailabilityState {
    return when (this) {
        BluetoothAdapter.STATE_OFF -> AvailabilityState.POWERED_OFF
        BluetoothAdapter.STATE_ON -> AvailabilityState.POWERED_ON
        BluetoothAdapter.STATE_TURNING_OFF -> AvailabilityState.RESETTING
        BluetoothAdapter.STATE_TURNING_ON -> AvailabilityState.RESETTING
        else -> AvailabilityState.UNKNOWN
    }
}

fun List<String>.toUUIDList(): List<UUID> {
    return this.map { UUID.fromString(it) }
}

fun String.toBluetoothGatt(): BluetoothGatt? {
    return knownGatts[this]
}

fun String.isKnownGatt(): Boolean {
    return knownGatts.containsKey(this)
}

fun String.findGatt(): BluetoothGatt? {
    return knownGatts[this]
}

fun BluetoothManager?.isBluetoothEnabled(): Boolean {
    return this?.adapter?.isEnabled == true
}

fun Intent.getBluetoothDeviceCompat(): BluetoothDevice? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        this.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
    } else {
        @Suppress("DEPRECATION")
        this.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
    }
}

fun Intent.getBondStateChange(): BondStateChange? {
    val device = this.getBluetoothDeviceCompat() ?: return null
    val bondState = this.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.BOND_NONE)
    return BondStateChange(device.address, bondState)
}

fun BluetoothDevice.isBonded(): Boolean {
    return bondState == BluetoothDevice.BOND_BONDED
}

@SuppressLint("MissingPermission")
fun BluetoothDevice.removeBond(): Boolean {
    return try {
        val method = javaClass.methods.find { it.name == "removeBond" }
        if (method != null) {
            method.invoke(this) as? Boolean ?: false
        } else {
            false
        }
    } catch (e: Exception) {
        PrinterConnectLogger.logError("Failed to remove bond: ${e.message}")
        false
    }
}

fun Context.registerReceiverCompat(receiver: android.content.BroadcastReceiver, filter: IntentFilter) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
        @Suppress("DEPRECATION")
        registerReceiver(receiver, filter)
    }
}

@SuppressLint("MissingPermission")
fun BluetoothGatt.saveCacheIfNeeded() {
    knownGatts[this.device.address] = this
}

@SuppressLint("MissingPermission")
fun BluetoothGatt.removeCache() {
    knownGatts.remove(this.device.address)
}

@SuppressLint("MissingPermission")
fun ScanResult.resolvedDeviceName(): String? {
    return try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val method = this.javaClass.getMethod("getDeviceName")
            method.invoke(this) as? String
        } else {
            null
        }
    } catch (_: Exception) {
        null
    }
}

fun ScanResult.manufacturerDataList(): List<UniversalManufacturerData> {
    val list = mutableListOf<UniversalManufacturerData>()
    try {
        val sparseArray = this.scanRecord?.manufacturerSpecificData ?: return emptyList()
        for (i in 0 until sparseArray.size()) {
            val key = sparseArray.keyAt(i)
            val value = sparseArray.valueAt(i)
            if (value != null) {
                list.add(UniversalManufacturerData(key.toLong(), value))
            }
        }
    } catch (e: Exception) {
        PrinterConnectLogger.logWarning("Error reading manufacturer data: ${e.message}")
    }
    return list
}

fun ScanResult.serviceData(): Map<String, ByteArray> {
    val result = mutableMapOf<String, ByteArray>()
    try {
        val serviceDataMap = this.scanRecord?.serviceData ?: return emptyMap()
        for ((uuid, value) in serviceDataMap) {
            result[uuid.toString()] = value
        }
    } catch (e: Exception) {
        PrinterConnectLogger.logWarning("Error reading service data: ${e.message}")
    }
    return result
}

fun ScanResult.serviceUuids(): List<String> {
    val result = mutableListOf<String>()
    try {
        val uuids = this.scanRecord?.serviceUuids ?: return emptyList()
        for (uuid in uuids) {
            result.add(uuid.toString())
        }
    } catch (e: Exception) {
        PrinterConnectLogger.logWarning("Error reading service UUIDs: ${e.message}")
    }
    return result
}

@SuppressLint("MissingPermission")
fun BluetoothGatt.getCharacteristic(serviceUuid: String, characteristicUuid: String): BluetoothGattCharacteristic? {
    val service = getService(UUID.fromString(serviceUuid)) ?: return null
    return service.getCharacteristic(UUID.fromString(characteristicUuid))
}

fun BluetoothGattCharacteristic.getPropertiesList(): List<CharacteristicProperty> {
    val properties = this.properties
    val list = mutableListOf<CharacteristicProperty>()

    if (properties and BluetoothGattCharacteristic.PROPERTY_BROADCAST != 0) {
        list.add(CharacteristicProperty.BROADCAST)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_READ != 0) {
        list.add(CharacteristicProperty.READ)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) {
        list.add(CharacteristicProperty.WRITE_WITHOUT_RESPONSE)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) {
        list.add(CharacteristicProperty.WRITE)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) {
        list.add(CharacteristicProperty.NOTIFY)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0) {
        list.add(CharacteristicProperty.INDICATE)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_SIGNED_WRITE != 0) {
        list.add(CharacteristicProperty.AUTHENTICATED_SIGNED_WRITES)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_EXTENDED_PROPS != 0) {
        list.add(CharacteristicProperty.EXTENDED_PROPERTIES)
    }

    return list
}

fun Short.toByteArray(): ByteArray {
    return byteArrayOf(
        (this.toInt() shr 8).toByte(),
        this.toByte()
    )
}

fun createFlutterError(code: String, message: String? = null, details: Any? = null): FlutterError {
    return FlutterError(code, message, details)
}

fun gattStatusToPrinterConnectErrorCode(status: Int): String {
    return when (status) {
        BluetoothGatt.GATT_SUCCESS -> "success"
        BluetoothGatt.GATT_READ_NOT_PERMITTED -> "read_not_permitted"
        BluetoothGatt.GATT_WRITE_NOT_PERMITTED -> "write_not_permitted"
        BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED -> "request_not_supported"
        BluetoothGatt.GATT_INVALID_OFFSET -> "invalid_offset"
        BluetoothGatt.GATT_INSUFFICIENT_ENCRYPTION -> "insufficient_encryption"
        BluetoothGatt.GATT_INVALID_ATTRIBUTE_LENGTH -> "invalid_attribute_length"
        else -> "gatt_error_$status"
    }
}

fun Int.parseBluetoothStatusCodeError(): String {
    return when (this) {
        BluetoothProfile.STATE_DISCONNECTED -> "Device is disconnected"
        BluetoothProfile.STATE_CONNECTING -> "Device is connecting"
        BluetoothProfile.STATE_CONNECTED -> "Device is connected"
        BluetoothProfile.STATE_DISCONNECTING -> "Device is disconnecting"
        else -> "Unknown Bluetooth state error: $this"
    }
}

fun Int.parseScanErrorMessage(): String {
    return when (this) {
        ScanSettings.SCAN_MODE_LOW_POWER -> "Scan mode: low power"
        ScanSettings.SCAN_MODE_BALANCED -> "Scan mode: balanced"
        ScanSettings.SCAN_MODE_LOW_LATENCY -> "Scan mode: low latency"
        ScanSettings.SCAN_MODE_OPPORTUNISTIC -> "Scan mode: opportunistic"
        else -> "Unknown scan mode error: $this"
    }
}

fun AndroidScanMode.Companion.parse(scanMode: Int): AndroidScanMode {
    return when (scanMode) {
        ScanSettings.SCAN_MODE_LOW_POWER -> AndroidScanMode.LOW_POWER
        ScanSettings.SCAN_MODE_BALANCED -> AndroidScanMode.BALANCED
        ScanSettings.SCAN_MODE_LOW_LATENCY -> AndroidScanMode.LOW_LATENCY
        ScanSettings.SCAN_MODE_OPPORTUNISTIC -> AndroidScanMode.OPPORTUNISTIC
        else -> AndroidScanMode.LOW_POWER
    }
}

fun AndroidScanCallbackType.Companion.parse(callbackType: Int): AndroidScanCallbackType {
    return when (callbackType) {
        ScanSettings.CALLBACK_TYPE_ALL_MATCHES -> AndroidScanCallbackType.ALL_MATCHES
        ScanSettings.CALLBACK_TYPE_FIRST_MATCH -> AndroidScanCallbackType.FIRST_MATCH
        ScanSettings.CALLBACK_TYPE_MATCH_LOST -> AndroidScanCallbackType.MATCH_LOST
        ScanSettings.CALLBACK_TYPE_ALL_MATCHES_AUTO_BATCH -> AndroidScanCallbackType.ALL_MATCHES_AUTO_BATCH
        else -> AndroidScanCallbackType.ALL_MATCHES
    }
}

fun AndroidScanMatchMode.Companion.parse(matchMode: Int): AndroidScanMatchMode {
    return when (matchMode) {
        ScanSettings.MATCH_MODE_AGGRESSIVE -> AndroidScanMatchMode.AGGRESSIVE
        ScanSettings.MATCH_MODE_STICKY -> AndroidScanMatchMode.STICKY
        else -> AndroidScanMatchMode.AGGRESSIVE
    }
}

fun AndroidScanNumOfMatches.Companion.parse(numOfMatches: Int): AndroidScanNumOfMatches {
    return when (numOfMatches) {
        1 -> AndroidScanNumOfMatches.ONE
        2 -> AndroidScanNumOfMatches.FEW
        3 -> AndroidScanNumOfMatches.MAX
        else -> AndroidScanNumOfMatches.ONE
    }
}
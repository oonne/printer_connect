package com.example.printer_connect

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

val ccdCharacteristic: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

private val knownGatts = ConcurrentHashMap<String, BluetoothGatt>()

data class BondStateChange(
    val device: BluetoothDevice,
    val state: Int,
)

fun Int.toBleConnectionState(): BleConnectionState {
    return when (this) {
        BluetoothGatt.STATE_CONNECTED -> BleConnectionState.CONNECTED
        BluetoothGatt.STATE_CONNECTING -> BleConnectionState.CONNECTING
        BluetoothGatt.STATE_DISCONNECTING -> BleConnectionState.DISCONNECTING
        BluetoothGatt.STATE_DISCONNECTED -> BleConnectionState.DISCONNECTED
        else -> BleConnectionState.DISCONNECTED
    }
}

fun List<String>.toUUIDList(): List<UUID> {
    return this.map { UUID.fromString(it) }
}

fun String.toBluetoothGatt(): BluetoothGatt {
    return this.findGatt()
        ?: throw createFlutterError(
            UniversalBleErrorCode.DEVICE_NOT_FOUND,
            "Unknown deviceId: $this",
        )
}

fun String.isKnownGatt(): Boolean {
    return this.findGatt() != null
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
    if (action != BluetoothDevice.ACTION_BOND_STATE_CHANGED) return null
    val device = this.getBluetoothDeviceCompat() ?: return null
    val state = this.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
    return BondStateChange(device, state)
}

fun BluetoothDevice.isBonded(): Boolean = bondState == BluetoothDevice.BOND_BONDED

fun Context.registerReceiverCompat(
    receiver: android.content.BroadcastReceiver,
    filter: IntentFilter,
) {
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

fun Int.toAvailabilityState(): AvailabilityState {
    return when (this) {
        BluetoothAdapter.STATE_OFF -> AvailabilityState.POWERED_OFF
        BluetoothAdapter.STATE_ON -> AvailabilityState.POWERED_ON
        BluetoothAdapter.STATE_TURNING_ON -> AvailabilityState.RESETTING
        BluetoothAdapter.STATE_TURNING_OFF -> AvailabilityState.RESETTING
        else -> AvailabilityState.UNKNOWN
    }
}

val ScanResult.resolvedDeviceName: String?
    get() {
        val advertisedName = scanRecord?.deviceName
        if (!advertisedName.isNullOrBlank()) return advertisedName
        return try {
            device.name
        } catch (_: SecurityException) {
            null
        }
    }

val ScanResult.manufacturerDataList: List<UniversalManufacturerData>
    get() {
        val raw = scanRecord?.bytes
        if (raw != null) {
            val byCompany = LinkedHashMap<Int, java.io.ByteArrayOutputStream>()
            var i = 0
            while (i < raw.size) {
                val fieldLen = raw[i].toInt() and 0xFF
                if (fieldLen == 0) break
                if (i + fieldLen >= raw.size) break
                if ((raw[i + 1].toInt() and 0xFF) == 0xFF && fieldLen >= 3) {
                    val companyId =
                        (raw[i + 2].toInt() and 0xFF) or ((raw[i + 3].toInt() and 0xFF) shl 8)
                    byCompany.getOrPut(companyId) { java.io.ByteArrayOutputStream() }
                        .write(raw, i + 4, fieldLen - 3)
                }
                i += fieldLen + 1
            }
            if (byCompany.isNotEmpty()) {
                return byCompany.map { (companyId, buffer) ->
                    UniversalManufacturerData(companyId.toLong(), buffer.toByteArray())
                }
            }
        }
        return scanRecord?.manufacturerSpecificData?.toList()?.map { (key, value) ->
            UniversalManufacturerData(key.toLong(), value)
        } ?: emptyList()
    }

val ScanResult.serviceData: Map<String, ByteArray>
    get() {
        return scanRecord?.serviceData?.mapKeys { it.key.uuid.toString() } ?: emptyMap()
    }

@SuppressLint("MissingPermission")
fun BluetoothGatt.getCharacteristic(
    service: String,
    characteristic: String,
): BluetoothGattCharacteristic? {
    return getService(UUID.fromString(service))?.getCharacteristic(UUID.fromString(characteristic))
}

@SuppressLint("MissingPermission")
fun BluetoothDevice.removeBond() {
    try {
        javaClass.getMethod("removeBond").invoke(this)
    } catch (e: Exception) {
        PrinterConnectLogger.logError("Removing bond failed. ${e.message}")
    }
}

fun BluetoothGattCharacteristic.getPropertiesList(): ArrayList<CharacteristicProperty> {
    val propertiesList = arrayListOf<CharacteristicProperty>()
    if (properties and BluetoothGattCharacteristic.PROPERTY_BROADCAST > 0) {
        propertiesList.add(CharacteristicProperty.BROADCAST)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_READ > 0) {
        propertiesList.add(CharacteristicProperty.READ)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE > 0) {
        propertiesList.add(CharacteristicProperty.WRITE_WITHOUT_RESPONSE)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_WRITE > 0) {
        propertiesList.add(CharacteristicProperty.WRITE)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY > 0) {
        propertiesList.add(CharacteristicProperty.NOTIFY)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_INDICATE > 0) {
        propertiesList.add(CharacteristicProperty.INDICATE)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_SIGNED_WRITE > 0) {
        propertiesList.add(CharacteristicProperty.AUTHENTICATED_SIGNED_WRITES)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_EXTENDED_PROPS > 0) {
        propertiesList.add(CharacteristicProperty.EXTENDED_PROPERTIES)
    }
    return propertiesList
}

fun Short.toByteArray(byteOrder: ByteOrder = ByteOrder.LITTLE_ENDIAN): ByteArray =
    ByteBuffer.allocate(2).order(byteOrder).putShort(this).array()

fun createFlutterError(
    code: UniversalBleErrorCode,
    message: String? = null,
    details: String? = null,
) = FlutterError(code.raw.toString(), message, details ?: code.toString())

fun Int.parseScanErrorMessage(): String {
    return when (this) {
        ScanSettings.SCAN_MODE_LOW_POWER -> "Scan mode: low power"
        ScanSettings.SCAN_MODE_BALANCED -> "Scan mode: balanced"
        ScanSettings.SCAN_MODE_LOW_LATENCY -> "Scan mode: low latency"
        ScanSettings.SCAN_MODE_OPPORTUNISTIC -> "Scan mode: opportunistic"
        else -> "Unknown scan mode: $this"
    }
}

fun Int.parseBluetoothStatusCodeError(): UniversalBleErrorCode? {
    if (this == BluetoothStatusCodes.SUCCESS) return null
    return when (this) {
        BluetoothStatusCodes.ERROR_BLUETOOTH_NOT_ENABLED -> UniversalBleErrorCode.BLUETOOTH_NOT_ENABLED
        BluetoothStatusCodes.ERROR_BLUETOOTH_NOT_ALLOWED -> UniversalBleErrorCode.BLUETOOTH_NOT_ALLOWED
        BluetoothStatusCodes.ERROR_DEVICE_NOT_BONDED -> UniversalBleErrorCode.NOT_PAIRED
        BluetoothStatusCodes.ERROR_GATT_WRITE_NOT_ALLOWED -> UniversalBleErrorCode.WRITE_NOT_PERMITTED
        BluetoothStatusCodes.ERROR_GATT_WRITE_REQUEST_BUSY -> UniversalBleErrorCode.WRITE_REQUEST_BUSY
        BluetoothStatusCodes.ERROR_MISSING_BLUETOOTH_CONNECT_PERMISSION -> UniversalBleErrorCode.CONNECTION_FAILED
        BluetoothStatusCodes.ERROR_PROFILE_SERVICE_NOT_BOUND -> UniversalBleErrorCode.SERVICE_NOT_FOUND
        BluetoothStatusCodes.ERROR_UNKNOWN -> UniversalBleErrorCode.UNKNOWN_ERROR
        BluetoothStatusCodes.FEATURE_NOT_CONFIGURED -> UniversalBleErrorCode.NOT_IMPLEMENTED
        BluetoothStatusCodes.FEATURE_NOT_SUPPORTED -> UniversalBleErrorCode.NOT_SUPPORTED
        else -> null
    }
}

fun AndroidScanMode.parse(): Int? {
    return when (this) {
        AndroidScanMode.BALANCED -> ScanSettings.SCAN_MODE_BALANCED
        AndroidScanMode.LOW_LATENCY -> ScanSettings.SCAN_MODE_LOW_LATENCY
        AndroidScanMode.LOW_POWER -> ScanSettings.SCAN_MODE_LOW_POWER
        AndroidScanMode.OPPORTUNISTIC -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            ScanSettings.SCAN_MODE_OPPORTUNISTIC
        } else {
            PrinterConnectLogger.logError("Scan mode OPPORTUNISTIC is not supported on this Android version.")
            null
        }
    }
}

fun AndroidScanCallbackType.parse(): Int? {
    return when (this) {
        AndroidScanCallbackType.ALL_MATCHES -> ScanSettings.CALLBACK_TYPE_ALL_MATCHES
        AndroidScanCallbackType.FIRST_MATCH ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                ScanSettings.CALLBACK_TYPE_FIRST_MATCH
            } else {
                PrinterConnectLogger.logError("CALLBACK_TYPE_FIRST_MATCH requires Android API 23+.")
                null
            }
        AndroidScanCallbackType.MATCH_LOST ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                ScanSettings.CALLBACK_TYPE_MATCH_LOST
            } else {
                PrinterConnectLogger.logError("CALLBACK_TYPE_MATCH_LOST requires Android API 23+.")
                null
            }
        AndroidScanCallbackType.ALL_MATCHES_AUTO_BATCH ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ScanSettings.CALLBACK_TYPE_ALL_MATCHES_AUTO_BATCH
            } else {
                PrinterConnectLogger.logError("CALLBACK_TYPE_ALL_MATCHES_AUTO_BATCH requires Android API 34+.")
                null
            }
    }
}

fun AndroidScanMatchMode.parse(): Int? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
        PrinterConnectLogger.logError("Match mode is not supported on this Android version.")
        return null
    }
    return when (this) {
        AndroidScanMatchMode.AGGRESSIVE -> ScanSettings.MATCH_MODE_AGGRESSIVE
        AndroidScanMatchMode.STICKY -> ScanSettings.MATCH_MODE_STICKY
    }
}

fun AndroidScanNumOfMatches.parse(): Int? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
        PrinterConnectLogger.logError("Num of matches is not supported on this Android version.")
        return null
    }
    return when (this) {
        AndroidScanNumOfMatches.ONE -> ScanSettings.MATCH_NUM_ONE_ADVERTISEMENT
        AndroidScanNumOfMatches.FEW -> ScanSettings.MATCH_NUM_FEW_ADVERTISEMENT
        AndroidScanNumOfMatches.MAX -> ScanSettings.MATCH_NUM_MAX_ADVERTISEMENT
    }
}

fun gattStatusToPrinterConnectErrorCode(code: Int): UniversalBleErrorCode {
    return when (code) {
        BluetoothGatt.GATT_READ_NOT_PERMITTED -> UniversalBleErrorCode.READ_NOT_PERMITTED
        BluetoothGatt.GATT_WRITE_NOT_PERMITTED -> UniversalBleErrorCode.WRITE_NOT_PERMITTED
        BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION -> UniversalBleErrorCode.INSUFFICIENT_AUTHENTICATION
        BluetoothGatt.GATT_INSUFFICIENT_AUTHORIZATION -> UniversalBleErrorCode.INSUFFICIENT_AUTHORIZATION
        BluetoothGatt.GATT_INSUFFICIENT_ENCRYPTION -> UniversalBleErrorCode.INSUFFICIENT_ENCRYPTION
        BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED -> UniversalBleErrorCode.OPERATION_NOT_SUPPORTED
        BluetoothGatt.GATT_INVALID_OFFSET -> UniversalBleErrorCode.INVALID_OFFSET
        BluetoothGatt.GATT_INVALID_ATTRIBUTE_LENGTH -> UniversalBleErrorCode.INVALID_ATTRIBUTE_LENGTH
        BluetoothGatt.GATT_CONNECTION_CONGESTED -> UniversalBleErrorCode.CONNECTION_FAILED
        BluetoothGatt.GATT_FAILURE -> UniversalBleErrorCode.FAILED
        0x01 -> UniversalBleErrorCode.INVALID_HANDLE
        0x04 -> UniversalBleErrorCode.INVALID_PDU
        0x09 -> UniversalBleErrorCode.OPERATION_IN_PROGRESS
        0x0a -> UniversalBleErrorCode.SERVICE_NOT_FOUND
        0x0b -> UniversalBleErrorCode.INVALID_ATTRIBUTE_LENGTH
        0x0c -> UniversalBleErrorCode.INSUFFICIENT_KEY_SIZE
        0x0e -> UniversalBleErrorCode.FAILED
        0x10 -> UniversalBleErrorCode.OPERATION_NOT_SUPPORTED
        0x11 -> UniversalBleErrorCode.FAILED
        else -> UniversalBleErrorCode.UNKNOWN_ERROR
    }
}

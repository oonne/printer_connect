package com.example.printer_connect

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.ScanCallback.SCAN_FAILED_ALREADY_STARTED
import android.bluetooth.le.ScanCallback.SCAN_FAILED_APPLICATION_REGISTRATION_FAILED
import android.bluetooth.le.ScanCallback.SCAN_FAILED_FEATURE_UNSUPPORTED
import android.bluetooth.le.ScanCallback.SCAN_FAILED_INTERNAL_ERROR
import android.bluetooth.le.ScanCallback.SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES
import android.bluetooth.le.ScanCallback.SCAN_FAILED_SCANNING_TOO_FREQUENTLY
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Context.RECEIVER_EXPORTED
import android.content.Context.RECEIVER_NOT_EXPORTED
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.SparseArray
import androidx.core.util.size
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

// CCCD (客户端配置描述符) UUID，用于通知/指示功能的启用配置
val ccdCharacteristic: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

// GATT 缓存池：以设备地址为 key，存储 BluetoothGatt 实例。
// 使用 ConcurrentHashMap 确保并发安全，在连接/断开时进行增删操作。
// 用于在多个操作间共享同一个 GATT 连接实例，避免重复创建连接。
internal val knownGatts = ConcurrentHashMap<String, BluetoothGatt>()

// 配对状态变更事件，封装设备和配对状态
data class BondStateChange(
    val device: BluetoothDevice,
    val state: Int,
)

// 将 Android GATT 连接状态常量转换为跨平台 BleConnectionState 枚举
fun Int.toBleConnectionState(): BleConnectionState {
    return when (this) {
        BluetoothGatt.STATE_CONNECTED -> BleConnectionState.CONNECTED
        BluetoothGatt.STATE_CONNECTING -> BleConnectionState.CONNECTING
        BluetoothGatt.STATE_DISCONNECTING -> BleConnectionState.DISCONNECTING
        BluetoothGatt.STATE_DISCONNECTED -> BleConnectionState.DISCONNECTED
        else -> BleConnectionState.DISCONNECTED
    }
}

// 将字符串列表转换为 UUID 列表，用于服务过滤
fun List<String>.toUUIDList(): List<UUID> {
    return this.map { UUID.fromString(it) }
}

// 根据设备 ID 查找已缓存的 BluetoothGatt 实例，若未找到则抛出异常
fun String.toBluetoothGatt(): BluetoothGatt {
    return this.findGatt()
        ?: throw createFlutterError(
            UniversalBleErrorCode.DEVICE_NOT_FOUND,
            "Unknown deviceId: $this",
        )
}

// 检查设备 ID 是否存在于 GATT 缓存中
fun String.isKnownGatt(): Boolean {
    return this.findGatt() != null
}

// 从 GATT 缓存池中查找设备对应的 BluetoothGatt 实例
fun String.findGatt(): BluetoothGatt? {
    return knownGatts[this]
}

// 检查蓝牙适配器是否可用
fun BluetoothManager?.isBluetoothEnabled(): Boolean {
    return this?.adapter?.isEnabled == true
}

// 兼容获取广播中的蓝牙设备对象，适配 Android 13+ 的 API 变更
fun Intent.getBluetoothDeviceCompat(): BluetoothDevice? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        this.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
    } else {
        @Suppress("DEPRECATION")
        this.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
    }
}

// 从广播 Intent 中解析配对状态变更信息
fun Intent.getBondStateChange(): BondStateChange? {
    if (action != BluetoothDevice.ACTION_BOND_STATE_CHANGED) return null
    val device = this.getBluetoothDeviceCompat() ?: return null
    val state = this.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
    return BondStateChange(device, state)
}

// 判断设备是否已配对（BOND_BONDED 状态）
fun BluetoothDevice.isBonded(): Boolean = bondState == BluetoothDevice.BOND_BONDED

// 兼容注册广播接收器，适配 Android 13+ 需要指定 RECEIVER_EXPORTED/NOT_EXPORTED
fun Context.registerReceiverCompat(
    receiver: android.content.BroadcastReceiver,
    filter: IntentFilter,
    exported: Boolean = false,
) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        val receiverFlag = if (exported) Context.RECEIVER_EXPORTED else Context.RECEIVER_NOT_EXPORTED
        registerReceiver(receiver, filter, receiverFlag)
    } else {
        @Suppress("DEPRECATION")
        registerReceiver(receiver, filter)
    }
}

// 将 GATT 实例保存到缓存池中，key 为设备地址
@SuppressLint("MissingPermission")
fun BluetoothGatt.saveCacheIfNeeded() {
    knownGatts[this.device.address] = this
}

// 从缓存池中移除 GATT 实例
@SuppressLint("MissingPermission")
fun BluetoothGatt.removeCache() {
    knownGatts.remove(this.device.address)
}

// 将蓝牙适配器状态转换为跨平台可用性状态枚举
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

// 解析扫描结果中的制造商数据列表。
// 优先从原始字节解析（支持多个公司ID的合并数据），回退到系统 API 的 manufacturerSpecificData。
// 数据格式遵循 BLE 广播包格式：[长度][类型0xFF][公司ID低字节][公司ID高字节][数据...]
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
                // 类型 0xFF 表示制造商自定义数据
                if ((raw[i + 1].toInt() and 0xFF) == 0xFF && fieldLen >= 3) {
                    // 公司ID为小端序 16 位值
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
        // 回退方案：使用系统 API 直接获取制造商数据
        return scanRecord?.manufacturerSpecificData?.toList()?.map { (key, value) ->
            UniversalManufacturerData(key.toLong(), value)
        } ?: emptyList()
    }

val ScanResult.serviceData: Map<String, ByteArray>
    get() {
        return scanRecord?.serviceData?.mapKeys { it.key.uuid.toString() } ?: emptyMap()
    }

fun <T> SparseArray<T>.toList(): List<Pair<Int, T>> {
    return (0 until size).map { index ->
        keyAt(index) to valueAt(index)
    }
}

// 通过服务 UUID 和特征 UUID 从 GATT 中查找特征对象
@SuppressLint("MissingPermission")
fun BluetoothGatt.getCharacteristic(
    service: String,
    characteristic: String,
): BluetoothGattCharacteristic? {
    return getService(UUID.fromString(service))?.getCharacteristic(UUID.fromString(characteristic))
}

// 通过反射调用隐藏的 removeBond 方法来取消配对
@SuppressLint("MissingPermission")
fun BluetoothDevice.removeBond() {
    try {
        javaClass.getMethod("removeBond").invoke(this)
    } catch (e: Exception) {
        PrinterConnectLogger.logError("Removing bond failed. ${e.message}")
    }
}

// 解析 GATT 特征的属性位掩码（8 个属性位），转为跨平台 CharacteristicProperty 枚举列表
// 属性位包括：BROADCAST, READ, WRITE_NO_RESPONSE, WRITE, NOTIFY, INDICATE, SIGNED_WRITE, EXTENDED_PROPERTIES
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

// 将 Short 值转为字节数组，用于协议数据的字节序转换
fun Short.toByteArray(byteOrder: ByteOrder = ByteOrder.LITTLE_ENDIAN): ByteArray =
    ByteBuffer.allocate(2).order(byteOrder).putShort(this).array()

// 创建 Flutter 异常对象，包含错误码、消息和详情
fun createFlutterError(
    code: UniversalBleErrorCode,
    message: String? = null,
    details: String? = null,
) = FlutterException(code.raw.toString(), message, details ?: code.toString())

// 解析扫描错误码为可读的错误描述字符串
fun Int.parseScanErrorMessage(): String {
    return when (this) {
        SCAN_FAILED_ALREADY_STARTED -> "SCAN_FAILED_ALREADY_STARTED"
        SCAN_FAILED_APPLICATION_REGISTRATION_FAILED -> "SCAN_FAILED_APPLICATION_REGISTRATION_FAILED"
        SCAN_FAILED_FEATURE_UNSUPPORTED -> "SCAN_FAILED_FEATURE_UNSUPPORTED"
        SCAN_FAILED_INTERNAL_ERROR -> "SCAN_FAILED_INTERNAL_ERROR"
        SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES -> "SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES"
        SCAN_FAILED_SCANNING_TOO_FREQUENTLY -> "SCAN_FAILED_SCANNING_TOO_FREQUENTLY"
        else -> "ErrorCode: $this"
    }
}

// 将 BluetoothStatusCodes 错误码转换为通用错误码
// 用于在 Android 13+ 的新 API 中统一错误表示
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

// 将 Android GATT 状态码转换为通用错误码
// 涵盖标准 GATT 状态码（如 GATT_READ_NOT_PERMITTED）和 HCI 错误码
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

package com.example.printer_connect

import android.annotation.SuppressLint
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.os.ParcelUuid
import android.util.Log
import java.util.UUID
import kotlin.experimental.and

// 过滤器工具类，负责 BLE 扫描结果的过滤逻辑
// 支持三种过滤方式：名称前缀、服务 UUID、制造商数据
// 工作模式分为：自定义过滤（Dart 端过滤）和原生过滤（Android ScanFilter）
object PrinterConnectFilterUtil {

    // 当前设置的通用扫描过滤器（Dart 端传入）
    var scanFilter: UniversalScanFilter? = null
    // 原生过滤器使用的服务 UUID 列表
    var serviceFilterUUIDS: List<UUID> = emptyList()

    // 核心过滤方法，根据名称、制造商数据和服务 UUID 判断设备是否匹配
    // 返回 true 表示设备通过所有过滤条件
    fun filterDevice(
        name: String?,
        manufacturerDataList: List<UniversalManufacturerData>,
        serviceUuids: Array<UUID>,
    ): Boolean {
        val filter = scanFilter ?: return true
        val hasNamePrefixFilter = filter.withNamePrefix.isNotEmpty()
        val hasServiceFilter = filter.withServices.isNotEmpty()
        val hasManufacturerDataFilter = filter.withManufacturerData.isNotEmpty()

        if (!hasNamePrefixFilter &&
            !hasServiceFilter &&
            !hasManufacturerDataFilter
        ) {
            return true
        }

        return hasNamePrefixFilter && isNameMatchingFilters(filter, name) ||
                hasServiceFilter && isServicesMatchingFilters(serviceUuids) ||
                hasManufacturerDataFilter && isManufacturerDataMatchingFilters(
            filter,
            manufacturerDataList
        )
    }

    // 名称前缀匹配：检查设备名称是否以任一过滤前缀开头
    // 若无前缀规则则直接通过；设备名为空则不匹配
    private fun isNameMatchingFilters(scanFilter: UniversalScanFilter, name: String?): Boolean {
        val namePrefixFilter = scanFilter.withNamePrefix
        if (namePrefixFilter.isEmpty()) {
            return true
        }
        if (name.isNullOrEmpty()) {
            return false
        }
        return namePrefixFilter.any { name.startsWith(it) }
    }

    // 服务 UUID 匹配：检查设备广播的服务 UUID 是否包含任一过滤 UUID
    // 若过滤列表为空则直接通过；设备无服务 UUID 则不匹配
    private fun isServicesMatchingFilters(
        serviceUuids: Array<UUID>,
    ): Boolean {
        if (serviceFilterUUIDS.isEmpty()) {
            return true
        }
        if (serviceUuids.isEmpty()) {
            return false
        }
        return serviceFilterUUIDS.any {
            serviceUuids.contains(it)
        }
    }

    // 制造商数据匹配：遍历设备的制造商数据列表，检查是否满足任一过滤条件
    // 匹配规则：公司 ID 一致 且 数据载荷通过位掩码匹配
    private fun isManufacturerDataMatchingFilters(
        scanFilter: UniversalScanFilter,
        manufacturerDataList: List<UniversalManufacturerData>,
    ): Boolean {
        val filters = scanFilter.withManufacturerData
        if (filters.isEmpty()) return true
        if (manufacturerDataList.isEmpty()) return false
        return manufacturerDataList.any { msd ->
            filters.any { filter ->
                msd.companyIdentifier == filter.companyIdentifier &&
                        isDataMatching(filter.payloadPrefix, msd.data, filter.payloadMask)
            }
        }
    }

    // 数据匹配算法：使用位掩码逐字节比对过滤前缀与设备数据
    // 掩码为 null 时默认为全 0xFF（所有位都参与比较）
    // 匹配规则：(filterData[i] and mask[i]) == (deviceData[i] and mask[i])
    private fun isDataMatching(
        filterData: ByteArray?,
        deviceData: ByteArray,
        filterMask: ByteArray?,
    ): Boolean {
        if (filterData == null) return true
        if (filterData.size > deviceData.size) return false
        val mask = filterMask ?: ByteArray(filterData.size) { 0xFF.toByte() }
        if (filterData.size != mask.size) return false
        return filterData.indices.all { i ->
            (filterData[i] and mask[i]) == (deviceData[i] and mask[i])
        }
    }
}

// 顶级扩展函数（放在对象外部，便于以 `filter?.usesCustomFilters()` / `filter.toScanFilters(...)` 的形式直接调用，
// 与参考项目结构保持一致。

// 判断是否需要使用自定义过滤（Dart 端过滤）。
// 选择策略：名称前缀过滤在原生 ScanFilter 中不支持，必须使用自定义过滤；
// 制造商数据和服务 UUID 可通过原生 ScanFilter 实现，无需自定义过滤。
fun UniversalScanFilter?.usesCustomFilters(): Boolean {
    if (this == null) return false
    return withNamePrefix.isNotEmpty()
}

// 将通用扫描过滤器转换为 Android 原生 ScanFilter 列表
// 用于在 startScan 时直接传递给 BluetoothLeScanner 进行原生过滤
// 包含两类原生过滤：服务 UUID 过滤 和 制造商数据过滤（支持 payloadMask 位掩码）
fun UniversalScanFilter.toScanFilters(serviceUuids: List<UUID>): List<ScanFilter> {
    val scanFilters = mutableListOf<ScanFilter>()

    for (service in serviceUuids) {
        try {
            scanFilters.add(
                ScanFilter.Builder().setServiceUuid(ParcelUuid(service)).build()
            )
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Invalid service UUID: $service")
            throw createFlutterError(
                UniversalBleErrorCode.FAILED,
                "Invalid serviceId: $service",
                e.toString(),
            )
        }
    }

    for (manufacturerData in this.withManufacturerData) {
        try {
            val data = manufacturerData.payloadPrefix ?: ByteArray(0)
            val mask = manufacturerData.payloadMask
            if (mask == null) {
                scanFilters.add(
                    ScanFilter.Builder().setManufacturerData(
                        manufacturerData.companyIdentifier.toInt(), data
                    ).build()
                )
            } else {
                scanFilters.add(
                    ScanFilter.Builder().setManufacturerData(
                        manufacturerData.companyIdentifier.toInt(), data, mask
                    ).build()
                )
            }
        } catch (e: Exception) {
            PrinterConnectLogger.logError("Invalid manufacturerData: ${manufacturerData.companyIdentifier}")
            throw createFlutterError(
                UniversalBleErrorCode.FAILED,
                "Invalid manufacturerData: ${manufacturerData.companyIdentifier} ${manufacturerData.payloadPrefix} ${manufacturerData.payloadMask}",
                e.toString(),
            )
        }
    }

    return scanFilters
}

@SuppressLint("MissingPermission")
// 判断扫描结果是否匹配过滤器。
// 使用 resolvedDeviceName（优先广播名称，其次缓存的 device.name）确保过滤使用的名称源
// 与上报给 Dart 层的名称源一致，避免过滤结果与实际结果不匹配。
fun ScanResult.isDeviceMatchingFilter(filter: UniversalScanFilter?): Boolean {
    if (filter == null) return true
    val name = this.resolvedDeviceName
    val manufacturerData = this.manufacturerDataList
    // scanRecord.serviceUuids 为 List<ParcelUuid>，提取 .uuid 转为 Array<UUID> 用于过滤
    val serviceUuids = scanRecord?.serviceUuids?.map { it.uuid }?.toTypedArray() ?: arrayOf()
    return PrinterConnectFilterUtil.filterDevice(name, manufacturerData, serviceUuids)
}

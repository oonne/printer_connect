package com.example.printer_connect

import android.annotation.SuppressLint
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.os.ParcelUuid
import android.util.Log
import java.util.UUID
import kotlin.experimental.and

object PrinterConnectFilterUtil {

    var scanFilter: UniversalScanFilter? = null
    var serviceFilterUUIDS: List<UUID> = emptyList()

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

// Top-level extension functions (kept outside the object so they can be invoked
// directly as `filter?.usesCustomFilters()` / `filter.toScanFilters(...)`, matching
// the reference project structure).
fun UniversalScanFilter?.usesCustomFilters(): Boolean {
    if (this == null) return false
    // NamePrefix filtering is not supported in native filters, so it requires
    // custom Dart-side filtering. ManufacturerData is handled by native filters
    // via toScanFilters, so it does not require custom filtering here.
    return withNamePrefix.isNotEmpty()
}

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
fun ScanResult.isDeviceMatchingFilter(filter: UniversalScanFilter?): Boolean {
    if (filter == null) return true
    // Use resolvedDeviceName (advertised name preferred over cached device.name) so the filter
    // uses the same name source that is reported to Dart in handleScanResult.
    val name = this.resolvedDeviceName
    val manufacturerData = this.manufacturerDataList
    // scanRecord.serviceUuids is List<ParcelUuid>; extract .uuid to get Array<UUID> for filtering.
    val serviceUuids = scanRecord?.serviceUuids?.map { it.uuid }?.toTypedArray() ?: arrayOf()
    return PrinterConnectFilterUtil.filterDevice(name, manufacturerData, serviceUuids)
}

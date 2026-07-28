package com.example.printer_connect

import android.os.Build
import android.bluetooth.le.ScanResult

object PrinterConnectFilterUtil {

    fun filterDevice(
        scanResult: ScanResult,
        filters: List<UniversalScanFilter>?,
        allowDuplicates: Boolean = false
    ): Boolean {
        if (filters.isNullOrEmpty()) return true

        for (filter in filters) {
            val matchesName = isNameMatchingFilters(scanResult, filter.withLocalName, filter.withLocalNamePrefix)
            val matchesServices = isServicesMatchingFilters(scanResult, filter.withServices)
            val matchesManufacturerData = isManufacturerDataMatchingFilters(scanResult, filter.withManufacturerData)

            if (matchesName && matchesServices && matchesManufacturerData) {
                return true
            }
        }

        return false
    }

    fun isNameMatchingFilters(scanResult: ScanResult, nameFilter: String?, namePrefixFilter: String? = null): Boolean {
        val deviceName = scanResult.device?.name

        if (nameFilter != null && nameFilter.isNotEmpty()) {
            if (deviceName == null || !deviceName.contains(nameFilter, ignoreCase = true)) {
                val resolvedName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    scanResult.resolvedDeviceName()
                } else {
                    null
                }
                val matchesResolved = resolvedName != null && resolvedName.contains(nameFilter, ignoreCase = true)
                if (!matchesResolved) return false
            }
        }

        if (namePrefixFilter != null && namePrefixFilter.isNotEmpty()) {
            val nameToCheck = deviceName ?: return false
            if (!nameToCheck.startsWith(namePrefixFilter, ignoreCase = true)) {
                return false
            }
        }

        if ((nameFilter == null || nameFilter.isEmpty()) && (namePrefixFilter == null || namePrefixFilter.isEmpty())) {
            return true
        }

        return true
    }

    fun isServicesMatchingFilters(scanResult: ScanResult, serviceUuidsFilter: List<String>?): Boolean {
        if (serviceUuidsFilter == null || serviceUuidsFilter.isEmpty()) return true

        val scanRecord = scanResult.scanRecord ?: return false
        val advertisedUuids = scanRecord.serviceUuids ?: return false

        val filterUuids = serviceUuidsFilter.map { it.uppercase() }.toSet()
        val advertisedUuidStrings = advertisedUuids.map { it.toString().uppercase() }.toSet()

        return advertisedUuidStrings.containsAll(filterUuids)
    }

    fun isManufacturerDataMatchingFilters(scanResult: ScanResult, manufacturerDataFilter: List<ManufacturerDataFilter>?): Boolean {
        if (manufacturerDataFilter == null || manufacturerDataFilter.isEmpty()) return true

        val scanRecord = scanResult.scanRecord ?: return false
        val manufacturerDataMap = scanRecord.manufacturerSpecificData ?: return false

        for (filterItem in manufacturerDataFilter) {
            val companyId = filterItem.companyId.toInt()
            val data = manufacturerDataMap[companyId] ?: return false

            val filterData = filterItem.data?.map { it.toInt() and 0xFF }?.toByteArray() ?: ByteArray(0)

            if (filterData.isNotEmpty() && !data.startsWith(filterData)) {
                return false
            }
        }

        return true
    }

    fun UniversalScanFilter?.usesCustomFilters(): Boolean {
        if (this == null) return false
        return withLocalName != null ||
            withLocalNamePrefix != null ||
            (withServices != null && withServices.isNotEmpty()) ||
            (withManufacturerData != null && withManufacturerData.isNotEmpty())
    }

    fun List<UniversalScanFilter>.toScanFilters(): List<android.bluetooth.le.ScanFilter> {
        val result = mutableListOf<android.bluetooth.le.ScanFilter>()

        for (filter in this) {
            val builder = android.bluetooth.le.ScanFilter.Builder()

            filter.withLocalName?.let { name ->
                builder.setName(name)
            }

            filter.withServices?.let { uuids ->
                for (uuidStr in uuids) {
                    try {
                        val uuid = java.util.UUID.fromString(uuidStr)
                        builder.addServiceUuid(android.os.ParcelUuid(uuid))
                    } catch (e: Exception) {
                        PrinterConnectLogger.logWarning("Invalid service UUID: $uuidStr")
                    }
                }
            }

            filter.withManufacturerData?.let { mfrData ->
                for (mfr in mfrData) {
                    val companyId = mfr.companyId.toInt()
                    val dataBytes = mfr.data?.map { it.toInt() and 0xFF }?.toByteArray() ?: ByteArray(0)
                    if (dataBytes.isNotEmpty()) {
                        builder.addManufacturerData(companyId, dataBytes)
                    }
                }
            }

            try {
                result.add(builder.build())
            } catch (e: Exception) {
                PrinterConnectLogger.logWarning("Failed to build scan filter: ${e.message}")
            }
        }

        return result
    }
}
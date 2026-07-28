package com.example.printer_connect

import android.os.Build
import android.bluetooth.le.ScanResult
import android.os.ParcelUuid

object PrinterConnectFilterUtil {

    fun filterDevice(
        scanResult: ScanResult,
        filter: UniversalScanFilter?,
        allowDuplicates: Boolean = false
    ): Boolean {
        if (filter == null) return true

        val matchesName = isNameMatchingFilters(scanResult, filter.withNamePrefix)
        val matchesServices = isServicesMatchingFilters(scanResult, filter.withServices)
        val matchesManufacturerData = isManufacturerDataMatchingFilters(scanResult, filter.withManufacturerData)

        return matchesName && matchesServices && matchesManufacturerData
    }

    fun isNameMatchingFilters(scanResult: ScanResult, namePrefixFilters: List<String>): Boolean {
        if (namePrefixFilters.isEmpty()) return true

        val deviceName = scanResult.device?.name
        val resolvedName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            scanResult.resolvedDeviceName()
        } else {
            null
        }

        for (prefix in namePrefixFilters) {
            val nameToCheck = deviceName ?: resolvedName ?: return false
            if (!nameToCheck.startsWith(prefix, ignoreCase = true)) {
                return false
            }
        }

        return true
    }

    fun isServicesMatchingFilters(scanResult: ScanResult, serviceUuidsFilter: List<String>): Boolean {
        if (serviceUuidsFilter.isEmpty()) return true

        val scanRecord = scanResult.scanRecord ?: return false
        val advertisedUuids = scanRecord.serviceUuids ?: return false

        val filterUuids = serviceUuidsFilter.map { it.uppercase() }.toSet()
        val advertisedUuidStrings = advertisedUuids.map { it.toString().uppercase() }.toSet()

        return advertisedUuidStrings.containsAll(filterUuids)
    }

    fun isManufacturerDataMatchingFilters(scanResult: ScanResult, manufacturerDataFilter: List<ManufacturerDataFilter>): Boolean {
        if (manufacturerDataFilter.isEmpty()) return true

        val scanRecord = scanResult.scanRecord ?: return false
        val manufacturerDataMap = scanRecord.manufacturerSpecificData ?: return false

        for (filterItem in manufacturerDataFilter) {
            val companyId = filterItem.companyIdentifier.toInt()
            val data = manufacturerDataMap[companyId] ?: return false

            val payloadPrefix = filterItem.payloadPrefix
            if (payloadPrefix != null && payloadPrefix.isNotEmpty()) {
                if (data.size < payloadPrefix.size) return false

                val payloadMask = filterItem.payloadMask
                for (i in payloadPrefix.indices) {
                    val maskByte = if (payloadMask != null && i < payloadMask.size) {
                        payloadMask[i].toInt() and 0xFF
                    } else {
                        0xFF
                    }
                    if (maskByte == 0) continue
                    if (data[i] != payloadPrefix[i]) return false
                }
            }
        }

        return true
    }

    fun UniversalScanFilter?.usesCustomFilters(): Boolean {
        if (this == null) return false
        return withNamePrefix.isNotEmpty() ||
            withServices.isNotEmpty() ||
            withManufacturerData.isNotEmpty()
    }

    fun List<UniversalScanFilter>.toScanFilters(): List<android.bluetooth.le.ScanFilter> {
        val result = mutableListOf<android.bluetooth.le.ScanFilter>()

        for (filter in this) {
            if (filter.withServices.size <= 1 &&
                filter.withManufacturerData.size <= 1 &&
                filter.withNamePrefix.size <= 1
            ) {
                val builder = android.bluetooth.le.ScanFilter.Builder()

                filter.withNamePrefix.firstOrNull()?.let { prefix ->
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        builder.setDeviceName(prefix)
                    }
                }

                filter.withServices.firstOrNull()?.let { uuidStr ->
                    try {
                        val uuid = java.util.UUID.fromString(uuidStr)
                        builder.setServiceUuid(ParcelUuid(uuid))
                    } catch (e: Exception) {
                        PrinterConnectLogger.logWarning("Invalid service UUID: $uuidStr")
                    }
                }

                filter.withManufacturerData.firstOrNull()?.let { mfr ->
                    val companyId = mfr.companyIdentifier.toInt()
                    val payloadPrefix = mfr.payloadPrefix
                    val payloadMask = mfr.payloadMask
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (payloadPrefix != null && payloadPrefix.isNotEmpty()) {
                            if (payloadMask != null && payloadMask.isNotEmpty()) {
                                builder.setManufacturerData(companyId, payloadPrefix, payloadMask)
                            } else {
                                builder.setManufacturerData(companyId, payloadPrefix)
                            }
                        }
                    }
                }

                try {
                    result.add(builder.build())
                } catch (e: Exception) {
                    PrinterConnectLogger.logWarning("Failed to build scan filter: ${e.message}")
                }
            } else {
                for (prefix in filter.withNamePrefix) {
                    val builder = android.bluetooth.le.ScanFilter.Builder()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        builder.setDeviceName(prefix)
                    }
                    try {
                        result.add(builder.build())
                    } catch (e: Exception) {
                        PrinterConnectLogger.logWarning("Failed to build scan filter: ${e.message}")
                    }
                }

                for (uuidStr in filter.withServices) {
                    val builder = android.bluetooth.le.ScanFilter.Builder()
                    try {
                        val uuid = java.util.UUID.fromString(uuidStr)
                        builder.setServiceUuid(ParcelUuid(uuid))
                    } catch (e: Exception) {
                        PrinterConnectLogger.logWarning("Invalid service UUID: $uuidStr")
                    }
                    try {
                        result.add(builder.build())
                    } catch (e: Exception) {
                        PrinterConnectLogger.logWarning("Failed to build scan filter: ${e.message}")
                    }
                }

                for (mfr in filter.withManufacturerData) {
                    val builder = android.bluetooth.le.ScanFilter.Builder()
                    val companyId = mfr.companyIdentifier.toInt()
                    val payloadPrefix = mfr.payloadPrefix
                    val payloadMask = mfr.payloadMask
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (payloadPrefix != null && payloadPrefix.isNotEmpty()) {
                            if (payloadMask != null && payloadMask.isNotEmpty()) {
                                builder.setManufacturerData(companyId, payloadPrefix, payloadMask)
                            } else {
                                builder.setManufacturerData(companyId, payloadPrefix)
                            }
                        }
                    }
                    try {
                        result.add(builder.build())
                    } catch (e: Exception) {
                        PrinterConnectLogger.logWarning("Failed to build scan filter: ${e.message}")
                    }
                }
            }
        }

        return result
    }
}
package com.example.printer_connect

import android.os.SystemClock
import java.util.concurrent.CopyOnWriteArrayList

class SafeScanner {

    private data class ScanRecord(val startTimeMs: Long)

    private val scanHistory = CopyOnWriteArrayList<ScanRecord>()
    private val maxScanRecords = 5
    private val scanWindowMs = 30_000L

    @Synchronized
    fun canStartScan(): Boolean {
        val now = SystemClock.elapsedRealtime()
        cleanupOldRecords(now)
        return scanHistory.size < maxScanRecords
    }

    @Synchronized
    fun recordScanStart(): Boolean {
        val now = SystemClock.elapsedRealtime()
        cleanupOldRecords(now)
        if (scanHistory.size >= maxScanRecords) {
            return false
        }
        scanHistory.add(ScanRecord(now))
        PrinterConnectLogger.logDebug("Scan started. Active scans: ${scanHistory.size}/$maxScanRecords")
        return true
    }

    @Synchronized
    fun getScansRemaining(): Int {
        val now = SystemClock.elapsedRealtime()
        cleanupOldRecords(now)
        return (maxScanRecords - scanHistory.size).coerceAtLeast(0)
    }

    @Synchronized
    fun getTimeUntilNextScanMs(): Long {
        if (scanHistory.isEmpty()) return 0L
        val now = SystemClock.elapsedRealtime()
        cleanupOldRecords(now)
        if (scanHistory.size < maxScanRecords) return 0L
        val oldest = scanHistory.minByOrNull { it.startTimeMs } ?: return 0L
        val timeRemaining = (oldest.startTimeMs + scanWindowMs) - now
        return timeRemaining.coerceAtLeast(0L)
    }

    @Synchronized
    fun reset() {
        scanHistory.clear()
        PrinterConnectLogger.logDebug("SafeScanner reset")
    }

    private fun cleanupOldRecords(now: Long) {
        val cutoffTime = now - scanWindowMs
        scanHistory.removeAll { it.startTimeMs < cutoffTime }
    }

    companion object {
        @Volatile
        private var instance: SafeScanner? = null

        fun getInstance(): SafeScanner {
            return instance ?: synchronized(this) {
                instance ?: SafeScanner().also { instance = it }
            }
        }
    }
}
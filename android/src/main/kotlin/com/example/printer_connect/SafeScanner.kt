package com.example.printer_connect

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import java.util.LinkedList

/**
 * Manages safe scan operations by limiting the number of concurrent scans
 * within a time window to prevent Bluetooth adapter issues.
 */
class SafeScanner {

    private data class ScanRecord(val startTimeMs: Long)

    private val scanHistory = LinkedList<ScanRecord>()
    private val maxScanRecords = 5
    private val scanWindowMs = 30_000L

    private val delayedScanHandler = Handler(Looper.getMainLooper())
    private var delayedScanRunnable: Runnable? = null

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
        delayedScanRunnable?.let { delayedScanHandler.removeCallbacks(it) }
        delayedScanRunnable = null
        PrinterConnectLogger.logDebug("SafeScanner reset")
    }

    /**
     * Schedules a scan to start after the cooldown period has elapsed.
     * @param onReady The callback to execute when the scan can start
     */
    fun scheduleScanStart(onReady: () -> Unit) {
        synchronized(this) {
            // Remove any previously scheduled delayed runnable
            delayedScanRunnable?.let { delayedScanHandler.removeCallbacks(it) }

            val delayMs = getTimeUntilNextScanMs()
            if (delayMs <= 0) {
                // No delay needed, execute immediately
                onReady()
                return
            }

            PrinterConnectLogger.logDebug("Scan delayed by ${delayMs}ms due to scan limit")

            val runnable = Runnable {
                synchronized(this) {
                    delayedScanRunnable = null
                }
                onReady()
            }

            delayedScanRunnable = runnable
            delayedScanHandler.postDelayed(runnable, delayMs)
        }
    }

    @Synchronized
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

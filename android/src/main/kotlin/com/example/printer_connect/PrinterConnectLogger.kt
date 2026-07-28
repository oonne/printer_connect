package com.example.printer_connect

import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object PrinterConnectLogger {
    private const val TAG = "PrinterConnect"
    private var currentLogLevel: BleLogLevel = BleLogLevel.NONE
    private val timeFormatter = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)

    fun setLogLevel(logLevel: BleLogLevel) {
        currentLogLevel = logLevel
    }

    fun logError(message: String) {
        if (!allows(BleLogLevel.ERROR)) return
        Log.e(TAG, withTimestamp(message))
    }

    fun logWarning(message: String) {
        if (!allows(BleLogLevel.WARNING)) return
        Log.w(TAG, withTimestamp(message))
    }

    fun logInfo(message: String) {
        if (!allows(BleLogLevel.INFO)) return
        Log.i(TAG, withTimestamp(message))
    }

    fun logDebug(message: String) {
        if (!allows(BleLogLevel.DEBUG)) return
        Log.d(TAG, withTimestamp(message))
    }

    fun logVerbose(message: String) {
        if (!allows(BleLogLevel.VERBOSE)) return
        Log.v(TAG, withTimestamp(message))
    }

    private fun allows(level: BleLogLevel): Boolean {
        if (currentLogLevel == BleLogLevel.NONE) return false
        return level.ordinal <= currentLogLevel.ordinal
    }

    private fun withTimestamp(message: String): String {
        return "[${timeFormatter.format(Date())}] $message"
    }
}
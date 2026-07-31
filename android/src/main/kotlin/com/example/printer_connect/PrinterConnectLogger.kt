package com.example.printer_connect

import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// 日志系统：基于 Android Log 封装的分级日志工具。
// 支持 5 个日志级别（ERROR > WARNING > INFO > DEBUG > VERBOSE），
// 通过 setLogLevel 设置输出阈值，仅输出指定级别及以上的日志。
// 每条日志自动添加时间戳前缀，便于调试时定位时序问题。
object PrinterConnectLogger {
    private const val TAG = "PrinterConnect"
    // 当前日志级别阈值，默认为 NONE（不输出任何日志）
    private var currentLogLevel: BleLogLevel = BleLogLevel.NONE
    // 时间戳格式：精确到毫秒，使用 Locale.US 保证格式一致
    private val timeFormatter = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)

    // 设置日志级别阈值，仅输出该级别及以上的日志
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

    // 判断指定级别是否允许输出：
    // - NONE 级别始终不输出
    // - 其他级别按 ordinal 值比较，level.ordinal <= currentLogLevel.ordinal 时允许输出
    private fun allows(level: BleLogLevel): Boolean {
        if (currentLogLevel == BleLogLevel.NONE) return false
        return level.ordinal <= currentLogLevel.ordinal
    }

    // 为日志消息添加时间戳前缀：[HH:mm:ss.SSS]
    private fun withTimestamp(message: String): String {
        return "[${timeFormatter.format(Date())}] $message"
    }
}

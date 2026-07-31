package com.example.printer_connect

import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanSettings
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.LinkedList

// 扫描频率限制参数：
// NUM_SCAN_DURATIONS_KEPT: 30 秒窗口内允许的最大扫描次数
// EXCESSIVE_SCANNING_PERIOD_MS: 频率限制的时间窗口（30 秒）
private const val NUM_SCAN_DURATIONS_KEPT = 5
private const val EXCESSIVE_SCANNING_PERIOD_MS = 30 * 1000L

/**
 * 安全的 BLE 扫描器包装类，用于防止过于频繁的扫描操作。
 *
 * Android 系统对 BLE 扫描频率有限制（30 秒内最多 5 次 startScan），
 * 超出限制会触发 SCAN_FAILED_SCANNING_TOO_FREQUENTLY 错误。
 * 本类通过以下机制确保遵守扫描限制：
 * - 维护滑动时间窗口，记录最近 30 秒内的扫描启动时间
 * - 当扫描次数达到上限时，拒绝新的扫描请求并返回错误回调
 * - 自动延迟重试：在最早的扫描请求超过 30 秒后自动重新发起扫描
 * - 提供安全的 start/stop 操作，含异常捕获和状态管理
 */
@SuppressLint("MissingPermission")
class SafeScanner(private val bluetoothManager: BluetoothManager) {

    private val handler = Handler(Looper.myLooper()!!)
    // 扫描启动时间记录列表，用于滑动窗口频率检查
    private val startTimes = LinkedList<Long>()
    // 标记是否有等待中的自动重试扫描
    private var awaitingScan = false
    // 标记当前是否正在扫描
    private var isScanning = false

    // 启动 BLE 扫描。
    // 频率限制机制：
    // 1. 清理超过 30 秒的历史记录
    // 2. 若已达上限：
    //    - 若已有等待中的重试，则忽略新请求
    //    - 否则计算延迟时间（最早记录 + 30 秒 - 当前时间 + 2 秒缓冲）
    //    - 延迟到期后自动重试 startScan
    // 3. 若未达上限：记录时间戳，调用原生 startScan
    fun startScan(filters: List<ScanFilter>, settings: ScanSettings, callback: ScanCallback) {
        val now = System.currentTimeMillis()
        startTimes.removeAll { now - it > EXCESSIVE_SCANNING_PERIOD_MS }

        if (startTimes.size >= NUM_SCAN_DURATIONS_KEPT) {
            if (awaitingScan) {
                PrinterConnectLogger.logError("startScan: too frequent, awaiting scan..")
                return
            }
            // Android 13+ 支持 SCAN_FAILED_SCANNING_TOO_FREQUENTLY 错误码
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                callback.onScanFailed(ScanCallback.SCAN_FAILED_SCANNING_TOO_FREQUENTLY)
            }
            awaitingScan = true
            // 自动延迟重试：等待最早的扫描记录超过窗口时间后，再加 2 秒缓冲
            val delay = startTimes.first() + EXCESSIVE_SCANNING_PERIOD_MS - now + 2_000
            PrinterConnectLogger.logDebug("startScan: too frequent, schedule auto-start after $delay ms $startTimes")
            handler.postDelayed({
                PrinterConnectLogger.logDebug("Retrying scan after delay")
                awaitingScan = false
                startScan(filters, settings, callback)
            }, delay)
        } else {
            awaitingScan = false
            startTimes.addLast(now)
            try {
                bluetoothManager.adapter.bluetoothLeScanner?.startScan(filters, settings, callback)
                isScanning = true
            } catch (e: Exception) {
                PrinterConnectLogger.logError("Failed to start Scan : $e")
                isScanning = false
            }
        }
    }

    // 停止 BLE 扫描，同时清除所有延迟重试任务
    fun stopScan(callback: ScanCallback) {
        awaitingScan = false
        handler.removeCallbacksAndMessages(null)
        bluetoothManager.adapter.bluetoothLeScanner?.stopScan(callback)
        isScanning = false
    }

    // 查询扫描状态：包含正在扫描和等待重试两种状态
    fun isScanning(): Boolean {
        return isScanning || awaitingScan
    }
}

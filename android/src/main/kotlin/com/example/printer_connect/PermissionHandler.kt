package com.example.printer_connect

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

// 权限处理器：负责蓝牙和位置权限的检查、请求和结果处理。
// 根据 Android 版本差异采用不同的权限策略：
// - Android 12+ (API 31+)：使用 BLUETOOTH_SCAN / BLUETOOTH_CONNECT 细粒度权限，位置权限可选
// - Android 11- (API 30-)：使用 BLUETOOTH / BLUETOOTH_ADMIN，位置权限为扫描所必需
object PermissionHandler {

    // 检查是否已授予所有指定权限
    fun hasPermissions(context: Context, permissions: List<String>): Boolean {
        for (permission in permissions) {
            if (ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED) {
                return false
            }
        }
        return true
    }

    // 根据 Android 版本和使用场景获取所需权限列表。
    //
    // Android 12+ (API 31+) 权限策略：
    // - BLUETOOTH_CONNECT：始终需要（GATT 连接操作）
    // - BLUETOOTH_SCAN：仅在 forScan=true 时需要（扫描操作）
    // - ACCESS_FINE_LOCATION：可选，仅当调用方显式要求 (withAndroidFineLocation=true)
    //   且 Manifest 中已声明时才请求，避免因请求未声明的权限而被系统自动拒绝
    //
    // Android 11- (API 30-) 权限策略：
    // - BLUETOOTH + BLUETOOTH_ADMIN：蓝牙操作基础权限
    // - ACCESS_FINE_LOCATION：BLE 扫描的强制要求，无位置权限则扫描无法发现设备
    fun getRequiredPermissions(
        context: Context,
        forScan: Boolean = false,
        withAndroidFineLocation: Boolean = false
    ): List<String> {
        val permissions = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
            if (forScan) {
                permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            }
            // Android 12+ 上位置权限为可选项，仅在调用方明确需要时才请求
            // 仅在 Manifest 中声明时才请求，否则请求未声明的权限会被自动拒绝并导致整个批次失败
            if (withAndroidFineLocation &&
                hasPermissionInManifest(context, Manifest.permission.ACCESS_FINE_LOCATION)
            ) {
                permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
            }
        } else {
            permissions.add(Manifest.permission.BLUETOOTH)
            permissions.add(Manifest.permission.BLUETOOTH_ADMIN)
            // Android 11 及以下版本，ACCESS_FINE_LOCATION 是 BLE 扫描的必要条件
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        return permissions
    }

    // 检查指定权限是否在 AndroidManifest.xml 中声明。
    // 用于避免请求未声明的权限（会被系统自动拒绝并导致整个权限批次失败）。
    // 通过反射读取包信息中的 requestedPermissions 列表进行判断。
    fun hasPermissionInManifest(context: Context, permission: String): Boolean {
        return try {
            val packageInfo = context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_PERMISSIONS
            )
            packageInfo.requestedPermissions?.contains(permission) == true
        } catch (e: Exception) {
            false
        }
    }

    // 验证扫描所需的权限是否全部已授予
    fun validateRequiredPermissions(context: Context): Boolean {
        val required = getRequiredPermissions(context, forScan = true)
        return hasPermissions(context, required)
    }

    // 获取 GATT 连接操作所需的权限
    fun getConnectPermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            listOf(Manifest.permission.BLUETOOTH, Manifest.permission.BLUETOOTH_ADMIN)
        }
    }

    // 获取 BLE 扫描操作所需的权限
    fun getScanPermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            listOf(Manifest.permission.BLUETOOTH, Manifest.permission.BLUETOOTH_ADMIN)
        }
    }

    // 获取位置权限列表。
    // Android 12+ 上位置权限不再是蓝牙操作的必要条件，返回空列表。
    fun getLocationPermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            emptyList()
        } else {
            listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }
}

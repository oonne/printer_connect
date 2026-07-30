package com.example.printer_connect

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

object PermissionHandler {

    fun hasPermissions(context: Context, permissions: List<String>): Boolean {
        for (permission in permissions) {
            if (ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED) {
                return false
            }
        }
        return true
    }

    fun requestPermissions(
        activity: android.app.Activity,
        permissions: List<String>,
        requestCode: Int
    ) {
        val permissionsArray = permissions.toTypedArray()
        activity.requestPermissions(permissionsArray, requestCode)
    }

    fun handlePermissionResult(
        permissions: Array<String>,
        grantResults: IntArray
    ): Boolean {
        if (grantResults.isEmpty()) return false
        for (result in grantResults) {
            if (result != PackageManager.PERMISSION_GRANTED) {
                return false
            }
        }
        return true
    }

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
            // On Android 12+ location is optional and only needed when the caller
            // explicitly wants it (e.g. to derive location from scan results).
            // Only request it when declared in the manifest, otherwise requesting an
            // undeclared permission would be auto-denied and fail the whole batch.
            if (withAndroidFineLocation &&
                hasPermissionInManifest(context, Manifest.permission.ACCESS_FINE_LOCATION)
            ) {
                permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
            }
        } else {
            permissions.add(Manifest.permission.BLUETOOTH)
            permissions.add(Manifest.permission.BLUETOOTH_ADMIN)
            // On Android 11 and below, ACCESS_FINE_LOCATION is mandatory for BLE scanning.
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        return permissions
    }

    /**
     * Checks whether [permission] is declared in AndroidManifest.xml (via a
     * `<uses-permission>` tag). Used to avoid requesting permissions the app did
     * not declare, which would otherwise be auto-denied and fail the batch.
     */
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

    fun validateRequiredPermissions(context: Context): Boolean {
        val required = getRequiredPermissions(context, forScan = true)
        return hasPermissions(context, required)
    }

    fun getConnectPermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            listOf(Manifest.permission.BLUETOOTH, Manifest.permission.BLUETOOTH_ADMIN)
        }
    }

    fun getScanPermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            listOf(Manifest.permission.BLUETOOTH, Manifest.permission.BLUETOOTH_ADMIN)
        }
    }

    fun getLocationPermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            emptyList()
        } else {
            listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }
}
package com.xraydj.freeclipbuddy

import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import io.flutter.plugin.common.EventChannel

/**
 * Bluetooth LE scan for finding a clip that is NOT connected anymore.
 *
 * No filter on purpose: nobody documented what a disconnected FreeClip 2
 * advertises, so Dart gets everything and decides (see ble_finder.dart).
 * Runs only while the Dart side listens to the EventChannel.
 */
class ClipScanner(context: Context) : EventChannel.StreamHandler {
    private val adapter =
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
    private var sink: EventChannel.EventSink? = null

    private val callback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            sink?.success(toMap(result))
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach { sink?.success(toMap(it)) }
        }

        override fun onScanFailed(errorCode: Int) {
            sink?.error("SCAN_FAILED", "Bluetooth LE scan failed: $errorCode", errorCode)
        }
    }

    @SuppressLint("MissingPermission") // Dart asks for it before listening
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        val scanner = adapter?.bluetoothLeScanner
        if (adapter == null || !adapter.isEnabled || scanner == null) {
            events.error("BT_OFF", "Bluetooth is off", null)
            return
        }
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        try {
            scanner.startScan(null, settings, callback)
        } catch (e: SecurityException) {
            events.error("NO_PERMISSION", e.message, null)
        }
    }

    @SuppressLint("MissingPermission")
    override fun onCancel(arguments: Any?) {
        sink = null
        try {
            adapter?.bluetoothLeScanner?.stopScan(callback)
        } catch (e: SecurityException) {
        } catch (e: IllegalStateException) {
            // Bluetooth went off meanwhile - nothing to stop
        }
    }

    /** Addresses of paired FreeClip 2 (classic MAC), to spot "your" clip */
    @SuppressLint("MissingPermission")
    fun bondedClipAddresses(): List<String> = try {
        adapter?.bondedDevices
            ?.filter { it.name?.contains("FreeClip", ignoreCase = true) == true }
            ?.map { it.address }
            ?: emptyList()
    } catch (e: SecurityException) {
        emptyList()
    }

    @SuppressLint("MissingPermission")
    private fun toMap(r: ScanResult): Map<String, Any?> {
        val record = r.scanRecord
        val manufacturer = HashMap<Int, ByteArray>()
        record?.manufacturerSpecificData?.let { data ->
            for (i in 0 until data.size()) manufacturer[data.keyAt(i)] = data.valueAt(i)
        }
        val serviceData = HashMap<String, ByteArray>()
        record?.serviceData?.forEach { (uuid, bytes) -> serviceData[uuid.toString()] = bytes }
        val name = try {
            record?.deviceName ?: r.device.name
        } catch (e: SecurityException) {
            record?.deviceName
        }
        return mapOf(
            "address" to r.device.address,
            "name" to name,
            "rssi" to r.rssi,
            "manufacturer" to manufacturer,
            "serviceUuids" to (record?.serviceUuids?.map { it.toString() } ?: emptyList()),
            "serviceData" to serviceData,
            "raw" to record?.bytes,
        )
    }

    fun stop() = onCancel(null)
}

package com.smartglass.ai.smartglass_flutter.sdk

import android.bluetooth.BluetoothDevice
import android.util.Log
import com.oudmon.ble.base.bluetooth.IBleListener
import com.oudmon.ble.base.scan.ScanWrapperCallback
import com.oudmon.wifi.GlassesControl
import com.oudmon.wifi.bean.GlassAlbumEntity
import com.oudmon.ble.base.communication.responseImpl.DeviceNotifyListener
import com.oudmon.ble.base.scan.ScanRecord

/**
 * Handles the raw callbacks from the LIB_GLASSES_SDK and translates them into clean GlassesEvents.
 * Exhaustive logging added for debugging Native SDK flows.
 */
class GlassesCallbacks(
    private val onEvent: (GlassesEvent) -> Unit,
    private val onUnexpectedDisconnect: () -> Unit // Trigger for auto-reconnect
) {

    private val TAG = "GlassesCallbacks"
    private var _isConnected = false

    val scanCallback = object : ScanWrapperCallback {
        override fun onStart() { Log.i(TAG, "BLE Scan Started") }
        override fun onStop() { Log.i(TAG, "BLE Scan Stopped") }
        override fun onLeScan(device: BluetoothDevice, rssi: Int, scanRecord: ByteArray) {
            val name = device.name ?: "Unknown Glasses"
            val address = device.address
            Log.d(TAG, "Discovered Device via SDK: $name [$address] (RSSI: $rssi)")
            onEvent(GlassesEvent.DeviceFound(name, address, rssi))
        }
        override fun onScanFailed(errorCode: Int) { Log.e(TAG, "Scan Failed: $errorCode") }
        override fun onParsedData(device: BluetoothDevice, record: ScanRecord) {}
        override fun onBatchScanResults(results: MutableList<android.bluetooth.le.ScanResult>) {}
    }

    val bleListener = object : IBleListener {
        override fun startConnect() { Log.i(TAG, "BLE startConnect") }
        override fun bleGattConnected(p0: BluetoothDevice?) {
            Log.i(TAG, "BLE Connected: ${p0?.address}")
            _isConnected = true
            onEvent(GlassesEvent.ConnectionStateChanged(true, p0?.address ?: ""))
        }
        override fun bleGattDisconnect(p0: BluetoothDevice?) {
            Log.i(TAG, "BLE Disconnected: ${p0?.address}")
            _isConnected = false
            onEvent(GlassesEvent.ConnectionStateChanged(false, p0?.address ?: ""))
            onUnexpectedDisconnect()
        }
        override fun bleServiceDiscovered(p0: Int, p1: String?) {
            Log.i(TAG, "BLE Services Discovered: status=$p0")
            onEvent(GlassesEvent.ServicesDiscovered)
        }
        override fun bleStatus(p0: Int, p1: Int) {}
        override fun bleCharacteristicRead(p0: String?, p1: String?, p2: Int, p3: ByteArray?) {}
        
        override fun bleCharacteristicNotification() {}
        override fun bleCharacteristicWrite(p0: String?, p1: String?, p2: Int, p3: ByteArray?) {}
        override fun bleCharacteristicChanged(p0: String?, p1: String?, p2: ByteArray?) {}
        override fun bleNoCallback() {}
        override fun execute(p0: com.oudmon.ble.base.request.BaseRequest?): Boolean { return false }
        override fun onReadRemoteRssi(p0: android.bluetooth.BluetoothGatt?, p1: Int, p2: Int) {}
        override fun onDescriptorRead(p0: android.bluetooth.BluetoothGatt?, p1: android.bluetooth.BluetoothGattDescriptor?, p2: Int) {}
        override fun onDescriptorWrite(p0: android.bluetooth.BluetoothGatt?, p1: android.bluetooth.BluetoothGattDescriptor?, p2: Int) {}
        override fun isConnected(): Boolean { return _isConnected }
    }

    val wifiDownloadListener = object : GlassesControl.WifiFilesDownloadListener {
        override fun voiceFromGlasses(pcmData: ByteArray) {
            onEvent(GlassesEvent.AudioDataReceived(pcmData))
        }

        override fun fileWasDownloadSuccessfully(entity: GlassAlbumEntity) {
            val path = entity.filePath ?: "Unknown"
            Log.i(TAG, "fileWasDownloadSuccessfully Callback: Saved to \$path")
            onEvent(GlassesEvent.VideoFileDownloaded(path))
        }

        override fun fileDownloadComplete() {
            Log.i(TAG, "fileDownloadComplete Callback: All files synced via WiFi.")
        }

        override fun fileDownloadError(fileType: Int, errorType: Int) {
            Log.e(TAG, "fileDownloadError Callback: type=\$fileType, error=\$errorType")
            onEvent(GlassesEvent.VideoDownloadError("Download error: type \$fileType, error \$errorType"))
        }

        override fun fileProgress(fileName: String, progress: Int) {
            Log.d(TAG, "fileProgress Callback: \$fileName is \$progress% downloaded.")
            onEvent(GlassesEvent.VideoDownloadProgress(progress))
        }

        override fun voiceFromGlassesStatus(status: Int) { Log.d(TAG, "voiceFromGlassesStatus: \$status") }
        override fun recordingToPcm(fileName: String, filePath: String, duration: Int) { Log.i(TAG, "recordingToPcm: \$fileName") }
        override fun recordingToPcmError(fileName: String, errorInfo: String) { Log.e(TAG, "recordingToPcmError: \$errorInfo") }
        override fun eisEnd(fileName: String, filePath: String) { }
        override fun eisError(fileName: String, sourcePath: String, errorInfo: String) { }
        override fun fileCount(index: Int, total: Int) { Log.i(TAG, "fileCount: \$index / \$total") }
        override fun onGlassesControlSuccess() { Log.i(TAG, "onGlassesControlSuccess") }
        override fun onGlassesFail(errorCode: Int) { Log.e(TAG, "onGlassesFail: \$errorCode") }
        override fun wifiSpeed(wifiSpeed: String) { }
    }
    
    val deviceNotifyListener = object : DeviceNotifyListener() {
        override fun onDataResponse(rsp: com.oudmon.ble.base.communication.rsp.DeviceNotifyRsp) {
            Log.i(TAG, "Device Notify Rsp: ${rsp.toString()}")
            try {
                for (field in rsp.javaClass.declaredFields) {
                    field.isAccessible = true
                    Log.i(TAG, "Field: ${field.name} = ${field.get(rsp)}")
                    if (field.name.contains("battery", ignoreCase = true)) {
                        val level = field.get(rsp) as? Int
                        if (level != null) {
                            onEvent(GlassesEvent.BatteryLevel(level))
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing DeviceNotifyRsp: ", e)
            }
        }
    }
}

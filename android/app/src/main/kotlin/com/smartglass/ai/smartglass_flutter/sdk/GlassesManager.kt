package com.smartglass.ai.smartglass_flutter.sdk

import android.app.Application
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.Context
import android.util.Log
import com.oudmon.ble.base.bluetooth.BleBaseControl
import com.oudmon.ble.base.bluetooth.BleOperateManager
import com.oudmon.ble.base.scan.BleScannerHelper
import com.oudmon.ble.base.communication.LargeDataHandler
import com.oudmon.wifi.GlassesControl

/**
 * The core orchestrator for the Glasses SDK.
 * This class abstracts away the raw SDK calls (BleOperateManager, LargeDataHandler, etc.)
 * into simple, clean methods.
 */
class GlassesManager(private val context: Context, private val eventCallback: (GlassesEvent) -> Unit) {

    private val TAG = "GlassesManager"
    private val callbacks = GlassesCallbacks(eventCallback) {
        attemptAutoReconnect()
    }
    private var isInitialized = false
    private var glassesControl: GlassesControl? = null
    
    // Auto-reconnect state
    private var lastConnectedAddress: String? = null
    private var isIntentionalDisconnect = false

    // ==========================================
    // 1. LIFECYCLE & INITIALIZATION
    // ==========================================

    fun initSDK(application: Application) {
        if (isInitialized) return
        
        Log.i(TAG, "Initializing Glasses SDK")
        
        try {
            // 1. Initialize BleOperateManager
            Log.i(TAG, "Setting up BleOperateManager")
            BleOperateManager.getInstance(application).setApplication(application)
            BleOperateManager.getInstance().init()
            
            // 2. Set Context for Base Control and Register listener
            Log.i(TAG, "Setting up BleBaseControl context")
            BleBaseControl.getInstance(context).setmContext(context)
            BleBaseControl.getInstance(context).setListener(callbacks.bleListener)

            // 3. Initialize LargeDataHandler and Listeners
            Log.i(TAG, "Initializing LargeDataHandler singleton")
            LargeDataHandler.getInstance()
            BleOperateManager.getInstance().addOutDeviceListener(100, callbacks.deviceNotifyListener)
            
            // 4. Initialize WiFi / Media downloads
            Log.i(TAG, "Registering WiFi Files Download Listener")
            glassesControl = GlassesControl(application)
            glassesControl?.setWifiDownloadListener(callbacks.wifiDownloadListener)
            
            // 5. Register Bluetooth Bond Receiver
            val filter = android.content.IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            application.registerReceiver(bondReceiver, filter)

            isInitialized = true
            Log.i(TAG, "Glasses SDK initialization COMPLETE")
        } catch (e: Exception) {
            Log.e(TAG, "FATAL ERROR during SDK Initialization", e)
        }
    }

    // ==========================================
    // 2. SCANNING & CONNECTION
    // ==========================================

    private var pendingBondAddress: String? = null

    private val bondReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: android.content.Intent?) {
            if (intent?.action == BluetoothDevice.ACTION_BOND_STATE_CHANGED) {
                val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                val state = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
                
                val deviceAddress = device?.address
                if (deviceAddress != null && pendingBondAddress != null && deviceAddress.equals(pendingBondAddress, ignoreCase = true)) {
                    if (state == BluetoothDevice.BOND_BONDED) {
                        Log.i(TAG, "Bonding complete! Now connecting SDK to: $deviceAddress")
                        pendingBondAddress = null
                        BleOperateManager.getInstance().connectDirectly(deviceAddress)
                    } else if (state == BluetoothDevice.BOND_NONE) {
                        Log.e(TAG, "Bonding failed or rejected for: $deviceAddress")
                        pendingBondAddress = null
                    }
                }
            }
        }
    }

    fun startScan() {
        Log.i(TAG, "Starting BLE Scan via BleScannerHelper")
        BleScannerHelper.getInstance().scanDevice(context, null, callbacks.scanCallback)
    }

    fun stopScan() {
        Log.i(TAG, "Stopping BLE Scan")
        BleScannerHelper.getInstance().stopScan(context)
    }

    fun connect(macAddress: String) {
        Log.i(TAG, "Attempting connection to MAC: $macAddress")
        isIntentionalDisconnect = false
        lastConnectedAddress = macAddress
        
        val adapter = BluetoothAdapter.getDefaultAdapter()
        val device = adapter?.getRemoteDevice(macAddress)
        
        Log.i(TAG, "Device bond state: ${device?.bondState} (BONDED=${BluetoothDevice.BOND_BONDED}, NONE=${BluetoothDevice.BOND_NONE})")
        
        // Stop any ongoing scan first to free up BLE resources for connection
        stopScan()
        
        if (device?.bondState == BluetoothDevice.BOND_NONE) {
            Log.i(TAG, "Device not bonded. Creating bond and waiting for receiver...")
            pendingBondAddress = macAddress
            val success = device?.createBond() ?: false
            if (!success) {
                Log.w(TAG, "OS blocked createBond()! Falling back to connectWithScan() to trigger native GATT pairing.")
                pendingBondAddress = null
                BleOperateManager.getInstance().connectWithScan(macAddress)
            }
        } else {
            Log.i(TAG, "Device already bonded or bonding. Using connectWithScan for robust connection.")
            BleOperateManager.getInstance().connectWithScan(macAddress)
        }
    }
    
    fun attemptAutoReconnect() {
        val address = lastConnectedAddress
        if (address != null && !isIntentionalDisconnect) {
            Log.w(TAG, "Unexpected disconnect. Attempting Auto-Reconnect to: $address")
            // The SDK connectWithScan provides a more robust reconnect when disconnected
            BleOperateManager.getInstance().connectWithScan(address)
        } else {
            Log.i(TAG, "No auto-reconnect needed. Intentional disconnect or no previous device.")
        }
    }

    fun disconnect() {
        Log.i(TAG, "Intentional Disconnect requested")
        val mac = lastConnectedAddress
        isIntentionalDisconnect = true
        lastConnectedAddress = null
        
        // Critical step from docs: disable need reconnect before manual disconnect
        BleBaseControl.getInstance(context).setNeedReconnect(false)
        BleOperateManager.getInstance().disconnect()
        Log.i(TAG, "Disconnect command sent to SDK")

        // Deep disconnect: Unpair from mobile OS entirely
        if (mac != null) {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                val device = adapter?.getRemoteDevice(mac)
                if (device != null && device.bondState == BluetoothDevice.BOND_BONDED) {
                    Log.i(TAG, "Attempting to unpair device (removeBond) via reflection for $mac")
                    val method = device.javaClass.getMethod("removeBond")
                    val result = method.invoke(device) as Boolean
                    Log.i(TAG, "removeBond returned: $result")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error removing bond", e)
            }
        }
    }

    // ==========================================
    // 3. DATA SERVICES (BATTERY, WEAR, ENABLE)
    // ==========================================

    /**
     * Must be called after GlassesEvent.ServicesDiscovered is fired to enable data streaming.
     */
    fun enableDataServices() {
        Log.i(TAG, "Services discovered. Enabling LargeDataHandler data services.")
        LargeDataHandler.getInstance().initEnable()
        
        // According to docs, we also mark it ready here
        BleOperateManager.getInstance().isReady = true
        Log.i(TAG, "SDK marked as READY. Safe to poll battery/wear state now.")
    }
    
    fun syncBattery() {
        if (!BleOperateManager.getInstance().isReady) {
            Log.e(TAG, "Cannot sync battery: SDK is not ready yet.")
            return
        }
        Log.i(TAG, "Requesting Battery Sync")
        LargeDataHandler.getInstance().syncBattery()
    }
    
    fun checkWearState() {
         if (!BleOperateManager.getInstance().isReady) {
            Log.e(TAG, "Cannot check wear state: SDK is not ready yet.")
            return
        }
        Log.i(TAG, "Requesting Wear State Check")
        LargeDataHandler.getInstance().wearCheck(true, true, null) 
    }

    // ==========================================
    // 4. MEDIA COMMANDS (PHOTOS & VIDEO)
    // ==========================================

    fun capturePhoto() {
        Log.i(TAG, "Sending Capture Photo Command (0x02, 0x01, 0x01)")
        LargeDataHandler.getInstance().glassesControl(byteArrayOf(0x02, 0x01, 0x01), null)
    }

    fun captureThumbnail() {
        Log.i(TAG, "Sending Capture Thumbnail Command (64x64) (0x02, 0x01, 0x06, 0x40, 0x40)")
        LargeDataHandler.getInstance().glassesControl(byteArrayOf(0x02, 0x01, 0x06, 0x40, 0x40), null)
    }

    fun startVideoRecording() {
        Log.i(TAG, "Sending Start Video Command (0x02, 0x01, 0x02)")
        LargeDataHandler.getInstance().glassesControl(byteArrayOf(0x02, 0x01, 0x02), null)
    }

    fun stopVideoRecording() {
        Log.i(TAG, "Sending Stop Video Command (0x02, 0x01, 0x03)")
        LargeDataHandler.getInstance().glassesControl(byteArrayOf(0x02, 0x01, 0x03), null)
    }

    fun importVideoAlbum() {
        Log.i(TAG, "Triggering importAlbum() via WiFi GlassesControl")
        glassesControl?.importAlbum()
    }
}

package com.smartglass.ai.smartglass_flutter

import android.widget.Toast
import android.graphics.Rect
import android.graphics.YuvImage
import java.io.ByteArrayOutputStream
import android.graphics.ImageFormat
import android.util.Log as AndroidLog

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.session.DeviceSession
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import com.meta.wearable.dat.core.selectors.SpecificDeviceSelector
import com.meta.wearable.dat.core.types.DeviceIdentifier
import com.meta.wearable.dat.camera.*
import com.meta.wearable.dat.camera.types.*
import com.meta.wearable.dat.mockdevice.MockDeviceKit
import com.meta.wearable.dat.mockdevice.api.MockDeviceKitInterface

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

object Log {
    fun d(tag: String, msg: String) {
        AndroidLog.i(tag, msg)
    }
    fun d(tag: String, msg: String, tr: Throwable) {
        AndroidLog.i(tag, msg, tr)
    }
    fun i(tag: String, msg: String) {
        AndroidLog.i(tag, msg)
    }
    fun i(tag: String, msg: String, tr: Throwable) {
        AndroidLog.i(tag, msg, tr)
    }
    fun e(tag: String, msg: String) {
        AndroidLog.e(tag, msg)
    }
    fun e(tag: String, msg: String, tr: Throwable) {
        AndroidLog.e(tag, msg, tr)
    }
}

class MainActivity : FlutterActivity() {
    private val channelName = "smart_myna/meta_sdk"
    private val streamChannelName = "smart_myna/meta_stream"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val streamMutex = Mutex()
    private var deviceSession: DeviceSession? = null
    private var stream: com.meta.wearable.dat.camera.Stream? = null
    private var streamJob: Job? = null
    private var eventSink: EventChannel.EventSink? = null
    private var mockDeviceKit: MockDeviceKitInterface? = null
    private var useMock = false
    private var targetAddress: String? = null
    private var isMetaDevice = false

    // Cache for discovered Meta SDK devices
    private val sdkMetaDevices = MutableStateFlow<List<Map<String, String>>>(emptyList())
    private val metaSdkReady = MutableStateFlow(false)
    private val metaSdkState = MutableStateFlow("unknown")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // SDK Warm-up: Collect Wearables devices and registration states
        scope.launch {
            try {
                metaSdkReady.value = true
                Wearables.devices.collect { devices ->
                    Log.d("MetaSdk_Native", "Observed Wearables devicesCount=${devices.size}")
                    val mappedDevices = devices.map { device ->
                        Log.d("MetaSdk_Native", "Device discovered identifier=${device.identifier}")
                        mapOf(
                            "name" to "Ray-Ban Meta (${device.identifier})",
                            "address" to device.identifier,
                            "source" to "SDK"
                        )
                    }
                    sdkMetaDevices.value = mappedDevices
                }
            } catch (e: Exception) {
                metaSdkReady.value = false
                Log.e("MetaSdk_Native", "Error collecting Wearables devices", e)
            }
        }

        scope.launch {
            try {
                Wearables.registrationState.collect { regState ->
                    Log.d("MetaSdk_Native", "registrationState=$regState")
                    metaSdkState.value = regState.toString()
                }
            } catch (e: Exception) {
                Log.e("MetaSdk_Native", "Error collecting Wearables registrationState", e)
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, streamChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSdkAvailable" -> {
                        result.success(true)
                    }
                    "getMetaDevices" -> {
                        scope.launch {
                            val devices = queryWearablesDevicesOnce()
                            result.success(devices)
                        }
                    }
                    "connect" -> {
                        val deviceAddress = call.argument<String>("deviceAddress")
                        val useMockArg = call.argument<Boolean>("useMock") ?: false
                        val isMetaArg = call.argument<Boolean>("isMeta") ?: false
                        this.targetAddress = deviceAddress
                        this.useMock = useMockArg
                        this.isMetaDevice = isMetaArg
                        
                        scope.launch {
                            val success = withContext(Dispatchers.IO) {
                                try {
                                    setupSession(deviceAddress, useMockArg, isMetaArg)
                                } catch (e: Exception) {
                                    Log.e("MetaSdk_Native", "connect failed for deviceAddress=$deviceAddress", e)
                                    false
                                }
                            }
                            result.success(success)
                        }
                    }
                    "register" -> {
                        try {
                            Log.d("MetaSdk_Native", "register: currentMetaState=${metaSdkState.value}, ready=${metaSdkReady.value}")
                            Wearables.startRegistration(this)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("MetaSdk_Native", "register failed", e)
                            Toast.makeText(
                                this,
                                "Ensure Developer Mode is ON in Meta View app settings",
                                Toast.LENGTH_LONG
                            ).show()
                            result.success(false)
                        }
                    }
                    "startVideoStream" -> {
                        val useMockArg = call.argument<Boolean>("useMock") ?: this.useMock
                        this.useMock = useMockArg
                        scope.launch {
                            val success = withContext(Dispatchers.IO) {
                                try {
                                    startStreamingFrames()
                                } catch (e: Exception) {
                                    Log.e("MetaSdk_Native", "startVideoStream failed", e)
                                    false
                                }
                            }
                            result.success(success)
                        }
                    }
                    "stopVideoStream" -> {
                        scope.launch {
                            withContext(Dispatchers.IO) {
                                stopStreamingFrames()
                            }
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private suspend fun queryWearablesDevicesOnce(): List<Map<String, String>> = withContext(Dispatchers.IO) {
        try {
            val current = Wearables.devices.first()
            Log.d("MetaSdk_Native", "queryWearablesDevicesOnce: devicesCount=${current.size}")
            current.map { device ->
                mapOf(
                    "name" to "Ray-Ban Meta (${device.identifier})",
                    "address" to device.identifier,
                    "source" to "SDK"
                )
            }
        } catch (e: Exception) {
            Log.e("MetaSdk_Native", "queryWearablesDevicesOnce failed", e)
            sdkMetaDevices.value
        }
    }

    private suspend fun enableMockDeviceIfConfigured() = withContext(Dispatchers.IO) {
        if (mockDeviceKit != null) return@withContext
        try {
            val kit = MockDeviceKit.getInstance(applicationContext)
            mockDeviceKit = kit
            kit.enable()
            val device = kit.pairRaybanMeta()
            device.powerOn()
            device.unfold()
            device.don()
            
            try {
                val servicesMethod = device.javaClass.getMethod("getServices")
                val services = servicesMethod.invoke(device)
                val cameraMethod = services.javaClass.getMethod("getCamera")
                val cameraKit = cameraMethod.invoke(services)
                
                val cameraFacingClass = Class.forName("com.meta.wearable.dat.mockdevice.api.camera.CameraFacing")
                val enumConstants = cameraFacingClass.enumConstants
                if (enumConstants != null && enumConstants.isNotEmpty()) {
                    val frontFacing = enumConstants.firstOrNull { it.toString().contains("FRONT", ignoreCase = true) } ?: enumConstants[0]
                    val setCameraFeedMethod = cameraKit.javaClass.getMethod("setCameraFeed", cameraFacingClass)
                    setCameraFeedMethod.invoke(cameraKit, frontFacing)
                }
            } catch (reflectionEx: Exception) {
                reflectionEx.printStackTrace()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun sessionIsReusable(stateStr: String): Boolean {
        val upper = stateStr.uppercase()
        return upper.contains("STARTED") || 
               upper.contains("STARTING") || 
               upper.contains("CONNECTED") || 
               upper.contains("RUNNING") || 
               upper.contains("ACTIVE")
    }

    private fun isSdkIdentifier(id: String?): Boolean {
        if (id.isNullOrBlank()) return false
        return !isDummyAddress(id)
    }

    private fun isBleMac(id: String?): Boolean {
        if (id.isNullOrBlank()) return false
        return id.contains(":")
    }

    private fun isDummyAddress(id: String?): Boolean {
        if (id.isNullOrBlank()) return false
        return id.contains("meta-rb", ignoreCase = true)
    }

    private fun getSelectorForDevice(deviceAddress: String?): com.meta.wearable.dat.core.selectors.DeviceSelector {
        return when {
            useMock -> {
                Log.d("MetaSdk_Native", "Device Selector: useMock is true -> Using AutoDeviceSelector")
                AutoDeviceSelector()
            }
            isSdkIdentifier(deviceAddress) -> {
                Log.d("MetaSdk_Native", "Device Selector: isSdkIdentifier ($deviceAddress) -> Using SpecificDeviceSelector")
                SpecificDeviceSelector(selectedDevice = DeviceIdentifier(deviceAddress!!))
            }
            else -> {
                Log.d("MetaSdk_Native", "Device Selector: Address is blank/MAC/Dummy ($deviceAddress) -> Using AutoDeviceSelector")
                AutoDeviceSelector()
            }
        }
    }

    private suspend fun waitForMetaReady(timeoutMs: Long = 4000): Boolean = withContext(Dispatchers.IO) {
        val start = System.currentTimeMillis()
        while (System.currentTimeMillis() - start < timeoutMs) {
            if (metaSdkReady.value) {
                return@withContext true
            }
            delay(100)
        }
        false
    }

    private suspend fun setupSession(deviceAddress: String?, useMock: Boolean, isMeta: Boolean): Boolean {
        Log.d("MetaSdk_Native", "setupSession: Address=$deviceAddress, useMock=$useMock, isMeta=$isMeta")
        if (!waitForMetaReady()) {
            Log.e("MetaSdk_Native", "setupSession aborted: Meta SDK not ready yet")
            return false
        }
        if (deviceSession != null) {
            val stateStr = deviceSession!!.state.value.toString()
            Log.d("MetaSdk_Native", "setupSession: Session already exists. Current state: $stateStr")
            if (sessionIsReusable(stateStr)) {
                Log.d("MetaSdk_Native", "setupSession: Session is active. Returning true immediately.")
                return true
            } else {
                Log.d("MetaSdk_Native", "setupSession: Session is stale ($stateStr). Resetting and recreating.")
                try { deviceSession!!.stop() } catch (_: Exception) {}
                deviceSession = null
            }
        }
        if (useMock) {
            enableMockDeviceIfConfigured()
        }
        val selector = getSelectorForDevice(deviceAddress)

        var session: DeviceSession? = null
        var attempts = 0
        while (session == null && attempts < 30) {
            val result = Wearables.createSession(selector)
            session = result.getOrNull()
            if (session == null) {
                Log.d("MetaSdk_Native", "setupSession: Wearables.createSession returned null. Waiting 500ms (attempt $attempts)...")
                delay(500)
                attempts++
            }
        }
        if (session == null) {
            Log.d("MetaSdk_Native", "setupSession failed after 30 attempts.")
            return false
        }
        deviceSession = session
        Log.d("MetaSdk_Native", "setupSession created session: $session. Starting it immediately to secure link lease...")
        
        try {
            session.start()
            var lastStateStr = session.state.value.toString()
            var waitTicks = 0
            while ((lastStateStr.contains("STARTING", ignoreCase = true) ||
                   lastStateStr.contains("IDLE", ignoreCase = true)) &&
                   waitTicks < 80) {
                delay(100)
                lastStateStr = session.state.value.toString()
                waitTicks++
            }
            Log.d("MetaSdk_Native", "setupSession: Session state after wait: $lastStateStr")
            if (!sessionIsReusable(lastStateStr)) {
                Log.d("MetaSdk_Native", "setupSession: Session failed to start ($lastStateStr). Stopping it.")
                try { session.stop() } catch (_: Exception) {}
                deviceSession = null
                return false
            }
        } catch (e: Exception) {
            Log.e("MetaSdk_Native", "setupSession: Exception starting session", e)
            try { session.stop() } catch (_: Exception) {}
            deviceSession = null
            return false
        }

        Log.d("MetaSdk_Native", "setupSession succeeded and session is active.")
        return true
    }

    private suspend fun startStreamingFrames(): Boolean = streamMutex.withLock {
        Log.d("MetaSdk_Native", "startStreamingFrames lock acquired. targetAddress: $targetAddress, useMock: $useMock")
        if (!waitForMetaReady()) {
            Log.e("MetaSdk_Native", "startStreamingFrames aborted: Meta SDK not ready yet")
            return false
        }
        
        // If stream is already running, and session is healthy, return true immediately!
        if (stream != null && streamJob?.isActive == true) {
            val sessionState = deviceSession?.state?.value?.toString() ?: ""
            if (sessionIsReusable(sessionState)) {
                Log.d("MetaSdk_Native", "Stream already running and active. Returning true.")
                return true
            }
        }

        // Clean up any old/stale streams
        streamJob?.cancel()
        streamJob = null
        try { stream?.stop() } catch (_: Exception) {}
        stream = null

        // Clean up stale session if needed
        val currentSession = deviceSession
        if (currentSession != null) {
            val stateStr = currentSession.state.value.toString()
            Log.d("MetaSdk_Native", "startStreamingFrames: Existing session state: $stateStr")
            if (!sessionIsReusable(stateStr)) {
                Log.d("MetaSdk_Native", "startStreamingFrames: Existing session is stale/failed ($stateStr). Stopping and resetting.")
                try { currentSession.stop() } catch (_: Exception) {}
                deviceSession = null
            }
        }

        val deviceAddress = this.targetAddress
        val selector = getSelectorForDevice(deviceAddress)

        var activeStream: com.meta.wearable.dat.camera.Stream? = null
        val maxSessionAttempts = 5
        var activeSession = deviceSession

        for (sessionAttempt in 1..maxSessionAttempts) {
            Log.d("MetaSdk_Native", "Session attempt $sessionAttempt of $maxSessionAttempts")
            if (activeSession == null) {
                Log.d("MetaSdk_Native", "activeSession is null. Creating new session...")
                var attempts = 0
                while (activeSession == null && attempts < 30) {
                    val result = Wearables.createSession(selector)
                    activeSession = result.getOrNull()
                    if (activeSession == null) {
                        Log.d("MetaSdk_Native", "Wearables.createSession returned null. Waiting 500ms (attempt $attempts)...")
                        delay(500)
                        attempts++
                    }
                }
            }
            val session = activeSession ?: run {
                Log.d("MetaSdk_Native", "Failed to create device session after 30 attempts.")
                return false
            }
            deviceSession = session

            try {
                Log.d("MetaSdk_Native", "Starting session... current state: ${session.state.value}")
                val currentState = session.state.value.toString()
                val isAlreadyStarted = sessionIsReusable(currentState)
                if (!isAlreadyStarted) {
                    session.start()
                    
                    var lastStateStr = session.state.value.toString()
                    var waitTicks = 0
                    while ((lastStateStr.contains("STARTING", ignoreCase = true) ||
                           lastStateStr.contains("IDLE", ignoreCase = true)) &&
                           waitTicks < 80) {
                        delay(100)
                        lastStateStr = session.state.value.toString()
                        waitTicks++
                    }
                    
                    Log.d("MetaSdk_Native", "Session state after wait: $lastStateStr")
                    if (!sessionIsReusable(lastStateStr)) {
                        Log.d("MetaSdk_Native", "Session entered failed state ($lastStateStr). Stopping session.")
                        try { session.stop() } catch (_: Exception) {}
                        deviceSession = null
                        activeSession = null
                        if (sessionAttempt < maxSessionAttempts) {
                            Log.d("MetaSdk_Native", "Waiting 2000ms before retrying...")
                            delay(2000)
                        }
                        continue
                    }
                } else {
                    Log.d("MetaSdk_Native", "Session is already active ($currentState). Skipping start().")
                }
                
                Log.d("MetaSdk_Native", "Adding stream configuration...")
                val streamConfig = StreamConfiguration(
                    videoQuality = VideoQuality.MEDIUM,
                    frameRate = 24,
                )
                val streamResult = session.addStream(streamConfig)
                activeStream = streamResult.getOrNull()
                if (activeStream != null) {
                    Log.d("MetaSdk_Native", "Stream added successfully.")
                    break
                } else {
                    val err = streamResult.exceptionOrNull()
                    Log.d("MetaSdk_Native", "Failed to add stream: ${err?.message}")
                }
            } catch (e: Exception) {
                Log.e("MetaSdk_Native", "Exception during session start or stream addition", e)
                try { session.stop() } catch (_: Exception) {}
                deviceSession = null
                activeSession = null
                if (sessionAttempt < maxSessionAttempts) {
                    Log.d("MetaSdk_Native", "Waiting 2000ms before retrying...")
                    delay(2000)
                }
            }
        }

        val streamToStart = activeStream ?: run {
            Log.d("MetaSdk_Native", "Failed to acquire active stream after all attempts.")
            return false
        }
        stream = streamToStart
        Log.d("MetaSdk_Native", "Starting camera stream...")
        streamToStart.start()
        
        streamJob?.cancel()
        streamJob = scope.launch(Dispatchers.IO) {
            try {
                Log.d("MetaSdk_Native", "Stream started. Collecting video stream frames...")
                streamToStart.videoStream.collect { frame: com.meta.wearable.dat.camera.types.VideoFrame ->
                    val rotation = try {
                        frame::class.java.getMethod("getRotation").invoke(frame) as? Int ?: 0
                    } catch (_: Exception) {
                        0
                    }
                    val format = try {
                        frame::class.java.getMethod("getFormat").invoke(frame)?.toString() ?: "NV21"
                    } catch (_: Exception) {
                        "NV21"
                    }
                    
                    val byteBuffer = frame.buffer
                    val bytes = ByteArray(byteBuffer.remaining())
                    byteBuffer.get(bytes)
                    
                    val jpegBytes = processAndCompressFrame(bytes, format, frame.width, frame.height, rotation)
                    if (jpegBytes != null) {
                        runOnUiThread {
                            eventSink?.success(jpegBytes)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("MetaSdk_Native", "Exception in video stream collection", e)
            }
        }
        Log.d("MetaSdk_Native", "startStreamingFrames finished successfully. Stream is running.")
        return true
    }

    private fun processAndCompressFrame(frameBytes: ByteArray, format: String, width: Int, height: Int, rotation: Int): ByteArray? {
        return try {
            val isJpeg = format.contains("JPEG", ignoreCase = true) || format.contains("JPG", ignoreCase = true)
            val jpegBytes = if (isJpeg) {
                frameBytes
            } else {
                val out = ByteArrayOutputStream()
                val yuvImage = YuvImage(frameBytes, ImageFormat.NV21, width, height, null)
                yuvImage.compressToJpeg(Rect(0, 0, width, height), 80, out)
                out.toByteArray()
            }

            if (rotation == 0) {
                return jpegBytes
            }
            val bitmap = android.graphics.BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size) ?: return jpegBytes
            val matrix = android.graphics.Matrix().apply { postRotate(rotation.toFloat()) }
            val rotatedBitmap = android.graphics.Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            val rotatedOut = ByteArrayOutputStream()
            rotatedBitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, rotatedOut)
            bitmap.recycle()
            rotatedBitmap.recycle()
            rotatedOut.toByteArray()
        } catch (e: Exception) {
            Log.e("MetaSdk_Native", "Error processing frame: ${e.message}", e)
            null
        }
    }

    private fun stopStreamingFrames() {
        Log.d("MetaSdk_Native", "stopStreamingFrames called.")
        streamJob?.cancel()
        streamJob = null
        try {
            stream?.stop()
        } catch (e: Exception) {
            Log.d("MetaSdk_Native", "Error stopping stream: ${e.message}")
        }
        stream = null
        try {
            deviceSession?.stop()
        } catch (e: Exception) {
            Log.d("MetaSdk_Native", "Error stopping session: ${e.message}")
        }
        deviceSession = null
        disableMockDevice()
    }

    private fun disableMockDevice() {
        try {
            mockDeviceKit?.disable()
        } catch (_: Exception) {}
        mockDeviceKit = null
    }

    override fun onDestroy() {
        stopStreamingFrames()
        super.onDestroy()
    }
}

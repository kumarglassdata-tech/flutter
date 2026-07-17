package com.smartglass.ai.smartglass_flutter

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.smartglass.ai.smartglass_flutter.sdk.GlassesManager
import com.smartglass.ai.smartglass_flutter.sdk.GlassesEvent

class MainActivity : FlutterActivity() {
    private val TAG = "SmartMyna_Native"
    private val COMMAND_CHANNEL = "smart_myna/glasses_commands"
    private val EVENT_CHANNEL = "smart_myna/glasses_events"

    private lateinit var glassesManager: GlassesManager
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        glassesManager = GlassesManager(this) { event ->
            // Forward events from the SDK Wrapper to Flutter via EventChannel
            mainHandler.post {
                eventSink?.success(eventToMap(event))
            }
        }
        
        // Defer SDK initialization slightly to allow the Flutter UI to render the splash screen first.
        // We run this on the main thread (via handler) because the BleOperateManager may require a Looper.
        mainHandler.postDelayed({
            glassesManager.initSDK(this.application)
        }, 1500)
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            glassesManager.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "Error disconnecting on destroy", e)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup EventChannel to stream data to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // Setup MethodChannel to receive commands from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COMMAND_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "startScan" -> {
                            glassesManager.startScan()
                            result.success(true)
                        }
                        "stopScan" -> {
                            glassesManager.stopScan()
                            result.success(true)
                        }
                        "connect" -> {
                            val mac = call.argument<String>("macAddress")
                            if (mac != null) {
                                glassesManager.connect(mac)
                                result.success(true)
                            } else {
                                result.error("INVALID_ARGS", "MAC address required", null)
                            }
                        }
                        "disconnect" -> {
                            glassesManager.disconnect()
                            result.success(true)
                        }
                        "setVolume" -> {
                            val level = call.argument<Double>("level")
                            if (level != null) {
                                val audioManager = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
                                val maxVolume = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
                                val volume = (maxVolume * level).toInt()
                                audioManager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, volume, 0)
                                result.success(true)
                            } else {
                                result.error("INVALID_ARGS", "Level required", null)
                            }
                        }
                        "enableDataServices" -> {
                            glassesManager.enableDataServices()
                            result.success(true)
                        }
                        "syncBattery" -> {
                            glassesManager.syncBattery()
                            result.success(true)
                        }
                        "checkWearState" -> {
                            glassesManager.checkWearState()
                            result.success(true)
                        }
                        "capturePhoto" -> {
                            glassesManager.capturePhoto()
                            result.success(true)
                        }
                        "captureThumbnail" -> {
                            glassesManager.captureThumbnail()
                            result.success(true)
                        }
                        "startVideoRecording" -> {
                            glassesManager.startVideoRecording()
                            result.success(true)
                        }
                        "stopVideoRecording" -> {
                            glassesManager.stopVideoRecording()
                            result.success(true)
                        }
                        "importVideoAlbum" -> {
                            glassesManager.importVideoAlbum()
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error executing command: \${call.method}", e)
                    result.error("COMMAND_ERROR", e.message, null)
                }
            }
    }

    /**
     * Converts Kotlin Sealed Classes into standard Maps that Flutter can decode
     */
    private fun eventToMap(event: GlassesEvent): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        when (event) {
            is GlassesEvent.DeviceFound -> {
                map["type"] = "DeviceFound"
                map["name"] = event.name
                map["address"] = event.address
                map["rssi"] = event.rssi
            }
            is GlassesEvent.ConnectionStateChanged -> {
                map["type"] = "ConnectionStateChanged"
                map["isConnected"] = event.isConnected
                map["address"] = event.address
            }
            is GlassesEvent.ServicesDiscovered -> {
                map["type"] = "ServicesDiscovered"
            }
            is GlassesEvent.BatteryLevel -> {
                map["type"] = "BatteryLevel"
                map["level"] = event.level
            }
            is GlassesEvent.WearStateChanged -> {
                map["type"] = "WearStateChanged"
                map["isWearing"] = event.isWearing
            }
            is GlassesEvent.PhotoChunkReceived -> {
                map["type"] = "PhotoChunkReceived"
                map["bytes"] = event.bytes
            }
            is GlassesEvent.AudioDataReceived -> {
                map["type"] = "AudioDataReceived"
                map["pcmData"] = event.pcmData
            }
            is GlassesEvent.VideoFileDownloaded -> {
                map["type"] = "VideoFileDownloaded"
                map["filePath"] = event.filePath
            }
            is GlassesEvent.VideoDownloadProgress -> {
                map["type"] = "VideoDownloadProgress"
                map["progress"] = event.progress
            }
            is GlassesEvent.VideoDownloadError -> {
                map["type"] = "VideoDownloadError"
                map["error"] = event.error
            }
        }
        return map
    }
}

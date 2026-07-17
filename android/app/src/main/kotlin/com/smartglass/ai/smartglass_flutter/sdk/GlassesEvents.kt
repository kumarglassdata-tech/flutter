package com.smartglass.ai.smartglass_flutter.sdk

/**
 * Clean data classes to represent events coming from the Glasses SDK.
 * This prevents raw SDK objects from leaking into our Flutter channel bridge.
 */

sealed class GlassesEvent {
    // Connection & Scan Events
    data class DeviceFound(val name: String, val address: String, val rssi: Int) : GlassesEvent()
    data class ConnectionStateChanged(val isConnected: Boolean, val address: String) : GlassesEvent()
    object ServicesDiscovered : GlassesEvent()
    
    // Hardware State
    data class BatteryLevel(val level: Int) : GlassesEvent()
    data class WearStateChanged(val isWearing: Boolean) : GlassesEvent()
    
    // Media & Sensor Streams
    data class PhotoChunkReceived(val bytes: ByteArray) : GlassesEvent()
    data class AudioDataReceived(val pcmData: ByteArray) : GlassesEvent()
    
    // WiFi / Video Import
    data class VideoFileDownloaded(val filePath: String) : GlassesEvent()
    data class VideoDownloadProgress(val progress: Int) : GlassesEvent()
    data class VideoDownloadError(val error: String) : GlassesEvent()
}

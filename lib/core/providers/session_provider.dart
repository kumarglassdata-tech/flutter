import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

import 'package:smartglass_flutter/core/services/camera_service.dart';
import 'package:smartglass_flutter/core/services/meta_glasses_sdk_service.dart';
import 'package:smartglass_flutter/core/services/audio_service.dart';
import 'package:smartglass_flutter/core/services/location_service.dart';

// Import New Production Architecture
import 'package:smartglass_flutter/core/sources/source_adapter.dart';
import 'package:smartglass_flutter/core/sources/source_manager.dart';
import 'package:smartglass_flutter/core/sources/meta/meta_source_adapter.dart';
import 'package:smartglass_flutter/core/sources/phone/phone_source_adapter.dart';
import 'package:smartglass_flutter/core/sources/laptop/laptop_source_adapter.dart';
import 'package:smartglass_flutter/core/sources/mock/mock_source_adapter.dart';
import 'package:smartglass_flutter/core/sources/video_upload/video_upload_source_adapter.dart';
import 'package:smartglass_flutter/core/models/engine_status.dart';
import 'package:smartglass_flutter/core/engines/shared/engine_registry.dart';

import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/engines/context/context_client.dart';
import 'package:smartglass_flutter/core/engines/behavior/behavior_client.dart';
import 'package:smartglass_flutter/core/engines/interaction/interaction_client.dart';
import 'package:smartglass_flutter/core/engines/ecom/ecom_client.dart';
import 'package:smartglass_flutter/core/engines/memory/memory_client.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';
import 'package:smartglass_flutter/core/network/audio_client.dart' as smartglass_audio_client;

import 'package:smartglass_flutter/core/orchestrator/pipeline_coordinator.dart';
import 'package:smartglass_flutter/core/orchestrator/stream_coordinator.dart';
import 'package:smartglass_flutter/core/diagnostics/telemetry_service.dart';
import 'package:smartglass_flutter/core/diagnostics/health_monitor.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ---------------------------------------------------------------------------
// Models (Maintained for Backwards Compatibility)
// ---------------------------------------------------------------------------

enum EngineState { idle, starting, running, stopping, failed }

enum GlassesConnectionState { disconnected, scanning, connecting, connected }

enum DeviceLinkType { ble, classicBt, wifi, metaDat }

class GlassesDevice {
  final String name;
  final String address;
  final bool isBonded;
  final int rssi;
  final DeviceLinkType linkType;

  const GlassesDevice({
    required this.name,
    required this.address,
    this.isBonded = false,
    this.rssi = 0,
    this.linkType = DeviceLinkType.ble,
  });
}

class AIResult {
  final String label;
  final double confidence;
  const AIResult({required this.label, required this.confidence});
}

class SessionState {
  final bool isSessionActive;
  final bool isDegraded;
  final EngineState glassesState;
  final EngineState mediaState;
  final EngineState aiState;
  final double mediaFps;
  final double aiThroughputFps;
  final double aiLatencyMs;
  final int rttMs;
  final int bleRssi;
  final String? connectedDeviceName;
  final GlassesConnectionState bleConnectionState;
  final List<GlassesDevice> discoveredDevices;
  final List<String> eventLogs;
  final String? lastHealthMessage;
  final int framesEmitted;
  final int framesDropped;
  final int aiFramesSkipped;
  final AIResult? lastAiResult;
  final Map<String, double> modelOutputs;
  final Map<String, dynamic>? modelContext;
  final double audioLevel;
  final double? latitude;
  final double? longitude;
  final bool metaSdkAvailable;
  final bool usingRealMetaStream;
  final Uint8List? metaFrameBytes;
  final ContextEngineOutput? lastContextOutput;
  final BIEFrame? lastBIEFrame;
  final InteractionResponse? lastInteractionResponse;
  final EcomAdResponse? lastEcomResponse;
  final MemoryResponse? lastMemoryResponse;
  final List<String> topSalientObjects;
  final List<EcomAdProduct> suggestedProducts;
  final Map<String, EngineStatus> engineStatuses;
  final List<ApiHealth> apiHealths;

  const SessionState({
    this.isSessionActive = false,
    this.isDegraded = false,
    this.glassesState = EngineState.idle,
    this.mediaState = EngineState.idle,
    this.aiState = EngineState.idle,
    this.mediaFps = 0.0,
    this.aiThroughputFps = 0.0,
    this.aiLatencyMs = 0.0,
    this.rttMs = 0,
    this.bleRssi = 0,
    this.connectedDeviceName,
    this.bleConnectionState = GlassesConnectionState.disconnected,
    this.discoveredDevices = const [],
    this.eventLogs = const [],
    this.lastHealthMessage,
    this.framesEmitted = 0,
    this.framesDropped = 0,
    this.aiFramesSkipped = 0,
    this.lastAiResult,
    this.modelOutputs = const {},
    this.modelContext,
    this.audioLevel = 0.0,
    this.latitude,
    this.longitude,
    this.metaSdkAvailable = false,
    this.usingRealMetaStream = false,
    this.metaFrameBytes,
    this.lastContextOutput,
    this.lastBIEFrame,
    this.lastInteractionResponse,
    this.lastEcomResponse,
    this.lastMemoryResponse,
    this.topSalientObjects = const [],
    this.suggestedProducts = const [],
    this.engineStatuses = const {},
    this.apiHealths = const [],
  });

  SessionState copyWith({
    bool? isSessionActive,
    bool? isDegraded,
    EngineState? glassesState,
    EngineState? mediaState,
    EngineState? aiState,
    double? mediaFps,
    double? aiThroughputFps,
    double? aiLatencyMs,
    int? rttMs,
    int? bleRssi,
    String? connectedDeviceName,
    GlassesConnectionState? bleConnectionState,
    List<GlassesDevice>? discoveredDevices,
    List<String>? eventLogs,
    int? framesEmitted,
    int? framesDropped,
    int? aiFramesSkipped,
    AIResult? lastAiResult,
    Map<String, double>? modelOutputs,
    Map<String, dynamic>? modelContext,
    double? audioLevel,
    double? latitude,
    double? longitude,
    String? lastHealthMessage,
    bool? metaSdkAvailable,
    bool? usingRealMetaStream,
    Uint8List? metaFrameBytes,
    ContextEngineOutput? lastContextOutput,
    BIEFrame? lastBIEFrame,
    InteractionResponse? lastInteractionResponse,
    EcomAdResponse? lastEcomResponse,
    MemoryResponse? lastMemoryResponse,
    List<String>? topSalientObjects,
    List<EcomAdProduct>? suggestedProducts,
    Map<String, EngineStatus>? engineStatuses,
    List<ApiHealth>? apiHealths,
  }) {
    return SessionState(
      isSessionActive: isSessionActive ?? this.isSessionActive,
      isDegraded: isDegraded ?? this.isDegraded,
      glassesState: glassesState ?? this.glassesState,
      mediaState: mediaState ?? this.mediaState,
      aiState: aiState ?? this.aiState,
      mediaFps: mediaFps ?? this.mediaFps,
      aiThroughputFps: aiThroughputFps ?? this.aiThroughputFps,
      aiLatencyMs: aiLatencyMs ?? this.aiLatencyMs,
      rttMs: rttMs ?? this.rttMs,
      bleRssi: bleRssi ?? this.bleRssi,
      connectedDeviceName: connectedDeviceName ?? this.connectedDeviceName,
      bleConnectionState: bleConnectionState ?? this.bleConnectionState,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      eventLogs: eventLogs ?? this.eventLogs,
      framesEmitted: framesEmitted ?? this.framesEmitted,
      framesDropped: framesDropped ?? this.framesDropped,
      aiFramesSkipped: aiFramesSkipped ?? this.aiFramesSkipped,
      lastAiResult: lastAiResult ?? this.lastAiResult,
      modelOutputs: modelOutputs ?? this.modelOutputs,
      modelContext: modelContext ?? this.modelContext,
      audioLevel: audioLevel ?? this.audioLevel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastHealthMessage: lastHealthMessage ?? this.lastHealthMessage,
      metaSdkAvailable: metaSdkAvailable ?? this.metaSdkAvailable,
      usingRealMetaStream: usingRealMetaStream ?? this.usingRealMetaStream,
      metaFrameBytes: metaFrameBytes ?? this.metaFrameBytes,
      lastContextOutput: lastContextOutput ?? this.lastContextOutput,
      lastBIEFrame: lastBIEFrame ?? this.lastBIEFrame,
      lastInteractionResponse: lastInteractionResponse ?? this.lastInteractionResponse,
      lastEcomResponse: lastEcomResponse ?? this.lastEcomResponse,
      lastMemoryResponse: lastMemoryResponse ?? this.lastMemoryResponse,
      topSalientObjects: topSalientObjects ?? this.topSalientObjects,
      suggestedProducts: suggestedProducts ?? this.suggestedProducts,
      engineStatuses: engineStatuses ?? this.engineStatuses,
      apiHealths: apiHealths ?? this.apiHealths,
    );
  }
}

// ---------------------------------------------------------------------------
// SessionProvider
// ---------------------------------------------------------------------------

class SessionProvider extends ChangeNotifier {
  final CameraService _cameraService;
  final MetaGlassesSdkService _metaSdkService;
  final AudioService _audioService;
  final LocationService _locationService;

  SessionState _state = const SessionState();
  String _scanStatus = 'Ready to scan';
  bool _isConnecting = false;
  bool _isStartingRuntime = false;
  late final VideoUploadSourceAdapter _videoUploadAdapter;
  Timer? _healthProbeTimer;

  // New Architecture Entities
  late final SourceManager sourceManager;
  late final TelemetryService telemetryService;
  late final PipelineCoordinator pipelineCoordinator;
  late final StreamCoordinator streamCoordinator;
  late final HealthMonitor healthMonitor;
  final FlutterTts flutterTts = FlutterTts()
  ..setVolume(1.0)
  ..setSpeechRate(0.5)
  ..setPitch(1.0);

  bool get isConnecting => _isConnecting;
  bool get isStartingRuntime => _isStartingRuntime;

  static const _registeredMetaName = 'RB Meta019G';
  static const _registeredMetaAddress = 'meta-rb-019g';

  SessionProvider(
    this._cameraService, {
    MetaGlassesSdkService? metaSdkService,
    AudioService? audioService,
    LocationService? locationService,
  })  : _metaSdkService = metaSdkService ?? const MetaGlassesSdkService(),
        _audioService = audioService ?? AudioService(),
        _locationService = locationService ?? LocationService() {
    _cameraService.addListener(_syncNewArchitecture);
    _audioService.addListener(_syncNewArchitecture);
    _locationService.addListener(_syncNewArchitecture);

    _initNewArchitecture();
  }

  void _initNewArchitecture() {
    // 1. Initialize Adapters
    final mockAdapter = MockSourceAdapter();
    final metaAdapter = MetaSourceAdapter(
      metaSdk: _metaSdkService,
      audio: _audioService,
      location: _locationService,
    );
    final phoneAdapter = PhoneSourceAdapter(
      camera: _cameraService,
      audio: _audioService,
      location: _locationService,
    );
    final laptopAdapter = LaptopSourceAdapter();
    _videoUploadAdapter = VideoUploadSourceAdapter(
      audio: _audioService,
      location: _locationService,
    );

    sourceManager = SourceManager({
      SourceType.mock: mockAdapter,
      SourceType.meta: metaAdapter,
      SourceType.phone: phoneAdapter,
      SourceType.laptop: laptopAdapter,
      SourceType.videoUpload: _videoUploadAdapter,
    });

    // 2. Initialize Clients & Telemetry
    telemetryService = TelemetryService();

    final contextClient = ContextClient(fallbackToMock: false);
    final behaviorClient = BehaviorClient(fallbackToMock: false);
    final interactionClient = InteractionClient(fallbackToMock: false);
    final ecomClient = EcomClient(fallbackToMock: false);
    final memoryClient = MemoryClient(fallbackToMock: false);

    pipelineCoordinator = PipelineCoordinator(
      contextClient: contextClient,
      behaviorClient: behaviorClient,
      interactionClient: interactionClient,
      ecomClient: ecomClient,
      memoryClient: memoryClient,
      telemetryService: telemetryService,
    );

    streamCoordinator = StreamCoordinator(
      sourceManager: sourceManager,
      pipelineCoordinator: pipelineCoordinator,
      telemetryService: telemetryService,
    );

    healthMonitor = HealthMonitor(
      contextClient: contextClient,
      behaviorClient: behaviorClient,
      interactionClient: interactionClient,
      ecomClient: ecomClient,
      memoryClient: memoryClient,
      sourceManager: sourceManager,
    );

    // 3. Set up listeners to propagate changes to UI
    sourceManager.addListener(_syncNewArchitecture);
    streamCoordinator.addListener(_syncNewArchitecture);
    healthMonitor.addListener(_syncNewArchitecture);
    telemetryService.addListener(_syncNewArchitecture);

    // Start health monitor
    healthMonitor.start();
    _startHealthProbes();
    _syncNewArchitecture();
  }

  SessionState get state => _state;
  String get scanStatus => _scanStatus;
  CameraService get cameraService => _cameraService;

  Future<void> startDiscovery() async {
    _scanStatus = 'Scanning nearby devices…';
    notifyListeners();

    final sdkAvailable = await _metaSdkService.isSdkAvailable();
    _state = _state.copyWith(
      bleConnectionState: GlassesConnectionState.scanning,
      metaSdkAvailable: sdkAvailable,
    );
    notifyListeners();

    // Query native Meta SDK devices
    final sdkMetaDevices = <GlassesDevice>[];
    if (sdkAvailable) {
      try {
        final sdkDevices = await _metaSdkService.getMetaDevices();
        for (final d in sdkDevices) {
          final address = d['address'] ?? '';
          final name = d['name'] ?? 'Ray-Ban Meta';
          if (address.isNotEmpty) {
            sdkMetaDevices.add(GlassesDevice(
              name: name,
              address: address,
              isBonded: true,
              rssi: -52,
              linkType: DeviceLinkType.metaDat,
            ));
          }
        }
      } catch (e) {
        _addLog('Error querying Meta SDK devices: $e');
      }
    }

    final retained = <GlassesDevice>[];
    for (final device in _state.discoveredDevices) {
      if (device.name == _state.connectedDeviceName && _state.bleConnectionState == GlassesConnectionState.connected) {
        retained.add(device);
      }
    }

    final baseMetaDevices = <GlassesDevice>[];
    baseMetaDevices.addAll(retained);
    baseMetaDevices.addAll(sdkMetaDevices);

    final hasMeta = baseMetaDevices.any((d) => d.address == _registeredMetaAddress || d.name == _registeredMetaName || d.name.contains('Meta') || d.name.contains('RB'));
    if (!hasMeta && sdkAvailable && _metaSdkService.supportsNativeSdk) {
      baseMetaDevices.add(const GlassesDevice(
        name: _registeredMetaName,
        address: _registeredMetaAddress,
        isBonded: true,
        rssi: -55,
        linkType: DeviceLinkType.metaDat,
      ));
    }

    final rawBle = await _scanBluetoothDevices();
    final wifi = await _scanWifiDevices();

    final normalized = <String, GlassesDevice>{};
    for (final dev in wifi) {
      normalized[dev.address] = dev;
    }
    for (final dev in baseMetaDevices) {
      normalized[dev.address] = dev;
    }

    for (final dev in rawBle) {
      final isBleMeta = dev.name.contains('Meta') || dev.name.contains('RB') || dev.name.contains('Ray-Ban');
      if (isBleMeta && sdkAvailable) {
        continue;
      }
      if (!normalized.containsKey(dev.address)) {
        normalized[dev.address] = dev;
      }
    }

    _state = _state.copyWith(
      discoveredDevices: normalized.values.toList(),
      bleConnectionState: GlassesConnectionState.disconnected,
    );

    if (!sdkAvailable) {
      _scanStatus = 'Scan complete. Meta SDK is unavailable on this device.';
    } else if (sdkMetaDevices.isEmpty) {
      _scanStatus = 'No Meta SDK devices discovered. Open Meta View app and ensure glasses are paired.';
    } else {
      _scanStatus = 'Found ${sdkMetaDevices.length} registered Meta SDK device(s) and ${normalized.length - sdkMetaDevices.length} other devices.';
    }
    _addLog(_scanStatus);
    notifyListeners();
  }

  Future<List<GlassesDevice>> _scanBluetoothDevices() async {
    if (kIsWeb) return const [];
    try {
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await Permission.locationWhenInUse.request();
      }

      final discovered = <String, GlassesDevice>{};
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final id = result.device.remoteId.str;
          final name = result.device.platformName.trim().isNotEmpty
              ? result.device.platformName.trim()
              : (result.advertisementData.advName.trim().isNotEmpty
                  ? result.advertisementData.advName.trim()
                  : 'BLE Device');
          discovered[id] = GlassesDevice(
            name: name,
            address: id,
            rssi: result.rssi,
            linkType: DeviceLinkType.ble,
          );
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      await Future.delayed(const Duration(seconds: 5));
      await subscription.cancel();
      return discovered.values.toList();
    } catch (error) {
      _addLog('BLE scan failed: $error');
      return const [];
    }
  }

  Future<List<GlassesDevice>> _scanWifiDevices() async {
    try {
      WiFiScan.instance.startScan();
      await Future.delayed(const Duration(seconds: 4));
      final accessPoints = await WiFiScan.instance.getScannedResults();
      return accessPoints
          .map(
            (ap) => GlassesDevice(
              name: ap.ssid.trim().isNotEmpty ? ap.ssid.trim() : ap.bssid.trim(),
              address: ap.bssid.trim().isNotEmpty ? ap.bssid.trim() : ap.ssid.trim(),
              rssi: ap.level,
              linkType: DeviceLinkType.wifi,
            ),
          )
          .toList();
    } catch (error) {
      _addLog('Wi-Fi scan fallback: $error');
      final fallback = await _currentWifiNetwork();
      return fallback == null ? const [] : [fallback];
    }
  }

  Future<GlassesDevice?> _currentWifiNetwork() async {
    try {
      final info = NetworkInfo();
      final ssid = await info.getWifiName();
      final bssid = await info.getWifiBSSID();
      final ip = await info.getWifiIP();
      final name = (ssid ?? '').replaceAll('"', '').trim();
      final address = (bssid ?? ip ?? 'wifi-current').trim();
      if (name.isEmpty && address == 'wifi-current') {
        return null;
      }
      return GlassesDevice(
        name: name.isEmpty ? 'Current Wi-Fi' : name,
        address: address,
        rssi: -50,
        linkType: DeviceLinkType.wifi,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> connectToDevice(String address, {bool useMock = false}) async {
    if (_isConnecting) return;
    _isConnecting = true;
    notifyListeners();

    try {
      final device = _state.discoveredDevices.where((d) => d.address == address).firstOrNull;
      _state = _state.copyWith(
        bleConnectionState: GlassesConnectionState.connecting,
        connectedDeviceName: device?.name,
      );
      _addLog('Connecting to ${device?.name ?? address}…');
      notifyListeners();

      final targetName = device?.name ?? '';
      final isMetaTarget = targetName.contains('RB') || targetName.contains('Meta') || address.contains('meta');

      if (isMetaTarget) {
        await sourceManager.switchSource(useMock ? SourceType.mock : SourceType.meta);
      } else {
        await sourceManager.switchSource(SourceType.phone);
      }

      await Future.delayed(const Duration(seconds: 1));
      _state = _state.copyWith(
        bleConnectionState: GlassesConnectionState.connected,
        glassesState: EngineState.running,
      );
      _addLog('Connected to ${device?.name ?? address}');
    } catch (e) {
      _addLog('Connection failed: $e');
      _state = _state.copyWith(
        bleConnectionState: GlassesConnectionState.disconnected,
        glassesState: EngineState.failed,
      );
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> connectToMetaGlasses({bool useMock = false}) async {
    await sourceManager.switchSource(useMock ? SourceType.mock : SourceType.meta);
    _state = _state.copyWith(
      bleConnectionState: GlassesConnectionState.connected,
      glassesState: EngineState.running,
      connectedDeviceName: useMock ? 'MOCK GLASSES' : 'RB META GLASSES',
    );
    _addLog('Connected to Meta glasses');
    notifyListeners();
  }

  Future<GlassesDevice> registerMetaGlasses() async {
    _addLog('Meta registration complete.');
    return const GlassesDevice(
      name: _registeredMetaName,
      address: _registeredMetaAddress,
      isBonded: true,
      rssi: -55,
      linkType: DeviceLinkType.metaDat,
    );
  }

  Future<void> startRuntime({bool useMock = false}) async {
    if (_isStartingRuntime) return;
    _isStartingRuntime = true;
    notifyListeners();

    try {
      _addLog('Starting real-time stream coordinator...');
      if (useMock) {
        await sourceManager.switchSource(SourceType.mock);
      } else if (sourceManager.activeType == SourceType.meta) {
        await sourceManager.switchSource(SourceType.meta);
      } else if (sourceManager.activeType == SourceType.videoUpload) {
        // Keep active source as video upload
      } else if (sourceManager.activeType == SourceType.laptop) {
        // Keep active source as laptop
      } else {
        await sourceManager.switchSource(SourceType.phone);
      }

      streamCoordinator.start();
      _addLog('Real-time ingestion pipeline running.');

      // Start continuous audio processing loop
      _startAudioProcessingLoop();
    } catch (e) {
      _addLog('Stream Coordinator start failed: $e');
    } finally {
      _isStartingRuntime = false;
      notifyListeners();
    }
  }

  bool _isAudioLoopRunning = false;

  void _startAudioProcessingLoop() async {
    if (_isAudioLoopRunning) return;
    _isAudioLoopRunning = true;
    _audioService.start();

    DateTime? lastVoiceTime;
    DateTime chunkStartTime = DateTime.now();

    while (_isAudioLoopRunning) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!_isAudioLoopRunning) break;

      final level = _audioService.level;
      if (level > 0.1) {
        lastVoiceTime = DateTime.now();
      }

      final now = DateTime.now();
      final silenceDuration = lastVoiceTime != null ? now.difference(lastVoiceTime).inMilliseconds : 0;
      final chunkDuration = now.difference(chunkStartTime).inMilliseconds;

      // Send chunk if there is 1.5s of silence after speaking, OR if chunk reaches 5 seconds
      if ((lastVoiceTime != null && silenceDuration > 1500) || chunkDuration > 5000) {
        final wavBytes = await _audioService.stopAndGetBytes();
        if (wavBytes != null && wavBytes.isNotEmpty && lastVoiceTime != null) {
          _sendAudioChunk(wavBytes);
        }
        lastVoiceTime = null;
        chunkStartTime = DateTime.now();
        
        if (_isAudioLoopRunning) {
          await _audioService.start(); // Restart recording
        }
      }
    }
  }

  Future<void> _sendAudioChunk(Uint8List bytes) async {
    try {
      final bieFrame = _state.lastBIEFrame;
      if (bieFrame == null) {
        _addLog('No behavior frame available for audio processing');
        return;
      }
      
      final payload = Map<String, dynamic>.from(bieFrame.raw);
      payload['audio_base64'] = base64Encode(bytes);
      
      var baseUrl = EngineRegistry.interactionSubUrl;
      // If baseUrl already includes /process, replace it
      if (baseUrl.endsWith('/process')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - '/process'.length);
      }
      if (!baseUrl.endsWith('/')) baseUrl += '/';
      final url = Uri.parse('${baseUrl}process_audio');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _addLog('Audio sent successfully.');
        
        final interactionResponse = InteractionResponse.fromJson(data);
        final utterance = interactionResponse.lastUtterance;
        
        // Also update the session state with the latest interaction response so the E-com handler has access to the updated BCP!
        _state = _state.copyWith(lastInteractionResponse: interactionResponse);
        
        // Force update lastBIEFrame so the E-com UI and pipeline can see the new salience score
        final bcpJson = data['bcp'] ?? <String, dynamic>{};
        if (bcpJson.isNotEmpty) {
          final audioBieFrame = BIEFrame.fromJson(bcpJson);
          _state = _state.copyWith(lastBIEFrame: audioBieFrame);
          
          if (audioBieFrame.salienceScore >= 0.5) {
            _addLog('Audio intent triggered Ecom. Salience: \${audioBieFrame.salienceScore}');
            final sharedState = <String, dynamic>{};
            final ecomRes = await pipelineCoordinator.ecomStep.execute(audioBieFrame, sharedState);
            if (ecomRes.isSuccess && ecomRes.output != null) {
               _state = _state.copyWith(
                 lastEcomResponse: ecomRes.output,
                 suggestedProducts: ecomRes.output!.suggestions,
               );
            }
          }
        }
        
        notifyListeners();
        
        if (utterance.isNotEmpty) {
          await flutterTts.speak(utterance);
        }
      } else {
        throw Exception('Audio server error: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _addLog('Failed to send audio chunk: $e');
    }
  }

  Future<void> stopRuntime() async {
    _addLog('Stopping real-time stream coordinator...');
    _isAudioLoopRunning = false;
    await _audioService.stop();
    streamCoordinator.stop();
    _state = _state.copyWith(
      isSessionActive: false,
      mediaState: EngineState.idle,
      aiState: EngineState.idle,
      glassesState: EngineState.idle,
      bleConnectionState: GlassesConnectionState.disconnected,
      connectedDeviceName: null,
      mediaFps: 0,
      aiThroughputFps: 0,
      aiLatencyMs: 0,
    );
    notifyListeners();
  }



  void setUploadedFile(Uint8List bytes, String name, bool isImage) {
    _videoUploadAdapter.setUploadedFile(bytes, name, isImage);
    notifyListeners();
  }

  void _startHealthProbes() {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    _healthProbeTimer?.cancel();
    _healthProbeTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _runHealthProbes();
    });
    _runHealthProbes();
  }

  Future<void> _runHealthProbes() async {
    final List<ApiHealth> updatedHealths = [];

    final engines = [
      ('Context Engine', 'context'),
      ('Behavior Intent', 'behavior'),
      ('Interaction Subsystem', 'interaction'),
      ('E-commerce Handler', 'ecom'),
      ('Safety Memory Service', 'memory'),
    ];

    for (final (name, key) in engines) {
      final urlStr = EngineRegistry.getEngineUrl(key);
      final endpoint = Uri.parse(urlStr);
      final circuitState = _getCircuitState(key);

      final stopwatch = Stopwatch()..start();
      bool reachable = false;
      String? lastError;

      try {
        if (kIsWeb) {
          reachable = true;
        } else {
          final host = endpoint.host;
          int port = endpoint.port;
          if (port == 0) {
            port = endpoint.scheme == 'https' ? 443 : 80;
          }
          final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
          socket.destroy();
          reachable = true;
        }
      } catch (e) {
        lastError = e.toString();
        if (lastError.contains('Connection refused')) {
          lastError = 'Connection refused';
        } else if (lastError.contains('TimeoutException')) {
          lastError = 'Timeout';
        } else {
          lastError = 'Unreachable';
        }
      }
      stopwatch.stop();

      updatedHealths.add(ApiHealth(
        name: name,
        endpoint: endpoint,
        circuit: circuitState,
        reachable: reachable,
        latency: stopwatch.elapsed,
        lastError: lastError,
      ));
    }

    _state = _state.copyWith(apiHealths: updatedHealths);
    notifyListeners();
  }

  CircuitState _getCircuitState(String engineKey) {
    switch (engineKey) {
      case 'context':
        return healthMonitor.contextState;
      case 'behavior':
        return healthMonitor.behaviorState;
      case 'interaction':
        return healthMonitor.interactionState;
      case 'ecom':
        return healthMonitor.ecomState;
      case 'memory':
        return healthMonitor.memoryState;
      default:
        return CircuitState.closed;
    }
  }

  bool get isAudioLoopRunning => _isAudioLoopRunning;
  String _lastSpokenUtterance = '';

  void _syncNewArchitecture() {
    final telemetry = telemetryService;
    final health = sourceManager.currentHealth;
    final result = streamCoordinator.lastResult;

    EngineState getEngineState(CircuitState state) {
      switch (state) {
        case CircuitState.closed:
          return EngineState.running;
        case CircuitState.halfOpen:
          return EngineState.starting;
        case CircuitState.open:
          return EngineState.failed;
      }
    }

    // Capture latency of context engine
    final lastLatency = telemetry.latencies['ContextEngine']?.toDouble() ?? 0.0;
    final rtt = telemetry.latencies['BehaviorEngine'] ?? 0;

    final contextOutput = result['context_output'] as ContextEngineOutput?;
    final behaviorOutput = result['behavior_output'] as BIEFrame?;
    final interactionOutput = result['interaction_output'] as InteractionResponse?;
    final ecomOutput = result['ecom_output'] as EcomAdResponse?;
    final memoryOutput = result['memory_output'] as MemoryResponse?;

    if (interactionOutput != null && 
        interactionOutput.lastUtterance.isNotEmpty && 
        interactionOutput.lastUtterance != _lastSpokenUtterance) {
      _lastSpokenUtterance = interactionOutput.lastUtterance;
      flutterTts.speak(_lastSpokenUtterance);
    }

    final topSalient = (contextOutput?.topSalientObjects != null && contextOutput!.topSalientObjects.isNotEmpty)
        ? contextOutput.topSalientObjects
        : _state.topSalientObjects;
    final suggested = (ecomOutput?.suggestions != null && ecomOutput!.suggestions.isNotEmpty)
        ? ecomOutput.suggestions
        : _state.suggestedProducts;

    final rawStatuses = result['engine_status'] as Map<String, EngineStatus>? ?? const <String, EngineStatus>{};

    final latestFrame = streamCoordinator.latestProcessedFrame;
    final frameBytes = latestFrame?.bytes;

    _state = _state.copyWith(
      metaFrameBytes: frameBytes,
      isSessionActive: streamCoordinator.isRunning,
      isDegraded: health.status == SourceHealthStatus.degraded ||
          healthMonitor.contextState == CircuitState.open ||
          healthMonitor.behaviorState == CircuitState.open ||
          healthMonitor.interactionState == CircuitState.open ||
          healthMonitor.ecomState == CircuitState.open ||
          healthMonitor.memoryState == CircuitState.open,
      glassesState: sourceManager.activeType == SourceType.meta
          ? (health.status == SourceHealthStatus.healthy ? EngineState.running : EngineState.failed)
          : EngineState.idle,
      mediaState: streamCoordinator.isRunning ? EngineState.running : EngineState.idle,
      aiState: getEngineState(healthMonitor.contextState),
      mediaFps: telemetry.fps,
      aiThroughputFps: telemetry.fps,
      aiLatencyMs: lastLatency,
      rttMs: rtt,
      bleRssi: sourceManager.activeType == SourceType.meta ? -55 : 0,
      connectedDeviceName: sourceManager.activeType.name.toUpperCase(),
      bleConnectionState: sourceManager.activeType == SourceType.meta
          ? (health.status == SourceHealthStatus.healthy ? GlassesConnectionState.connected : GlassesConnectionState.connecting)
          : GlassesConnectionState.disconnected,
      framesEmitted: telemetry.capturedFrames,
      framesDropped: telemetry.droppedFrames,
      aiFramesSkipped: telemetry.droppedFrames,
      modelOutputs: {},
      modelContext: _makeJsonEncodable(result),
      audioLevel: _audioService.level,
      latitude: _locationService.latitude,
      longitude: _locationService.longitude,
      lastHealthMessage: health.message,
      lastContextOutput: contextOutput,
      lastBIEFrame: behaviorOutput,
      lastInteractionResponse: interactionOutput,
      lastEcomResponse: ecomOutput,
      lastMemoryResponse: memoryOutput,
      topSalientObjects: topSalient,
      suggestedProducts: suggested,
      engineStatuses: rawStatuses,
    );
    notifyListeners();
  }

  Map<String, dynamic> _makeJsonEncodable(Map<String, dynamic> input) {
    final result = <String, dynamic>{};
    input.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[key] = _makeJsonEncodable(value);
      } else if (value is Map) {
        final typedMap = <String, dynamic>{};
        value.forEach((k, v) {
          if (v is EngineStatus) {
            typedMap[k.toString()] = v.toJson();
          } else if (v is ApiHealth) {
            typedMap[k.toString()] = v.toJson();
          } else if (v is ContextEngineOutput) {
            typedMap[k.toString()] = _makeJsonEncodable(v.raw);
          } else if (v is BIEFrame) {
            typedMap[k.toString()] = _makeJsonEncodable(v.raw);
          } else if (v is InteractionResponse) {
            typedMap[k.toString()] = _makeJsonEncodable(v.raw);
          } else if (v is EcomAdResponse) {
            typedMap[k.toString()] = _makeJsonEncodable(v.raw);
          } else if (v is MemoryResponse) {
            typedMap[k.toString()] = _makeJsonEncodable(v.raw);
          } else if (v is Map<String, dynamic>) {
            typedMap[k.toString()] = _makeJsonEncodable(v);
          } else {
            typedMap[k.toString()] = v;
          }
        });
        result[key] = typedMap;
      } else if (value is EngineStatus) {
        result[key] = value.toJson();
      } else if (value is ApiHealth) {
        result[key] = value.toJson();
      } else if (value is ContextEngineOutput) {
        result[key] = _makeJsonEncodable(value.raw);
      } else if (value is BIEFrame) {
        result[key] = _makeJsonEncodable(value.raw);
      } else if (value is InteractionResponse) {
        result[key] = _makeJsonEncodable(value.raw);
      } else if (value is EcomAdResponse) {
        result[key] = _makeJsonEncodable(value.raw);
      } else if (value is MemoryResponse) {
        result[key] = _makeJsonEncodable(value.raw);
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is EngineStatus) return item.toJson();
          if (item is ApiHealth) return item.toJson();
          if (item is ContextEngineOutput) return _makeJsonEncodable(item.raw);
          if (item is BIEFrame) return _makeJsonEncodable(item.raw);
          if (item is InteractionResponse) return _makeJsonEncodable(item.raw);
          if (item is EcomAdResponse) return _makeJsonEncodable(item.raw);
          if (item is MemoryResponse) return _makeJsonEncodable(item.raw);
          if (item is Map<String, dynamic>) return _makeJsonEncodable(item);
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  void _addLog(String message) {
    debugPrint('SessionProvider: $message');
    final time = DateTime.now();
    final stamp = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    final logs = List<String>.from(_state.eventLogs);
    logs.insert(0, '[$stamp] $message');
    if (logs.length > 100) logs.removeLast();
    _state = _state.copyWith(eventLogs: logs);
  }

  @override
  void dispose() {
    _healthProbeTimer?.cancel();
    _cameraService.removeListener(_syncNewArchitecture);
    _audioService.removeListener(_syncNewArchitecture);
    _locationService.removeListener(_syncNewArchitecture);
    sourceManager.removeListener(_syncNewArchitecture);
    streamCoordinator.removeListener(_syncNewArchitecture);
    healthMonitor.removeListener(_syncNewArchitecture);
    telemetryService.removeListener(_syncNewArchitecture);

    sourceManager.dispose();
    streamCoordinator.dispose();
    healthMonitor.dispose();
    telemetryService.dispose();
    super.dispose();
  }
}

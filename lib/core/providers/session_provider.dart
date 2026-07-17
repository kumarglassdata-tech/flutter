import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartglass_flutter/core/services/camera_service.dart';
import 'package:smartglass_flutter/core/services/titan_sdk_service.dart';
import 'package:smartglass_flutter/core/services/location_service.dart';
import 'package:smartglass_flutter/core/services/notification_service.dart' as import_notification;
import 'package:smartglass_flutter/core/services/glasses_hardware_service.dart';

// Import New Production Architecture
import 'package:smartglass_flutter/core/sources/source_adapter.dart';
import 'package:smartglass_flutter/core/sources/source_manager.dart';
import 'package:smartglass_flutter/core/sources/titan/titan_source_adapter.dart';
import 'package:smartglass_flutter/core/sources/phone/phone_source_adapter.dart';
import 'package:smartglass_flutter/core/sources/laptop/laptop_source_adapter.dart';
import 'package:smartglass_flutter/core/sources/mock/mock_source_adapter.dart';
import 'package:smartglass_flutter/core/sources/video_upload/video_upload_source_adapter.dart';
import 'package:smartglass_flutter/core/models/engine_status.dart';
import 'package:smartglass_flutter/core/engines/shared/engine_registry.dart';
import 'package:smartglass_flutter/core/engines/shared/mappers/request_mappers.dart';

import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/engines/context/context_client.dart';
import 'package:smartglass_flutter/core/engines/behavior/behavior_client.dart';
import 'package:smartglass_flutter/core/engines/interaction/interaction_client.dart';
import 'package:smartglass_flutter/core/engines/ecom/ecom_client.dart';
import 'package:smartglass_flutter/core/engines/memory/memory_client.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';
import 'package:smartglass_flutter/core/models/domain/action_hub_result.dart';
import 'package:smartglass_flutter/core/network/audio_client.dart' as smartglass_audio_client;

import 'package:smartglass_flutter/core/orchestrator/pipeline_coordinator.dart';
import 'package:smartglass_flutter/core/orchestrator/stream_coordinator.dart';
import 'package:smartglass_flutter/core/diagnostics/telemetry_service.dart';
import 'package:smartglass_flutter/core/diagnostics/health_monitor.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:smartglass_flutter/core/services/audio_stream_manager.dart';
import 'package:smartglass_flutter/core/config/env_config.dart';

// ---------------------------------------------------------------------------
// Models (Maintained for Backwards Compatibility)
// ---------------------------------------------------------------------------

enum EngineState { idle, starting, running, stopping, failed }

enum GlassesConnectionState { disconnected, scanning, connecting, connected }

enum DeviceLinkType { ble, classicBt, wifi }

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
  final String? city;
  final ContextEngineOutput? lastContextOutput;
  final BIEFrame? lastBIEFrame;
  final InteractionResponse? lastInteractionResponse;
  final EcomAdResponse? lastEcomResponse;
  final MemoryResponse? lastMemoryResponse;
  final List<String> topSalientObjects;
  final List<EcomAdProduct> suggestedProducts;
  final Map<String, EngineStatus> engineStatuses;
  final List<ApiHealth> apiHealths;
  final int batteryLevel;
  final bool isWearing;
  final bool isVideoRecording;
  final double volumeLevel;
  final double videoDownloadProgress;
  final List<String> importedAlbums;

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
    this.city,
    this.lastContextOutput,
    this.lastBIEFrame,
    this.batteryLevel = 0,
    this.isWearing = false,
    this.isVideoRecording = false,
    this.volumeLevel = 0.5,
    this.videoDownloadProgress = 0.0,
    this.importedAlbums = const [],
    this.lastInteractionResponse,
    this.lastEcomResponse,
    this.lastMemoryResponse,
    this.topSalientObjects = const [],
    this.suggestedProducts = const [],
    this.engineStatuses = const {},
    this.apiHealths = const [],
  });

  ActionHubResult? get actionHubResult {
    if (lastEcomResponse == null) return null;
    return ActionHubResult(
      actionEndpoint: lastEcomResponse!.status, // Not perfect but passes the string
      generatedPayload: lastEcomResponse!.raw,
      productLink: lastEcomResponse!.suggestions.isNotEmpty ? lastEcomResponse!.suggestions.first.id : null,
      imageUrl: lastEcomResponse!.suggestions.isNotEmpty ? lastEcomResponse!.suggestions.first.imageUrl : null,
    );
  }

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
    String? city,
    String? lastHealthMessage,
    ContextEngineOutput? lastContextOutput,
    BIEFrame? lastBIEFrame,
    InteractionResponse? lastInteractionResponse,
    EcomAdResponse? lastEcomResponse,
    MemoryResponse? lastMemoryResponse,
    List<String>? topSalientObjects,
    List<EcomAdProduct>? suggestedProducts,
    Map<String, EngineStatus>? engineStatuses,
    List<ApiHealth>? apiHealths,
    int? batteryLevel,
    bool? isWearing,
    bool? isVideoRecording,
    double? volumeLevel,
    double? videoDownloadProgress,
    List<String>? importedAlbums,
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
      city: city ?? this.city,
      lastHealthMessage: lastHealthMessage ?? this.lastHealthMessage,
      lastContextOutput: lastContextOutput ?? this.lastContextOutput,
      lastBIEFrame: lastBIEFrame ?? this.lastBIEFrame,
      lastInteractionResponse: lastInteractionResponse ?? this.lastInteractionResponse,
      lastEcomResponse: lastEcomResponse ?? this.lastEcomResponse,
      lastMemoryResponse: lastMemoryResponse ?? this.lastMemoryResponse,
      topSalientObjects: topSalientObjects ?? this.topSalientObjects,
      suggestedProducts: suggestedProducts ?? this.suggestedProducts,
      engineStatuses: engineStatuses ?? this.engineStatuses,
      apiHealths: apiHealths ?? this.apiHealths,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isWearing: isWearing ?? this.isWearing,
      isVideoRecording: isVideoRecording ?? this.isVideoRecording,
      volumeLevel: volumeLevel ?? this.volumeLevel,
      videoDownloadProgress: videoDownloadProgress ?? this.videoDownloadProgress,
      importedAlbums: importedAlbums ?? this.importedAlbums,
    );
  }
}

// ---------------------------------------------------------------------------
// SessionProvider
// ---------------------------------------------------------------------------

class SessionProvider extends ChangeNotifier {
  final CameraService _cameraService;
  final TitanSdkService _titanSdkService;
  final LocationService _locationService;

  SessionState _state = const SessionState();
  String _scanStatus = 'Ready to scan';
  bool _isConnecting = false;
  bool _isStartingRuntime = false;
  late final VideoUploadSourceAdapter _videoUploadAdapter;
  late final GlassesHardwareService hardwareService;
  Timer? _healthProbeTimer;
  DateTime? _lastNotificationTime;

  // New Architecture Entities
  late final SourceManager sourceManager;
  late final TelemetryService telemetryService;
  late final PipelineCoordinator pipelineCoordinator;
  late final StreamCoordinator streamCoordinator;
  late final HealthMonitor healthMonitor;
  late final AudioStreamManager audioStreamManager;
  InteractionClient? _interactionClient;
  final FlutterTts flutterTts = FlutterTts()
  ..setVolume(1.0)
  ..setSpeechRate(0.5)
  ..setPitch(1.0);

  bool get isConnecting => _isConnecting;
  bool get isStartingRuntime => _isStartingRuntime;

  String? _savedMacAddress;

  SessionProvider(
    this._cameraService, {
    TitanSdkService? titanSdkService,
    LocationService? locationService,
  })  : _titanSdkService = titanSdkService ?? TitanSdkService(),
        _locationService = locationService ?? LocationService() {
    _cameraService.addListener(_syncNewArchitecture);
    _loadSavedProducts();
    _locationService.addListener(_syncNewArchitecture);
    _locationService.addListener(_syncLocationWithInteractionEngine);

    _initSavedMac();

    if (!kIsWeb) {
      hardwareService = GlassesHardwareService();
      hardwareService.events.listen(_onHardwareEvent);

      _initNewArchitecture();
    }
  }

  Future<void> _initSavedMac() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedMacAddress = prefs.getString('last_connected_mac');
    } catch (e) {
      debugPrint('Error loading saved MAC: $e');
    }
  }

  void _onHardwareEvent(GlassesHardwareEvent event) {
    print('DEBUG _onHardwareEvent: received ${event.runtimeType}');
    if (event is ConnectionStateEvent) {
      print('DEBUG _onHardwareEvent: ConnectionStateEvent isConnected=${event.isConnected} address=${event.address}');
      _isConnecting = false;
      if (event.isConnected) {
        _state = _state.copyWith(
          bleConnectionState: GlassesConnectionState.connected,
          glassesState: EngineState.running,
        );
        _addLog('Hardware connected to ${event.address}');
        print('DEBUG _onHardwareEvent: State set to CONNECTED');
        hardwareService.enableDataServices(); // auto-enable services upon connection!
      } else {
        _state = _state.copyWith(
          bleConnectionState: GlassesConnectionState.disconnected,
          glassesState: EngineState.idle,
        );
        _addLog('Hardware disconnected from ${event.address}');
        print('DEBUG _onHardwareEvent: State set to DISCONNECTED');
      }
      notifyListeners();
      } else if (event is DeviceFoundEvent) {
        final nameUpper = event.name.toUpperCase();
        final isValidName = nameUpper.contains('TITAN') || 
                            nameUpper.contains('FASTRACK') || 
                            nameUpper.contains('SMART') || 
                            nameUpper.contains('MYNA') ||
                            nameUpper.contains('GLASS') ||
                            nameUpper.contains('UNKNOWN');
                            
        // Reject generic BLE noise
        if (!isValidName) {
          debugPrint('Rejected device: ${event.name} [${event.address}]');
          return;
        }

        /* Auto-connect commented out for now
        if (_savedMacAddress != null && event.address == _savedMacAddress) {
          if (_state.bleConnectionState != GlassesConnectionState.connected && !_isConnecting) {
            _addLog('Auto-reconnecting to known device: ${event.name}');
            hardwareService.stopScan();
            connectToDevice(event.address);
          }
          return;
        }
        */

        _addLog('Native SDK found device: ${event.name} [${event.address}]');
        
        // Add native SDK device to the UI list if it doesn't already exist
        final exists = _state.discoveredDevices.any((d) => d.address == event.address);
        if (!exists) {
          final newDevice = GlassesDevice(
            name: event.name,
            address: event.address,
            rssi: event.rssi,
            linkType: DeviceLinkType.ble,
          );
          _state = _state.copyWith(
            discoveredDevices: List.from(_state.discoveredDevices)..add(newDevice)
          );
          notifyListeners();
        }
      } else if (event is BatteryLevelEvent) {
        _state = _state.copyWith(batteryLevel: event.level);
        notifyListeners();
        _addLog('🔋 Battery: ${event.level}%');
      } else if (event is PhotoChunkEvent) {
        _addLog('📸 Photo chunk received: ${event.bytes.length} bytes');
      } else if (event is WearStateEvent) {
        _state = _state.copyWith(isWearing: event.isWearing);
        notifyListeners();
        _addLog(event.isWearing ? '👓 Glasses are being worn' : '👓 Glasses removed');
      } else if (event is VideoDownloadProgressEvent) {
        _state = _state.copyWith(videoDownloadProgress: event.progress);
        notifyListeners();
      } else if (event is VideoFileDownloadedEvent) {
        final newAlbums = List<String>.from(_state.importedAlbums)..add(event.filePath);
        _state = _state.copyWith(
          videoDownloadProgress: 1.0,
          importedAlbums: newAlbums,
        );
        notifyListeners();
        _addLog('✅ Video downloaded: ${event.filePath}');
      } else if (event is VideoDownloadErrorEvent) {
        _state = _state.copyWith(videoDownloadProgress: 0.0);
        notifyListeners();
        _addLog('❌ Video download error: ${event.error}');
      }
    }

  Future<void> _loadSavedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsStr = prefs.getString('saved_products');
      if (productsStr != null) {
        final List<dynamic> decoded = jsonDecode(productsStr);
        final List<EcomAdProduct> loaded = decoded
            .map((e) => EcomAdProduct.fromJson(e as Map<String, dynamic>))
            .toList();
        if (loaded.isNotEmpty) {
          _state = _state.copyWith(suggestedProducts: loaded);
          notifyListeners();
        }
      }
    } catch (e) {
      print('Failed to load saved products: $e');
    }
  }

  void _syncLocationWithInteractionEngine() {
    if (_interactionClient != null && _locationService.latitude != null && _locationService.longitude != null) {
      _interactionClient!.setLocation(
        _locationService.latitude!,
        _locationService.longitude!,
        _locationService.city ?? 'Unknown',
        _locationService.country ?? 'Unknown',
      );
    }
  }

  Future<void> _saveProducts(List<EcomAdProduct> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsJson = products.map((p) => p.toJson()).toList();
      await prefs.setString('saved_products', jsonEncode(productsJson));
    } catch (e) {
      print('Failed to save products: $e');
    }
  }

  void _initNewArchitecture() {
    // 1. Initialize Adapters
    final mockAdapter = MockSourceAdapter();
    final phoneAdapter = PhoneSourceAdapter(
      camera: _cameraService,
      location: _locationService,
    );
    final laptopAdapter = LaptopSourceAdapter();
    _videoUploadAdapter = VideoUploadSourceAdapter(
      location: _locationService,
    );

    sourceManager = SourceManager({
      SourceType.mock: mockAdapter,
      SourceType.phone: phoneAdapter,
      SourceType.laptop: laptopAdapter,
      SourceType.videoUpload: _videoUploadAdapter,
    });

    // 2. Initialize Clients & Telemetry
    telemetryService = TelemetryService();

    final contextClient = ContextClient(
      fallbackToMock: false,
      onDiagnosticLog: telemetryService.addDiagnosticLog,
    );
    final behaviorClient = BehaviorClient(
      fallbackToMock: false,
      onDiagnosticLog: telemetryService.addDiagnosticLog,
    );
    final interactionClient = InteractionClient(
      fallbackToMock: false,
      onDiagnosticLog: telemetryService.addDiagnosticLog,
    );
    _interactionClient = interactionClient;
    final ecomClient = EcomClient(
      fallbackToMock: false,
      onDiagnosticLog: telemetryService.addDiagnosticLog,
    );
    final memoryClient = MemoryClient(
      fallbackToMock: false,
      onDiagnosticLog: telemetryService.addDiagnosticLog,
    );

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
      getActiveVoiceNlu: () => _activeVoiceNlu,
    );

    healthMonitor = HealthMonitor(
      contextClient: contextClient,
      behaviorClient: behaviorClient,
      interactionClient: interactionClient,
      ecomClient: ecomClient,
      memoryClient: memoryClient,
      sourceManager: sourceManager,
    );

    // 3. Set up AudioStreamManager — connect WebSocket
    audioStreamManager = AudioStreamManager();
    _audioInitFuture = audioStreamManager.init();
    _audioInitFuture.then((_) {
      audioStreamManager.connect(EnvConfig.interactionWsUrl);
    });
    
    _initAudioStreamListeners(interactionClient);
  }

  late Future<void> _audioInitFuture;

  bool _isListeningStarted = false;

  /// Called after permissions are explicitly granted in the UI
  Future<void> startAlwaysListening() async {
    if (_isListeningStarted) return;
    _isListeningStarted = true;
    await _audioInitFuture;
    await audioStreamManager.startVad();
    _addLog('Always-Listening mode activated.');
  }

  /// Called when app goes to background
  Future<void> stopAlwaysListening() async {
    if (!_isListeningStarted) return;
    _isListeningStarted = false;
    await audioStreamManager.stopVad();
    _addLog('Always-Listening mode paused.');
  }

  Timer? _voiceNluTimer;
  Map<String, dynamic>? _activeVoiceNlu;

  void _initAudioStreamListeners(InteractionClient interactionClient) {
    audioStreamManager.onSpeechStartContext = () {
      // Clear previous voice intent on new speech start
      _voiceNluTimer?.cancel();
      _activeVoiceNlu = null;

      if (_state.lastBIEFrame != null) {
        return _state.lastBIEFrame!.raw;
      }
      return <String, dynamic>{};
    };

    audioStreamManager.transcriptStream.listen((text) async {
      if (text.isNotEmpty && text != _lastSpokenUtterance) {
        _lastSpokenUtterance = text;
        // Since Web can't play raw PCM stream, use TTS as fallback
        if (kIsWeb) {
          flutterTts.speak(_lastSpokenUtterance);
        }
      }

      if (_state.lastInteractionResponse != null) {
        final current = _state.lastInteractionResponse!;
        final updated = InteractionResponse(
          dialogueMode: current.dialogueMode,
          llmGateStatus: current.llmGateStatus,
          lastUtterance: text,
          bcp: current.bcp,
          raw: current.raw,
        );
        _state = _state.copyWith(lastInteractionResponse: updated);
        notifyListeners();
      } else {
        final newResp = InteractionResponse(
          dialogueMode: 'speak',
          llmGateStatus: 'pass',
          lastUtterance: text,
          bcp: BCPPayload.fromJson({}),
          raw: {'utterance': text},
        );
        _state = _state.copyWith(lastInteractionResponse: newResp);
        notifyListeners();
      }
    });

    audioStreamManager.statusStream.listen((statusData) {
      final interactionResponse = InteractionResponse.fromJson(statusData);
      _state = _state.copyWith(lastInteractionResponse: interactionResponse);

      // Extract voice NLU and set 15s TTL
      final bcpRaw = interactionResponse.raw['bcp'] as Map<String, dynamic>?;
      final bcpVoiceNlu = bcpRaw?['voice_nlu'];
      final voiceNlu = bcpVoiceNlu ?? interactionResponse.raw['voice_nlu'] ?? interactionResponse.raw['voice_assistant_response'];

      if (voiceNlu != null && voiceNlu['rhino_active'] == true) {
        _activeVoiceNlu = voiceNlu;
        _voiceNluTimer?.cancel();
        _voiceNluTimer = Timer(const Duration(seconds: 15), () {
          _activeVoiceNlu = null;
        });
      }

      if (interactionResponse.lastUtterance.isNotEmpty && interactionResponse.lastUtterance != _lastSpokenUtterance) {
        _lastSpokenUtterance = interactionResponse.lastUtterance;
      }

      final bcpJson = statusData['bcp'] ?? <String, dynamic>{};
      if (bcpJson.isNotEmpty) {
        // Inject current salient objects if the voice intent doesn't have any
        if (bcpJson['top_salient_objects'] == null || (bcpJson['top_salient_objects'] as List).isEmpty) {
           final lastSalience = _state.lastBIEFrame?.salienceScore ?? 1.0;
           bcpJson['top_salient_objects'] = _state.topSalientObjects.map((obj) => {
             'class_name': obj,
             'salience_score': lastSalience,
           }).toList();
        }

        final audioBieFrame = BIEFrame.fromJson(bcpJson);
        _state = _state.copyWith(lastBIEFrame: audioBieFrame);
        
        _addLog('Audio intent triggered Ecom unconditionally (delegating to backend).');
        final sharedState = <String, dynamic>{};
        pipelineCoordinator.ecomStep.execute(audioBieFrame, sharedState).then((ecomRes) {
          if (ecomRes.isSuccess && ecomRes.output != null) {
              final newSuggestions = ecomRes.output!.suggestions;
              final newIds = newSuggestions.map((e) => e.id).toSet();
              final oldIds = _state.suggestedProducts.map((e) => e.id).toSet();
              final validLinks = newSuggestions.where((s) => s.id.startsWith('http://') || s.id.startsWith('https://')).toList();
              
              _state = _state.copyWith(
                lastEcomResponse: ecomRes.output,
                suggestedProducts: newSuggestions.isNotEmpty ? newSuggestions : _state.suggestedProducts,
              );
              
              if (!oldIds.containsAll(newIds) && validLinks.isNotEmpty) {
                final now = DateTime.now();
                if (_lastNotificationTime == null || now.difference(_lastNotificationTime!).inSeconds > 120) {
                  _lastNotificationTime = now;
                  import_notification.NotificationService().showProductRecommendationNotification(
                    title: 'Product Link Found',
                    body: 'A buy link for ${validLinks.first.name} is available!',
                  );
                }
              }
              notifyListeners();
          }
        });
      }
      notifyListeners();
    });

    interactionClient.setAudioStreamManager(audioStreamManager);

    // 4. Set up listeners to propagate changes to UI
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
    if (_state.bleConnectionState == GlassesConnectionState.scanning) {
      print('DEBUG: Already scanning, ignoring startDiscovery call.');
      return;
    }

    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        await Permission.locationWhenInUse.request();
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.bluetoothScan.request();
        await Permission.bluetoothConnect.request();
      }
    }

    _scanStatus = 'Scanning nearby devices…';
    _state = _state.copyWith(
        bleConnectionState: GlassesConnectionState.scanning,
        discoveredDevices: [] // Clear previously discovered devices on new scan
    );
    notifyListeners();
    
    // Stop any existing scans to prevent SCAN_FAILED_ALREADY_STARTED (Error 0)
    if (!kIsWeb) {
      hardwareService.stopScan();
      await Future.delayed(const Duration(milliseconds: 300));
      hardwareService.startScan();
    }
    
    // Stop native scan when flutter finishes its timeout (increased to 30 seconds to give ample time)
    Future.delayed(const Duration(seconds: 30), () {
      if (_state.bleConnectionState == GlassesConnectionState.scanning) {
        if (!kIsWeb) hardwareService.stopScan();
        _state = _state.copyWith(bleConnectionState: GlassesConnectionState.disconnected);
        _scanStatus = 'Scan complete.';
        _addLog(_scanStatus);
        notifyListeners();
      }
    });
  }

  Future<void> stopDiscovery() async {
    if (_state.bleConnectionState != GlassesConnectionState.scanning) return;
    if (!kIsWeb) hardwareService.stopScan();
    _state = _state.copyWith(bleConnectionState: GlassesConnectionState.disconnected);
    _scanStatus = 'Scan stopped.';
    _addLog(_scanStatus);
    notifyListeners();
  }

  Future<List<GlassesDevice>> _scanBluetoothDevices() async {
    if (kIsWeb) {
      return const [
        GlassesDevice(
          name: 'Titan Web Simulator',
          address: 'WEB:00:11:22',
          isBonded: false,
          rssi: -40,
          linkType: DeviceLinkType.ble,
        )
      ];
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        await Permission.locationWhenInUse.request();
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.bluetoothScan.request();
        await Permission.bluetoothConnect.request();
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

          final nameUpper = name.toUpperCase();
          if (nameUpper == 'BLE DEVICE') {
            continue; // Drop completely nameless devices to avoid flooding, but allow UNKNOWN glasses
          }

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

  Future<void> syncBattery() async {
    if (!kIsWeb) hardwareService.syncBattery();
    _addLog('🔋 Syncing battery...');
    notifyListeners();
  }
  
  Future<void> importAlbums() async {
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        final statuses = await [
          Permission.location,
          Permission.nearbyWifiDevices,
        ].request();
        _addLog('Location permission: ${statuses[Permission.location]}');
        _addLog('Nearby WiFi permission: ${statuses[Permission.nearbyWifiDevices]}');
      }
      hardwareService.importVideoAlbum();
    }
    _addLog('📥 Importing video album...');
    notifyListeners();
  }

  Future<void> capturePhoto() async {
    if (!kIsWeb) hardwareService.capturePhoto();
    _addLog('📸 Capturing photo...');
    notifyListeners();
  }

  Future<void> setVolume(double level) async {
    _state = _state.copyWith(volumeLevel: level.clamp(0.0, 1.0));
    notifyListeners();
    if (!kIsWeb) hardwareService.setVolume(level);
    _addLog('🔊 Volume set to ${(level * 100).round()}%');
  }

  Future<void> startVideoRecording() async {
    if (!kIsWeb) hardwareService.startVideoRecording();
    _state = _state.copyWith(isVideoRecording: true);
    _addLog('🎥 Video recording started');
    notifyListeners();
  }

  Future<void> stopVideoRecording() async {
    if (!kIsWeb) hardwareService.stopVideoRecording();
    _state = _state.copyWith(isVideoRecording: false);
    _addLog('🎥 Video recording stopped');
    notifyListeners();
  }

  Future<void> connectToDevice(String address, {bool useMock = false}) async {
    print('DEBUG: connectToDevice called with address: $address, isConnecting: $_isConnecting');
    if (_isConnecting) {
      print('DEBUG: Aborting connectToDevice because _isConnecting is already true!');
      return;
    }
    _isConnecting = true;
    
    final device = _state.discoveredDevices.where((d) => d.address == address).firstOrNull;
    _state = _state.copyWith(
      bleConnectionState: GlassesConnectionState.connecting,
      connectedDeviceName: device?.name,
    );
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_connected_mac', address);
      _savedMacAddress = address;

      print('DEBUG: State updated to connecting for ${device?.name ?? address}');
      _addLog('Connecting to ${device?.name ?? address}…');
      notifyListeners();
      try {
        await sourceManager.switchSource(SourceType.phone); // Temporary fallback video source
      } catch (e) {
        print('DEBUG: sourceManager.switchSource failed: $e. Continuing with BLE connection anyway.');
      }
      print('DEBUG: Checking mock and web status: useMock=$useMock, kIsWeb=$kIsWeb');
      if (!useMock && !kIsWeb) {
        print('DEBUG: Invoking hardwareService.connect($address)');
        _addLog('Delegating connection to GlassesHardwareService for $address...');
        await hardwareService.connect(address);
      } else {
        await Future.delayed(const Duration(seconds: 1));
        _state = _state.copyWith(
          bleConnectionState: GlassesConnectionState.connected,
          glassesState: EngineState.running,
        );
        _addLog('Connected to ${device?.name ?? address} (Simulated)');
      }
      print('DEBUG: connectToDevice try block completed successfully');
    } catch (e, stack) {
      print('DEBUG: Exception in connectToDevice: $e\n$stack');
      _addLog('Connection failed: $e');
      _state = _state.copyWith(
        bleConnectionState: GlassesConnectionState.disconnected,
        glassesState: EngineState.failed,
      );
      _isConnecting = false;
      notifyListeners();
    }
    
    // Set a timeout to clear the connecting state if native SDK doesn't respond
    // Increased to 45 seconds to allow ample time for OS-level Bluetooth Pairing/Bonding dialogs!
    if (!useMock && !kIsWeb) {
      Future.delayed(const Duration(seconds: 45), () {
        if (_state.bleConnectionState == GlassesConnectionState.connecting) {
          print('DEBUG: 45 second timeout hit!');
          _isConnecting = false;
          _state = _state.copyWith(
            bleConnectionState: GlassesConnectionState.disconnected,
            glassesState: EngineState.failed,
          );
          _addLog('Connection timed out.');
          notifyListeners();
        }
      });
    } else {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> startRuntime({bool useMock = false}) async {
    if (_isStartingRuntime) return;
    _isStartingRuntime = true;
    notifyListeners();

    try {
      _addLog('Starting real-time stream coordinator...');
      if (useMock) {
        await sourceManager.switchSource(SourceType.mock);
      } else if (sourceManager.activeType == SourceType.videoUpload) {
        // Keep active source as video upload
      } else if (sourceManager.activeType == SourceType.laptop) {
        // Keep active source as laptop
      } else {
        await sourceManager.switchSource(SourceType.phone);
      }

      healthMonitor.resetAllCircuits();
      streamCoordinator.start();
      await audioStreamManager.startVad();
      _addLog('Real-time ingestion pipeline running. VAD listening.');

      // Removed HTTP audio loop as WebSockets are used now.
    } catch (e) {
      _addLog('Stream Coordinator start failed: $e');
    } finally {
      _isStartingRuntime = false;
      notifyListeners();
    }
  }

  Future<void> stopRuntime() async {
    _addLog('Stopping real-time stream coordinator...');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_connected_mac');
      _savedMacAddress = null;
      await hardwareService.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting hardware: $e');
    }
    try {
      await _cameraService.stopStreaming().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Error stopping camera: $e');
    }
    try {
      await audioStreamManager.stopVad().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Error stopping VAD: $e');
    }
    try {
      await audioStreamManager.disconnect().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Error disconnecting audio WS: $e');
    }
    try {
      streamCoordinator.stop();
    } catch (e) {
      debugPrint('Error stopping stream coordinator: $e');
    }

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
    if (kIsWeb) return;
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
          // Use HTTP GET instead of raw TCP socket to bypass reverse proxies/WAF blocks
          try {
            final response = await http.get(endpoint).timeout(const Duration(seconds: 4));
            // Even a 404/405/500 means the host is reachable
            reachable = true;
          } catch (e) {
             reachable = false;
             throw e;
          }
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


  String _lastSpokenUtterance = '';
  DateTime _lastNotifyTime = DateTime.now();

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
    }

    final topSalient = (contextOutput?.topSalientObjects != null && contextOutput!.topSalientObjects.isNotEmpty)
        ? contextOutput.topSalientObjects
        : _state.topSalientObjects;
        
    final suggested = (ecomOutput?.suggestions != null && ecomOutput!.suggestions.isNotEmpty)
        ? ecomOutput.suggestions
        : _state.suggestedProducts;

    if (ecomOutput?.suggestions != null && ecomOutput!.suggestions.isNotEmpty) {
      _saveProducts(ecomOutput.suggestions);
      
      final newIds = ecomOutput!.suggestions.map((e) => e.id).toSet();
      final oldIds = _state.suggestedProducts.map((e) => e.id).toSet();
      final validLinks = ecomOutput.suggestions.where((s) => s.id.startsWith('http://') || s.id.startsWith('https://')).toList();
      
      if (!oldIds.containsAll(newIds) && validLinks.isNotEmpty) {
        final now = DateTime.now();
        if (_lastNotificationTime == null || now.difference(_lastNotificationTime!).inSeconds > 120) {
          _lastNotificationTime = now;
          import_notification.NotificationService().showProductRecommendationNotification(
            title: 'Product Link Found',
            body: 'A buy link for ${validLinks.first.name} is available!',
          );
        }
      }
    }

    final rawStatuses = result['engine_status'] as Map<String, EngineStatus>? ?? const <String, EngineStatus>{};

    final latestFrame = streamCoordinator.latestProcessedFrame;
    final frameBytes = latestFrame?.bytes;

    _state = _state.copyWith(
      isSessionActive: streamCoordinator.isRunning,
      latitude: _locationService.latitude,
      longitude: _locationService.longitude,
      city: _locationService.city,
      isDegraded: health.status == SourceHealthStatus.degraded ||
          healthMonitor.contextState == CircuitState.open ||
          healthMonitor.behaviorState == CircuitState.open ||
          healthMonitor.interactionState == CircuitState.open ||
          healthMonitor.ecomState == CircuitState.open ||
          healthMonitor.memoryState == CircuitState.open,
      // IMPORTANT: Do NOT overwrite glassesState, bleConnectionState, connectedDeviceName, or bleRssi here.
      // Those are managed by _onHardwareEvent and connectToDevice. Overwriting them here
      // was the root cause of the "dashboard never shows connected" bug.
      mediaState: streamCoordinator.isRunning ? EngineState.running : EngineState.idle,
      aiState: getEngineState(healthMonitor.contextState),
      mediaFps: telemetry.fps,
      aiThroughputFps: telemetry.fps,
      aiLatencyMs: lastLatency,
      rttMs: rtt,
      framesEmitted: telemetry.capturedFrames,
      framesDropped: telemetry.droppedFrames,
      aiFramesSkipped: telemetry.droppedFrames,
      modelOutputs: {},
      audioLevel: 0.0, // Interaction Engine manages audio directly now
      modelContext: _makeJsonEncodable(result),
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

  // ==========================================
  // Public Event Logging
  // ==========================================
  void logEvent(String message) {
    _addLog(message);
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

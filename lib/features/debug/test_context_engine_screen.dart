import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:smartglass_flutter/core/engines/context/test_context_websocket_client.dart';
import 'package:smartglass_flutter/core/services/location_service.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class TestContextEngineScreen extends StatefulWidget {
  const TestContextEngineScreen({super.key});

  @override
  State<TestContextEngineScreen> createState() => _TestContextEngineScreenState();
}

class _TestContextEngineScreenState extends State<TestContextEngineScreen> {
  final TextEditingController _urlController = TextEditingController(text: 'wss://myna.glassdata.ai/api/v1/ce/stream'); // Production default
  late TestContextWebsocketClient _wsClient;
  
  // Camera variables
  CameraController? _cameraController;
  bool _isStreaming = false;
  bool _isLeftPanelCollapsed = false;
  Timer? _streamingTimer;
  
  @override
  void initState() {
    super.initState();
    _wsClient = TestContextWebsocketClient();
    _initCamera();
    
    // Automatically start GPS when this screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locService = context.read<LocationService>();
      locService.start();
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _toggleStreaming() async {
    if (_isStreaming) {
      setState(() => _isStreaming = false);
      _wsClient.disconnect();
    } else {
      if (_cameraController == null || !_cameraController!.value.isInitialized) return;
      
      // Auto connect to the websocket
      if (!_wsClient.isConnected) {
        await _wsClient.connect('wss://myna.glassdata.ai/api/v1/ce/stream');
      }
      
      setState(() => _isStreaming = true);
      _streamFrames();
    }
  }

  Future<void> _streamFrames() async {
    final locService = context.read<LocationService>();
    
    while (_isStreaming && _wsClient.isConnected) {
      try {
        final xFile = await _cameraController!.takePicture();
        final bytes = await xFile.readAsBytes();
        
        // Final safety check before pushing to socket just in case they clicked stop while taking picture
        if (_isStreaming && _wsClient.isConnected) {
          final lat = locService.latitude ?? 12.9716; // default fallback if no gps
          final lon = locService.longitude ?? 77.5946; // default fallback
          _wsClient.sendFrameWithMetadata(bytes, lat, lon);
        }
      } catch (e) {
        debugPrint('Error taking picture: $e');
      }
      
      if (_isStreaming) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    
    if (mounted && _isStreaming) {
      setState(() => _isStreaming = false);
    }
  }

  @override
  void dispose() {
    _isStreaming = false;
    _cameraController?.dispose();
    _wsClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locService = context.watch<LocationService>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Context Engine Tester'),
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: Icon(_isLeftPanelCollapsed ? Icons.menu : Icons.menu_open),
          onPressed: () => setState(() => _isLeftPanelCollapsed = !_isLeftPanelCollapsed),
          tooltip: 'Toggle Left Panel',
        ),
      ),
      body: Column(
        children: [
          
          // Main Body: 2 Columns
          Expanded(
            child: Row(
              children: [
                // Left Panel: GPS & Camera
                if (!_isLeftPanelCollapsed)
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      color: AppTheme.background,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Live GPS Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Latitude: ${locService.latitude?.toStringAsFixed(6) ?? 'Waiting...'}', style: const TextStyle(fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('Longitude: ${locService.longitude?.toStringAsFixed(6) ?? 'Waiting...'}', style: const TextStyle(fontSize: 16)),
                                    const SizedBox(height: 8),
                                    const Text('Sent automatically when moved 5m or every 5s.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            const Text('Live Camera Stream', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            if (_cameraController != null && _cameraController!.value.isInitialized)
                              Card(
                                clipBehavior: Clip.antiAlias,
                                child: AspectRatio(
                                  aspectRatio: _cameraController!.value.aspectRatio,
                                  child: CameraPreview(_cameraController!),
                                ),
                              )
                            else
                              const SizedBox(
                                height: 200,
                                child: Center(child: CircularProgressIndicator())
                              ),
                            
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _toggleStreaming,
                              icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                              label: Text(_isStreaming ? 'Stop Streaming' : 'Start Streaming'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isStreaming ? Colors.red : AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                if (!_isLeftPanelCollapsed)
                  const VerticalDivider(width: 1),
                
                // Right Panel: WebSocket Logs
                Expanded(
                  flex: _isLeftPanelCollapsed ? 1 : 2,
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    color: const Color(0xFF1E1E1E), // Dark theme for logs
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Engine Outputs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListenableBuilder(
                            listenable: _wsClient,
                            builder: (context, _) {
                              return ListView.builder(
                                itemCount: _wsClient.logs.length,
                                itemBuilder: (context, index) {
                                  final log = _wsClient.logs[index];
                                  final isReceived = log.contains('Received JSON:');
                                  final isSent = log.contains('Sent ');
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Text(
                                      log,
                                      style: TextStyle(
                                        color: isReceived ? Colors.greenAccent : (isSent ? Colors.blueAccent : Colors.white70),
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

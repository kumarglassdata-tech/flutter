import 'dart:convert';
import 'dart:io';
import 'package:path_provider/package:path_provider.dart';
import '../models/engine_context.dart';
import '../mappers/session_state_mapper.dart';

class ReplayService {
  static Future<void> logExecution(EngineContext context, SessionState finalState) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/replay_${context.pipelineId}.json');

      final payload = {
        'pipelineId': context.pipelineId,
        'timestamp': DateTime.now().toIso8601String(),
        'input_source': context.input.source.toString(),
        'telemetry': context.telemetry.map((t) => {
          'engine': t.engine,
          'latencyMs': t.latencyMs,
          'success': t.success,
          'error': t.error,
        }).toList(),
        'final_ui_text': finalState.uiOverlayText,
        'is_interacting': finalState.isInteracting,
      };

      await file.writeAsString(jsonEncode(payload));
      print('[ReplayService] Logged pipeline ${context.pipelineId} to ${file.path}');
    } catch (e) {
      print('[ReplayService] Failed to log replay data: $e');
    }
  }
}

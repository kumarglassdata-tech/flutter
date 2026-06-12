import 'dart:async';
import 'dart:convert';

import 'package:smartglass_flutter/core/orchestrator/steps/context_engine_step.dart';
import 'package:smartglass_flutter/core/orchestrator/steps/behaviour_intent_step.dart';
import 'package:smartglass_flutter/core/orchestrator/steps/gate_check_step.dart';
import 'package:smartglass_flutter/core/orchestrator/steps/interaction_subsystem_step.dart';
import 'package:smartglass_flutter/core/orchestrator/steps/ecom_ad_step.dart';
import 'package:smartglass_flutter/core/orchestrator/steps/safety_memory_step.dart';

import 'package:smartglass_flutter/core/engines/context/context_client.dart';
import 'package:smartglass_flutter/core/engines/behavior/behavior_client.dart';
import 'package:smartglass_flutter/core/engines/interaction/interaction_client.dart';
import 'package:smartglass_flutter/core/engines/ecom/ecom_client.dart';
import 'package:smartglass_flutter/core/engines/memory/memory_client.dart';

import 'package:smartglass_flutter/core/engines/shared/mappers/request_mappers.dart';
import 'package:smartglass_flutter/core/models/unified_input.dart';
import 'package:smartglass_flutter/core/models/engine_status.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';
import 'package:smartglass_flutter/core/orchestrator/pipeline_step.dart';
import 'package:smartglass_flutter/core/diagnostics/telemetry_service.dart';

class PipelineCoordinator {
  final ContextEngineStep contextStep;
  final BehaviourIntentStep behaviorStep;
  final GateCheckStep gateCheckStep;
  final InteractionSubsystemStep interactionStep;
  final EcomAdStep ecomStep;
  final SafetyMemoryStep memoryStep;
  final TelemetryService _telemetryService;

  PipelineCoordinator({
    required ContextClient contextClient,
    required BehaviorClient behaviorClient,
    required InteractionClient interactionClient,
    required EcomClient ecomClient,
    required MemoryClient memoryClient,
    required TelemetryService telemetryService,
    ContextEngineStep? contextStep,
    BehaviourIntentStep? behaviorStep,
    GateCheckStep? gateCheckStep,
    InteractionSubsystemStep? interactionStep,
    EcomAdStep? ecomStep,
    SafetyMemoryStep? memoryStep,
  })  : contextStep = contextStep ?? ContextEngineStep(contextClient),
        behaviorStep = behaviorStep ?? BehaviourIntentStep(behaviorClient),
        gateCheckStep = gateCheckStep ?? GateCheckStep(),
        interactionStep = interactionStep ?? InteractionSubsystemStep(interactionClient),
        ecomStep = ecomStep ?? EcomAdStep(ecomClient),
        memoryStep = memoryStep ?? SafetyMemoryStep(memoryClient),
        _telemetryService = telemetryService;

  Future<Map<String, dynamic>> runPipeline(UnifiedInput input) async {
    final sharedState = <String, dynamic>{};
    final statuses = <String, EngineStatus>{};
    sharedState['engine_status'] = statuses;
    sharedState['input_lat'] = input.latitude ?? 0.0;
    sharedState['input_lon'] = input.longitude ?? 0.0;
    final stopwatch = Stopwatch()..start();

    final timestamp = input.timestamp;
    final source = input.source.name;
    final imgLen = input.imageBytes?.length ?? 0;
    final lat = input.latitude ?? 0.0;
    final lon = input.longitude ?? 0.0;
    final audioLevel = 0.0; // Input audioLevel removed for now

    print('============================================================');
    print('[PIPELINE RUN] STARTING PIPELINE');
    print('  - Timestamp: $timestamp');
    print('  - Source: $source');
    print('  - Input details:');
    print('    * Image frame: $imgLen bytes');
    print('    * GPS Location: Latitude $lat, Longitude $lon');
    print('    * Audio first sample: $audioLevel');
    print('------------------------------------------------------------');

    // 1. Run Context Step
    final contextStart = stopwatch.elapsedMilliseconds;
    final contextRes = await contextStep.execute(input, sharedState);
    final contextLatency = stopwatch.elapsedMilliseconds - contextStart;
    _telemetryService.recordLatency('ContextEngine', contextLatency);

    final contextRawOutput = sharedState['context'];
    final contextIsMock = sharedState['context_is_mock'] ?? false;
    print('[STEP 1] ContextEngine (Latency: ${contextLatency}ms, Mock: $contextIsMock)');
    print('  - Request:');
    print('    * Image size: $imgLen bytes');
    print('    * GPS Hazard flag: false');
    if (contextRes.isSuccess) {
      print('  - Response payload:');
      try {
        print('    ${jsonEncode(contextRawOutput)}');
      } catch (_) {
        print('    $contextRawOutput');
      }
    } else {
      print('  - FAILED: ${contextRes.errorMessage}');
    }
    print('------------------------------------------------------------');

    if (!contextRes.isSuccess) {
      statuses['ContextEngine'] = EngineStatus(
        engine: 'ContextEngine',
        state: 'ERROR',
        message: contextRes.errorMessage,
        timestamp: DateTime.now(),
        latency: Duration(milliseconds: contextLatency),
      );
      sharedState['pipeline.error'] = 'Context Step Failed: ${contextRes.errorMessage}';
      print('[PIPELINE RUN] ABORTED (Context Step Failed)');
      print('============================================================');
      return sharedState;
    } else {
      statuses['ContextEngine'] = EngineStatus(
        engine: 'ContextEngine',
        state: 'CONNECTED',
        timestamp: DateTime.now(),
        latency: Duration(milliseconds: contextLatency),
      );
    }

    // 2. Run Behavior Step
    final behaviorStart = stopwatch.elapsedMilliseconds;
    final PipelineResult<BIEFrame> behaviorRes = await behaviorStep.execute(contextRes.output!, sharedState);
    final behaviorLatency = stopwatch.elapsedMilliseconds - behaviorStart;
    _telemetryService.recordLatency('BehaviorEngine', behaviorLatency);

    final behaviorRawOutput = sharedState['behavior'];
    final behaviorIsMock = sharedState['behavior_is_mock'] ?? false;
    print('[STEP 2] BehaviorEngine (Latency: ${behaviorLatency}ms, Mock: $behaviorIsMock)');
    print('  - Request:');
    try {
      final reqPayload = RequestMappers.toBehaviorRequest(contextRes.output!, lat: lat, lon: lon);
      print('    ${jsonEncode(reqPayload)}');
    } catch (_) {
      print('    <Failed to map request payload>');
    }
    if (behaviorRes.isSuccess) {
      print('  - Response payload:');
      try {
        print('    ${jsonEncode(behaviorRawOutput)}');
      } catch (_) {
        print('    $behaviorRawOutput');
      }
    } else {
      print('  - FAILED: ${behaviorRes.errorMessage}');
    }
    print('------------------------------------------------------------');

    if (!behaviorRes.isSuccess) {
      statuses['BehaviorEngine'] = EngineStatus(
        engine: 'BehaviorEngine',
        state: 'ERROR',
        message: behaviorRes.errorMessage,
        timestamp: DateTime.now(),
        latency: Duration(milliseconds: behaviorLatency),
      );
      sharedState['pipeline.error'] = 'Behavior Step Failed: ${behaviorRes.errorMessage}';
      print('[PIPELINE RUN] ABORTED (Behavior Step Failed)');
      print('============================================================');
      return sharedState;
    } else {
      statuses['BehaviorEngine'] = EngineStatus(
        engine: 'BehaviorEngine',
        state: 'CONNECTED',
        timestamp: DateTime.now(),
        latency: Duration(milliseconds: behaviorLatency),
      );
    }

    // 3. Run Gate Check Step
    final gateStart = stopwatch.elapsedMilliseconds;
    final gateRes = await gateCheckStep.execute(behaviorRes.output!, sharedState);
    final gateLatency = stopwatch.elapsedMilliseconds - gateStart;
    _telemetryService.recordLatency('GateCheck', gateLatency);

    final gateOpen = gateRes.output ?? false;
    final gateReason = sharedState['gate_reason'] ?? '';
    print('[STEP 3] GateCheck (Latency: ${gateLatency}ms)');
    print('  - Gaze target: ${behaviorRes.output!.gazeTarget}');
    print('  - Salience score: ${behaviorRes.output!.salienceScore}');
    print('  - Gate status: ${gateOpen ? "OPEN" : "CLOSED"} ($gateReason)');
    print('------------------------------------------------------------');

    if (!gateRes.isSuccess) {
      statuses['GateCheck'] = EngineStatus(
        engine: 'GateCheck',
        state: 'ERROR',
        message: gateRes.errorMessage,
        timestamp: DateTime.now(),
        latency: Duration(milliseconds: gateLatency),
      );
      sharedState['pipeline.error'] = 'Gate Check Step Failed: ${gateRes.errorMessage}';
      print('[PIPELINE RUN] ABORTED (Gate Check Step Failed)');
      print('============================================================');
      return sharedState;
    } else {
      statuses['GateCheck'] = EngineStatus(
        engine: 'GateCheck',
        state: 'CONNECTED',
        timestamp: DateTime.now(),
        latency: Duration(milliseconds: gateLatency),
      );
    }

    if (!gateOpen) {
      sharedState['pipeline.status'] = 'GATED';
      sharedState['interaction'] = {'status': 'skipped', 'reason': 'gate closed'};
      sharedState['ecom'] = {'status': 'skipped', 'reason': 'gate closed'};

      // Run Safety Memory Step anyway to persist context/recall
      final memoryStart = stopwatch.elapsedMilliseconds;
      final memoryRes = await memoryStep.execute(behaviorRes.output!, sharedState);
      final memoryLatency = stopwatch.elapsedMilliseconds - memoryStart;
      _telemetryService.recordLatency('SafetyMemory', memoryLatency);

      final memoryRawOutput = sharedState['memory'];
      final memoryIsMock = sharedState['memory_is_mock'] ?? false;
      print('[STEP 6] SafetyMemory (Gated Run) (Latency: ${memoryLatency}ms, Mock: $memoryIsMock)');
      print('  - Recall Request:');
      try {
        final recallPayload = {
          'query': behaviorRes.output!.gazeTarget,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        print('    ${jsonEncode(recallPayload)}');
      } catch (_) {}
      if (memoryRes.isSuccess) {
        print('  - Recall Response payload:');
        try {
          print('    ${jsonEncode(memoryRawOutput)}');
        } catch (_) {
          print('    $memoryRawOutput');
        }
      } else {
        print('  - FAILED: ${memoryRes.errorMessage}');
      }
      print('------------------------------------------------------------');

      if (!memoryRes.isSuccess) {
        statuses['SafetyMemory'] = EngineStatus(
          engine: 'SafetyMemory',
          state: 'ERROR',
          message: memoryRes.errorMessage,
          timestamp: DateTime.now(),
          latency: Duration(milliseconds: memoryLatency),
        );
        sharedState['pipeline.error'] = 'Memory Step Failed: ${memoryRes.errorMessage}';
      } else {
        statuses['SafetyMemory'] = EngineStatus(
          engine: 'SafetyMemory',
          state: 'CONNECTED',
          timestamp: DateTime.now(),
          latency: Duration(milliseconds: memoryLatency),
        );
      }

      stopwatch.stop();
      print('[PIPELINE RUN] COMPLETED (GATED - Skipped Interaction and Ecom)');
      print('  - Total Time: ${stopwatch.elapsedMilliseconds}ms');
      print('============================================================');
      return sharedState;
    }

    sharedState['pipeline.status'] = 'ACTIVE';

    print('[PIPELINE RUN] Executing Interaction, Ecom, and Memory in parallel...');

    final results = await Future.wait([
      () async {
        final start = stopwatch.elapsedMilliseconds;
        final res = await interactionStep.execute(behaviorRes.output!, sharedState);
        final latency = stopwatch.elapsedMilliseconds - start;
        _telemetryService.recordLatency('InteractionSubsystem', latency);
        return {'res': res, 'latency': latency};
      }(),
      () async {
        final start = stopwatch.elapsedMilliseconds;
        final res = await ecomStep.execute(behaviorRes.output!, sharedState);
        final latency = stopwatch.elapsedMilliseconds - start;
        _telemetryService.recordLatency('EcomAddHandler', latency);
        return {'res': res, 'latency': latency};
      }(),
      () async {
        final start = stopwatch.elapsedMilliseconds;
        final res = await memoryStep.execute(behaviorRes.output!, sharedState);
        final latency = stopwatch.elapsedMilliseconds - start;
        _telemetryService.recordLatency('SafetyMemory', latency);
        return {'res': res, 'latency': latency};
      }()
    ]);

    final interactionRes = results[0]['res'] as dynamic;
    final interactionLatency = results[0]['latency'] as int;
    
    final ecomRes = results[1]['res'] as dynamic;
    final ecomLatency = results[1]['latency'] as int;
    
    final memoryRes = results[2]['res'] as dynamic;
    final memoryLatency = results[2]['latency'] as int;

    // ------------------------------------------------------------------------
    // 4. Interaction Logging & Status
    // ------------------------------------------------------------------------
    final interactionRawOutput = sharedState['interaction'];
    final interactionIsMock = sharedState['interaction_is_mock'] ?? false;
    print('[STEP 4] InteractionSubsystem (Latency: ${interactionLatency}ms, Mock: $interactionIsMock)');
    print('  - Request:');
    try {
      final reqPayload = RequestMappers.toInteractionRequest(behaviorRes.output!, lat: lat, lon: lon);
      print('    ${jsonEncode(reqPayload)}');
    } catch (_) {
      print('    <Failed to map request payload>');
    }
    if (interactionRes.isSuccess) {
      print('  - Response payload:');
      try {
        print('    ${jsonEncode(interactionRawOutput)}');
      } catch (_) {
        print('    $interactionRawOutput');
      }
    } else {
      print('  - FAILED: ${interactionRes.errorMessage}');
    }
    print('------------------------------------------------------------');

    if (!interactionRes.isSuccess) {
      statuses['InteractionSubsystem'] = EngineStatus(
        engine: 'InteractionSubsystem',
        state: 'ERROR',
        message: interactionRes.errorMessage,
        timestamp: DateTime.now(),
        latency: Duration(milliseconds: interactionLatency),
      );
      sharedState['pipeline.error'] = 'Interaction Step Failed: ${interactionRes.errorMessage}';
      print('[PIPELINE RUN] ABORTED (Interaction Step Failed)');
      print('============================================================');
      return sharedState;
    } else {
      statuses['InteractionSubsystem'] = EngineStatus(
        engine: 'InteractionSubsystem',
        state: 'CONNECTED',
        timestamp: DateTime.now(),
        latency: Duration(milliseconds: interactionLatency),
      );
    }

    // ------------------------------------------------------------------------
    // 5. Ecom Ad Step Logging & Status
    // ------------------------------------------------------------------------
    final ecomRawOutput = sharedState['ecom'];
    final ecomIsMock = sharedState['ecom_is_mock'] ?? false;
    print('[STEP 5] EcomAddHandler (Latency: ${ecomLatency}ms, Mock: $ecomIsMock)');
    print('  - Request:');
    try {
      final reqPayload = RequestMappers.toEcomRequest(behaviorRes.output!);
      print('    ${jsonEncode(reqPayload)}');
    } catch (_) {
      print('    <Failed to map request payload>');
    }
    if (ecomRes.isSuccess) {
      print('  - Response payload:');
      try {
        print('    ${jsonEncode(ecomRawOutput)}');
      } catch (_) {
        print('    $ecomRawOutput');
      }
    } else {
      print('  - FAILED: ${ecomRes.errorMessage}');
    }
    print('------------------------------------------------------------');

    if (!ecomRes.isSuccess) {
      statuses['EcomAddHandler'] = EngineStatus(
        engine: 'EcomAddHandler',
        state: 'ERROR',
        message: ecomRes.errorMessage,
        timestamp: DateTime.now(),
        latency: Duration(milliseconds: ecomLatency),
      );
      sharedState['pipeline.error'] = 'Ecom Step Failed: ${ecomRes.errorMessage}';
      print('[PIPELINE RUN] ABORTED (Ecom Step Failed)');
      print('============================================================');
      return sharedState;
    } else {
      statuses['EcomAddHandler'] = EngineStatus(
        engine: 'EcomAddHandler',
        state: 'CONNECTED',
        timestamp: DateTime.now(),
        latency: Duration(milliseconds: ecomLatency),
      );
    }

    // ------------------------------------------------------------------------
    // 6. Safety Memory Step Logging & Status
    // ------------------------------------------------------------------------
    final memoryRawOutput = sharedState['memory'];
    final memoryIsMock = sharedState['memory_is_mock'] ?? false;
    print('[STEP 6] SafetyMemory (Latency: ${memoryLatency}ms, Mock: $memoryIsMock)');
    print('  - Recall Request:');
    try {
      final recallPayload = {
        'query': behaviorRes.output!.gazeTarget,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      print('    ${jsonEncode(recallPayload)}');
    } catch (_) {}
    if (memoryRes.isSuccess) {
      print('  - Recall Response payload:');
      try {
        print('    ${jsonEncode(memoryRawOutput)}');
      } catch (_) {
        print('    $memoryRawOutput');
      }
    } else {
      print('  - FAILED: ${memoryRes.errorMessage}');
    }
    print('------------------------------------------------------------');

    if (!memoryRes.isSuccess) {
      statuses['SafetyMemory'] = EngineStatus(
        engine: 'SafetyMemory',
        state: 'ERROR',
        message: memoryRes.errorMessage,
        timestamp: DateTime.now(),
        latency: Duration(milliseconds: memoryLatency),
      );
      sharedState['pipeline.error'] = 'Memory Step Failed: ${memoryRes.errorMessage}';
    } else {
      statuses['SafetyMemory'] = EngineStatus(
        engine: 'SafetyMemory',
        state: 'CONNECTED',
        timestamp: DateTime.now(),
        latency: Duration(milliseconds: memoryLatency),
      );
    }

    stopwatch.stop();
    print('[PIPELINE RUN] COMPLETED SUCCESSFULLY IN PARALLEL');
    print('  - Total Time: ${stopwatch.elapsedMilliseconds}ms');
    print('============================================================');
    return sharedState;
  }
}


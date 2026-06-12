import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/config/env_config.dart';
import 'package:smartglass_flutter/core/sources/source_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import '../dashboard/widgets/action_hub_tab.dart';

class EngineInspectorScreen extends StatelessWidget {
  const EngineInspectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    // Get circuit breaker states from health monitor
    final contextState = session.healthMonitor.contextState;
    final behaviorState = session.healthMonitor.behaviorState;
    final interactionState = session.healthMonitor.interactionState;
    final ecomState = session.healthMonitor.ecomState;
    final memoryState = session.healthMonitor.memoryState;

    // Get latencies from telemetry
    final contextLatency = session.telemetryService.latencies['ContextEngine']?.toDouble() ?? 0.0;
    final behaviorLatency = session.telemetryService.latencies['BehaviorEngine']?.toDouble() ?? 0.0;
    final interactionLatency = session.telemetryService.latencies['InteractionSubsystem']?.toDouble() ?? 0.0;
    final ecomLatency = session.telemetryService.latencies['EcomAddHandler']?.toDouble() ?? 0.0;
    final memoryLatency = session.telemetryService.latencies['SafetyMemory']?.toDouble() ?? 0.0;

    final sharedState = session.state.modelContext ?? {};

    // Get mock flags (check if step fell back to mock due to network/configuration issues)
    final contextIsMock = sharedState['context_is_mock'] == true || session.sourceManager.activeType == SourceType.mock;
    final behaviorIsMock = sharedState['behavior_is_mock'] == true || EnvConfig.behaviourIntentUrl.isEmpty;
    final interactionIsMock = sharedState['interaction_is_mock'] == true;
    final ecomIsMock = sharedState['ecom_is_mock'] == true;
    final memoryIsMock = sharedState['memory_is_mock'] == true || EnvConfig.safetyMemoryUrl.isEmpty;

    // Dynamically retrieve requests & responses from model context
    final contextReq = {
      'audio_level': session.state.audioLevel,
      'location': {
        'latitude': session.state.latitude ?? 0.0,
        'longitude': session.state.longitude ?? 0.0,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final contextRes = sharedState['context'] as Map<String, dynamic>?;

    final behaviorReq = sharedState['context'] != null ? {'context_data': sharedState['context']} : null;
    final behaviorRes = sharedState['behavior'] as Map<String, dynamic>?;

    final interactionReq = sharedState['behavior'] != null 
        ? {
            'dialogue_mode': 'query',
            'utterance': 'User looking at ${session.state.lastBIEFrame?.gazeTarget}',
            'bcp': {
              'relevance_score': session.state.lastBIEFrame?.salienceScore,
              'behavioral_state': session.state.lastBIEFrame?.intent,
            }
          }
        : null;
    final interactionRes = sharedState['interaction'] as Map<String, dynamic>?;

    final ecomReq = session.state.lastBIEFrame != null 
        ? {
            'gaze_target': session.state.lastBIEFrame!.gazeTarget,
            'intent_scoring': {
              'salience_score': session.state.lastBIEFrame!.salienceScore,
              'class_name': session.state.lastBIEFrame!.gazeTarget,
            }
          }
        : null;
    final ecomRes = sharedState['ecom'] as Map<String, dynamic>?;

    final memoryReq = session.state.lastBIEFrame != null
        ? {
            'query': session.state.lastBIEFrame!.gazeTarget,
            'store_intent': session.state.lastBIEFrame!.intent,
          }
        : null;
    final memoryRes = sharedState['memory'] as Map<String, dynamic>?;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Engine Inspector', style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reset Circuits',
              onPressed: () {
                session.healthMonitor.resetAllCircuits();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All engine circuit breakers reset.')),
                );
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.onSurfaceVariant,
            tabs: const [
              Tab(text: 'Context'),
              Tab(text: 'Behavior'),
              Tab(text: 'Interaction'),
              Tab(text: 'Ecom'),
              Tab(text: 'Memory'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Context Tab
            _InspectorTab(
              name: 'Context Engine',
              state: contextState,
              latencyMs: contextLatency,
              isMock: contextIsMock,
              errorMessage: sharedState['context_error']?.toString(),
              requestJson: contextReq,
              responseJson: contextRes,
              extraWidgets: [
                if (session.state.lastContextOutput != null) ...[
                  const SizedBox(height: 16),
                  _InfoPanel(
                    title: 'Scene Detection Details',
                    children: [
                      _InfoRow(label: 'Scene context', value: session.state.lastContextOutput!.sceneContext),
                      _InfoRow(label: 'Tracked objects', value: session.state.lastContextOutput!.trackedObjects.join(', ')),
                      _InfoRow(label: 'Top salient objects', value: session.state.lastContextOutput!.topSalientObjects.join(', ')),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _InfoPanel(
                  title: 'Location Context',
                  children: [
                    _InfoRow(
                      label: 'Current Location',
                      value: '${session.state.city ?? "Unknown"}, Lat: ${session.state.latitude?.toStringAsFixed(4) ?? '0.0'}, Lon: ${session.state.longitude?.toStringAsFixed(4) ?? '0.0'}',
                    ),
                  ],
                ),
              ],
            ),
 
            // Behavior Tab
            _InspectorTab(
              name: 'Behavior Engine',
              state: behaviorState,
              latencyMs: behaviorLatency,
              isMock: behaviorIsMock,
              errorMessage: sharedState['behavior_error']?.toString(),
              requestJson: behaviorReq,
              responseJson: behaviorRes,
              extraWidgets: [
                if (session.state.lastBIEFrame != null) ...[
                  const SizedBox(height: 16),
                  _InfoPanel(
                    title: 'salience objects',
                    children: [
                      _InfoRow(label: 'Predicted intent', value: session.state.lastBIEFrame!.intent),
                      _InfoRow(label: 'Confidence level', value: '${(session.state.lastBIEFrame!.confidence * 100).toStringAsFixed(1)}%'),
                      _InfoRow(label: 'Gaze grounding target', value: session.state.lastBIEFrame!.gazeTarget),
                      _InfoRow(label: 'Product salience score', value: session.state.lastBIEFrame!.salienceScore.toStringAsFixed(2)),
                    ],
                  ),
                ],
              ],
            ),
 
            // Interaction Tab
            _InspectorTab(
              name: 'Interaction Subsystem',
              state: interactionState,
              latencyMs: interactionLatency,
              isMock: interactionIsMock,
              errorMessage: sharedState['interaction_error']?.toString(),
              requestJson: interactionReq,
              responseJson: interactionRes,
              extraWidgets: [
                if (session.state.lastInteractionResponse != null) ...[
                  const SizedBox(height: 16),
                  _InfoPanel(
                    title: 'Interaction Gating Status',
                    children: [
                      _InfoRow(label: 'Dialogue mode', value: session.state.lastInteractionResponse!.dialogueMode),
                      _InfoRow(label: 'LLM Gate status', value: session.state.lastInteractionResponse!.llmGateStatus),
                      _InfoRow(
                        label: 'Gating Verdict',
                        value: sharedState['gate_open'] == true ? 'OPEN' : 'CLOSED',
                        valueColor: sharedState['gate_open'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                      _InfoRow(label: 'Gating reason', value: sharedState['gate_reason']?.toString() ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Live Generating Dialogues',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.outline.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            session.state.lastInteractionResponse!.lastUtterance.isNotEmpty
                                ? session.state.lastInteractionResponse!.lastUtterance
                                : 'Awaiting input...',
                            style: TextStyle(
                              color: AppTheme.onSurface,
                              fontSize: 14,
                              fontStyle: session.state.lastInteractionResponse!.lastUtterance.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
 
            // Ecom Tab
            _InspectorTab(
              name: 'Action Hub Subsystem',
              state: ecomState,
              latencyMs: ecomLatency,
              isMock: ecomIsMock,
              errorMessage: sharedState['ecom_error']?.toString(),
              requestJson: ecomReq,
              responseJson: ecomRes,
              extraWidgets: [
                const SizedBox(height: 16),
                ActionHubTab(actionHubResult: session.state.actionHubResult),
              ],
            ),
 
            // Memory Tab
            _InspectorTab(
              name: 'Safety Memory Subsystem',
              state: memoryState,
              latencyMs: memoryLatency,
              isMock: memoryIsMock,
              errorMessage: sharedState['memory_error']?.toString(),
              requestJson: memoryReq,
              responseJson: memoryRes,
              extraWidgets: [
                if (session.state.lastMemoryResponse != null) ...[
                  const SizedBox(height: 16),
                  _InfoPanel(
                    title: 'Recalled Safety Memories',
                    children: [
                      _InfoRow(label: 'Recall status', value: session.state.lastMemoryResponse!.status),
                      _InfoRow(label: 'Data recalled', value: session.state.lastMemoryResponse!.recallData),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectorTab extends StatelessWidget {
  final String name;
  final CircuitState state;
  final double latencyMs;
  final bool isMock;
  final String? errorMessage;
  final Map<String, dynamic>? requestJson;
  final Map<String, dynamic>? responseJson;
  final List<Widget> extraWidgets;

  const _InspectorTab({
    required this.name,
    required this.state,
    required this.latencyMs,
    required this.isMock,
    this.errorMessage,
    required this.requestJson,
    required this.responseJson,
    this.extraWidgets = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EngineStatusCard(
          name: name,
          state: state,
          latencyMs: latencyMs,
          isMock: isMock,
          errorMessage: errorMessage,
        ),
        const SizedBox(height: 16),
        ...extraWidgets,
        const SizedBox(height: 16),
        JsonViewer(title: 'Request Payload JSON', json: requestJson),
        JsonViewer(title: 'Response Payload JSON', json: responseJson),
      ],
    );
  }
}

class EngineStatusCard extends StatelessWidget {
  final String name;
  final CircuitState state;
  final double latencyMs;
  final bool isMock;
  final String? errorMessage;

  const EngineStatusCard({
    super.key,
    required this.name,
    required this.state,
    required this.latencyMs,
    required this.isMock,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    switch (state) {
      case CircuitState.closed:
        statusColor = const Color(0xFF10B981);
        statusLabel = 'CLOSED (HEALTHY)';
        break;
      case CircuitState.halfOpen:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'HALF-OPEN (TESTING)';
        break;
      case CircuitState.open:
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'OPEN (TRIPPED)';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: AppTheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Latency: ',
                style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
              ),
              Text(
                '${latencyMs.toStringAsFixed(1)} ms',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const Spacer(),
              Icon(Icons.settings_suggest_outlined, size: 16, color: AppTheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Mode: ',
                style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
              ),
              Text(
                isMock ? 'Mock Fallback' : 'Real Deployment',
                style: TextStyle(
                  color: isMock ? const Color(0xFF8B5CF6) : AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (errorMessage != null && errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Error: $errorMessage',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class JsonViewer extends StatefulWidget {
  final Map<String, dynamic>? json;
  final String title;

  const JsonViewer({super.key, required this.json, required this.title});

  @override
  State<JsonViewer> createState() => _JsonViewerState();
}

class _JsonViewerState extends State<JsonViewer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String formattedJson = widget.json != null
        ? const JsonEncoder.withIndent('  ').convert(widget.json)
        : '{}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              widget.title,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            trailing: IconButton(
              icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A), // Slate 900
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: SelectableText(
                formattedJson,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF38BDF8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoPanel({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value.isNotEmpty ? value : 'None',
              style: TextStyle(
                color: valueColor ?? AppTheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _GridCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              subtitle,
              style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 10),
              maxLines: 15,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:smartglass_flutter/core/engines/shared/circuit_breaker.dart';
import 'package:smartglass_flutter/core/models/engine_status.dart';
class ApiConnectivityPanel extends StatelessWidget {
  const ApiConnectivityPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final state = session.state;
    final apiHealths = state.apiHealths;

    final hasErrors = apiHealths.any((api) => !api.reachable || api.circuit == CircuitState.open);
    final overallColor = hasErrors ? AppTheme.error : const Color(0xFF22C55E);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_tethering_rounded, color: overallColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'API Connectivity & Health',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                if (hasErrors)
                  const BlinkingWarningIndicator()
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ALL HEALTHY',
                      style: TextStyle(
                        color: Color(0xFF1B5E20),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24, thickness: 0.5),
            if (apiHealths.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Running initial health checks...',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  horizontalMargin: 4,
                  columnSpacing: 16,
                  headingRowHeight: 32,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 52,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Engine',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Endpoint',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Latency',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Error',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                  rows: apiHealths.map((api) {
                    final statusWidget = _buildStatusBadge(
                      context,
                      api,
                      session.streamCoordinator.isPipelineBusy,
                    );
                    final latencyVal = api.latency.inMilliseconds;
                    final latencyStr = api.reachable ? '${latencyVal}ms' : '—';
                    final portStr =
                        api.endpoint.port != 0 ? api.endpoint.port.toString() : api.endpoint.host;

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            api.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Text(
                            portStr,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        DataCell(statusWidget),
                        DataCell(Text(latencyStr, style: const TextStyle(fontSize: 12))),
                        DataCell(
                          Text(
                            api.lastError ?? '—',
                            style: TextStyle(
                              color: api.lastError != null ? AppTheme.error : Colors.grey,
                              fontSize: 11,
                              fontStyle: api.lastError != null ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, ApiHealth api, bool isPipelineBusy) {
    Color indicatorColor;
    String statusLabel;
    bool isPulse = false;

    if (api.circuit == CircuitState.open) {
      indicatorColor = AppTheme.error;
      statusLabel = 'OFFLINE';
    } else if (api.circuit == CircuitState.halfOpen) {
      indicatorColor = const Color(0xFFF59E0B);
      statusLabel = 'RETRYING';
      isPulse = true;
    } else {
      if (!api.reachable) {
        indicatorColor = AppTheme.error;
        statusLabel = 'ERROR';
      } else if (isPipelineBusy) {
        indicatorColor = const Color(0xFF3B82F6);
        statusLabel = 'ACTIVE';
        isPulse = true;
      } else {
        indicatorColor = const Color(0xFF22C55E);
        statusLabel = 'CONNECTED';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: indicatorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(color: indicatorColor, isPulse: isPulse),
          const SizedBox(width: 4),
          Text(
            statusLabel,
            style: TextStyle(
              color: indicatorColor,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusDot extends StatefulWidget {
  final Color color;
  final bool isPulse;

  const StatusDot({super.key, required this.color, required this.isPulse});

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPulse && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPulse) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.2 + (_controller.value * 0.8)),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4),
                  blurRadius: 4 * _controller.value,
                  spreadRadius: 2 * _controller.value,
                ),
              ],
            ),
          );
        },
      );
    } else {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      );
    }
  }
}

class BlinkingWarningIndicator extends StatefulWidget {
  const BlinkingWarningIndicator({super.key});

  @override
  State<BlinkingWarningIndicator> createState() => _BlinkingWarningIndicatorState();
}

class _BlinkingWarningIndicatorState extends State<BlinkingWarningIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: _controller.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 12),
                SizedBox(width: 4),
                Text(
                  'MISCOMMUNICATION',
                  style: TextStyle(color: AppTheme.error, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

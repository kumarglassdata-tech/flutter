import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';

class MynaAssistantBottomSheet extends StatelessWidget {
  const MynaAssistantBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final auth = context.watch<AuthProvider>();
    final state = session.state;

    final String username = auth.username.isNotEmpty ? auth.username : 'User';
    final String greeting = 'Hi $username, How can I help you today?';
    
    final String lastUtterance = (state.lastInteractionResponse != null && state.lastInteractionResponse!.lastUtterance.isNotEmpty)
        ? state.lastInteractionResponse!.lastUtterance
        : greeting;

    final String ecomStatus = (state.lastEcomResponse?.suggestions.isNotEmpty ?? false)
        ? '${state.lastEcomResponse!.suggestions.length} suggestions'
        : 'Idle';

    final String recommendStatus = (state.lastEcomResponse != null)
        ? 'Active'
        : 'Idle';

    final String behaviorStatus = state.lastBIEFrame?.intent.toUpperCase() ?? 'NONE';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: Image.asset(
                    "assets/images/myna_bot.png",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text(
                          "MYNA Assistant",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: Colors.green,
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.isSessionActive ? "Listening..." : "Idle",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            lastUtterance,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            "Live Insights",
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _MetricRow(icon: Icons.shopping_bag, label: 'Ecom Suggestions', value: ecomStatus),
          _MetricRow(icon: Icons.auto_awesome, label: 'AI Recommend', value: recommendStatus),
          _MetricRow(icon: Icons.directions_run, label: 'Behavior State', value: behaviorStatus),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onLongPressStart: (_) => context.read<SessionProvider>().audioStreamManager.startRecording(),
              onLongPressEnd: (_) => context.read<SessionProvider>().audioStreamManager.stopRecording(),
              onLongPressCancel: () => context.read<SessionProvider>().audioStreamManager.stopRecording(),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2563EB),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 4),
                  ],
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              "Press and Hold to Speak",
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3B82F6), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

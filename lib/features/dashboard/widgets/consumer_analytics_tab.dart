import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

class ConsumerAnalyticsTab extends StatelessWidget {
  const ConsumerAnalyticsTab({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final settings = context.watch<SettingsProvider>();
    final state = session.state;
    final lastBie = state.lastBIEFrame;
    
    // Fallback values if nothing is scanned yet
    final target = (lastBie?.gazeTarget != null && lastBie!.gazeTarget != 'unknown')
        ? lastBie.gazeTarget.replaceAll('_', ' ').toUpperCase() 
        : 'SCANNING ENVIRONMENT...';
    
    final salience = lastBie?.salienceScore ?? 0.0;
    final interestScore = (salience * 100).toInt();
    final thresholdInt = (settings.salienceThreshold * 100).toInt();
    
    final suggestions = state.suggestedProducts ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Product Focus Header
          _buildGlassCard(
            child: Column(
              children: [
                const Icon(Icons.center_focus_strong_rounded, size: 48, color: AppTheme.primary),
                const SizedBox(height: 12),
                Text(
                  'CURRENT FOCUS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: AppTheme.primary.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  target,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                // Interest Gauge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: salience,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            color: interestScore >= thresholdInt ? Colors.green : (interestScore > 50 ? Colors.orange : AppTheme.primary),
                          ),
                          Center(
                            child: Text(
                              '$interestScore%',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Interest Score',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          interestScore >= thresholdInt ? 'High Intent Detected' : 'Passive Observation',
                          style: TextStyle(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

          const SizedBox(height: 16),

          // 2. Cross Platform Comparison (Action Hub Links)
          const Text(
            'Cross-Platform Pricing',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),
          
          if (suggestions.isEmpty)
            _buildGlassCard(
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Focus on a product to see live pricing comparisons.', textAlign: TextAlign.center),
              ),
            ).animate().fadeIn(delay: 200.ms)
          else
            ...suggestions.map((product) {
              final isAmazon = product.id.contains('amazon');
              final isWalmart = product.id.contains('walmart');
              final platformName = isAmazon ? 'Amazon' : (isWalmart ? 'Walmart' : 'Store');
              final iconColor = isAmazon ? Colors.orange : (isWalmart ? Colors.blue : Colors.black);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildGlassCard(
                  padding: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withOpacity(0.1),
                      child: Icon(Icons.shopping_bag_rounded, color: iconColor),
                    ),
                    title: Text(platformName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: ElevatedButton.icon(
                      onPressed: () => _launchUrl(product.id),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text('\$${product.price.toStringAsFixed(2)}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.05);
            }),

          const SizedBox(height: 24),

          // 3. Life Balance Metrics (Mocked for Demo as per architecture)
          const Text(
            'Life Balance Impact',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 12),
          
          _buildGlassCard(
            child: Column(
              children: [
                _buildLifeBalanceRow(Icons.eco_rounded, 'Eco-Friendly', 85, Colors.green),
                const SizedBox(height: 12),
                _buildLifeBalanceRow(Icons.health_and_safety_rounded, 'Health Rating', 92, Colors.blue),
                const SizedBox(height: 12),
                _buildLifeBalanceRow(Icons.account_balance_wallet_rounded, 'Budget Fit', 60, Colors.orange),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLifeBalanceRow(IconData icon, String label, int score, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('$score%', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: color.withOpacity(0.1),
                  color: color,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(20)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

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
    final lastEcom = state.lastEcomResponse;
    
    final target = (lastBie?.gazeTarget != null && lastBie!.gazeTarget != 'unknown')
        ? lastBie.gazeTarget.replaceAll('_', ' ').toUpperCase() 
        : 'SCANNING ENVIRONMENT...';
    
    final salience = lastBie?.salienceScore ?? 0.0;
    final interestScore = (salience * 100).toInt();
    final thresholdInt = (settings.salienceThreshold * 100).toInt();
    
    final suggestions = state.suggestedProducts ?? [];
    final analyzeData = lastEcom?.analyzeData;
    final lifeBalanceData = lastEcom?.lifeBalanceData;

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
                          interestScore >= thresholdInt ? 'High Intent Detected' : 'Passive Browsing',
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

          const SizedBox(height: 24),

          // 2. Life Balance Index
          if (lifeBalanceData != null) ...[
            const Text(
              'Life Balance Index',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 12),
            _buildLifeBalanceCard(lifeBalanceData).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
            const SizedBox(height: 24),
          ],

          // 3. Platform ROI Analytics
          if (analyzeData != null && analyzeData.platforms.isNotEmpty) ...[
            const Text(
              'Campaign Performance',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: analyzeData.platforms.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: _buildPlatformAnalyticsCard(analyzeData.platforms[index]),
                  ).animate().fadeIn(delay: Duration(milliseconds: 300 + (index * 100))).slideX(begin: 0.1);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 4. Mall Feed
          const Text(
            'Live Mall Feed',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 12),
          
          if (suggestions.isEmpty)
            _buildGlassCard(
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Awaiting contextual signals to generate feed...', textAlign: TextAlign.center),
              ),
            ).animate().fadeIn(delay: 400.ms)
          else
            ...suggestions.map((product) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildProductCard(product),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05);
            }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProductCard(EcomAdProduct product) {
    final platformLower = product.platform?.toLowerCase() ?? '';
    final isAmazon = platformLower.contains('amazon');
    final isFlipkart = platformLower.contains('flipkart');
    final iconColor = isAmazon ? Colors.orange : (isFlipkart ? Colors.blue : Colors.black87);
    
    return _buildGlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _launchUrl(product.id),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (product.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  product.imageUrl,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(height: 140, child: Center(child: Icon(Icons.image_not_supported))),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          product.price > 0 ? '\$${product.price.toStringAsFixed(0)}' : 'N/A',
                          style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primary, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (product.platform != null)
                        _buildBadge(Icons.storefront, product.platform!, iconColor),
                      if (product.rating != null && product.rating! > 0)
                        _buildBadge(Icons.star_rounded, product.rating.toString(), Colors.amber.shade700),
                      if (product.delivery != null && product.delivery!.isNotEmpty)
                        _buildBadge(Icons.local_shipping_rounded, product.delivery!, Colors.green),
                      if (product.offer != null && product.offer!.isNotEmpty)
                        _buildBadge(Icons.local_offer_rounded, product.offer!, Colors.redAccent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildPlatformAnalyticsCard(PlatformAnalytics analytics) {
    return _buildGlassCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_rounded, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  analytics.platform,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
            const Divider(),
            _buildStatRow('ROAS', analytics.roas, Icons.trending_up_rounded),
            _buildStatRow('ROI', analytics.roi, Icons.percent_rounded),
            _buildStatRow('Ad Spend', analytics.adSpend, Icons.attach_money_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant)),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildLifeBalanceCard(LifeBalanceResponse data) {
    return _buildGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 80,
                        width: 80,
                        child: CircularProgressIndicator(
                          value: data.score / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          color: data.score > 80 ? Colors.green : (data.score > 50 ? Colors.orange : Colors.red),
                        ),
                      ),
                      Text(
                        '${data.score}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Wellness Score', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notifications_active_rounded, size: 16, color: Colors.amber),
                            SizedBox(width: 4),
                            Text('AI Observation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.primaryNotification,
                          style: TextStyle(fontSize: 12, color: AppTheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...data.breakdown.entries.map((e) {
            Color c = Colors.blue;
            if (e.key.toLowerCase().contains('family')) c = Colors.purple;
            if (e.key.toLowerCase().contains('fitness')) c = Colors.green;
            if (e.key.toLowerCase().contains('work')) c = Colors.orange;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildLifeBalanceRow(Icons.adjust_rounded, e.key, e.value.toInt(), c),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLifeBalanceRow(IconData icon, String label, int score, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('$score%', style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: color.withOpacity(0.1),
                  color: color,
                  minHeight: 4,
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

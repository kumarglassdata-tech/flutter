import 'package:flutter/material.dart';
import 'package:smartglass_flutter/core/models/domain/action_hub_result.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ActionHubTab extends StatelessWidget {
  final ActionHubResult? actionHubResult;

  const ActionHubTab({super.key, this.actionHubResult});

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (actionHubResult == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: AppTheme.outline),
            SizedBox(height: 16),
            Text('Awaiting E-Commerce Data...',
                style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 16)),
          ],
        ),
      );
    }

    final endpoint = actionHubResult!.actionEndpoint;
    final payload = actionHubResult!.generatedPayload;

    IconData titleIcon = Icons.shopping_bag_rounded;
    Color headerColor = AppTheme.primary;
    String headerText = 'Action Hub Result';

    if (endpoint.contains('recommend') || endpoint.contains('buy')) {
      titleIcon = Icons.auto_awesome_rounded;
      headerColor = Colors.amber;
      headerText = 'Shopping AI Recommendation';
    } else if (endpoint.contains('compare')) {
      titleIcon = Icons.compare_arrows_rounded;
      headerColor = Colors.blue;
      headerText = 'Product Comparison';
    } else if (endpoint.contains('lifebalance')) {
      titleIcon = Icons.monitor_heart_rounded;
      headerColor = Colors.green;
      headerText = 'LifeBalance Analytics';
    } else if (endpoint.contains('analyze')) {
      titleIcon = Icons.analytics_rounded;
      headerColor = Colors.purple;
      headerText = 'Ad Deep Analysis';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: headerColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(titleIcon, color: headerColor),
                const SizedBox(width: 12),
                Text(
                  headerText,
                  style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                  child: Text(endpoint, style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Route to specific UI parser based on endpoint
          if (endpoint.contains('lifebalance'))
            _buildLifeBalanceView(payload)
          else if (endpoint.contains('analyze'))
            _buildAnalyzeView(payload)
          else
            _buildShoppingView(payload),
        ],
      ),
    );
  }

  Widget _buildShoppingView(Map<String, dynamic> payload) {
    final List<dynamic>? mallFeed = payload['mall_feed'];
    final Map<String, dynamic>? adContent = payload['ad_content'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (adContent != null) ...[
          const Text('Featured Deal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
          const SizedBox(height: 12),
          _buildAdCard(adContent),
          const SizedBox(height: 24),
        ],
        if (mallFeed != null && mallFeed.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.local_mall_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Smart Recommendations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mallFeed.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = mallFeed[index] as Map<String, dynamic>;
              return _buildProductCard(item);
            },
          ),
        ],
        if (mallFeed == null && adContent == null)
          const Center(child: Text('No structured product data found in payload.', style: TextStyle(color: AppTheme.onSurfaceVariant))),
      ],
    );
  }

  Widget _buildLifeBalanceView(Map<String, dynamic> payload) {
    final score = payload['life_balance_score']?.toString() ?? 'N/A';
    final observations = payload['observations'] as List<dynamic>? ?? [];
    final notifications = payload['notifications'] as List<dynamic>? ?? [];
    final breakdown = payload['breakdown'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withValues(alpha: 0.1),
              border: Border.all(color: Colors.green, width: 4),
            ),
            child: Column(
              children: [
                const Text('Score', style: TextStyle(fontSize: 14, color: Colors.green)),
                Text(score, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.green)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        if (notifications.isNotEmpty) ...[
          const Text('Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
          const SizedBox(height: 12),
          ...notifications.map((n) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(child: Text(n['message'] ?? '', style: const TextStyle(color: AppTheme.onSurface))),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
        if (observations.isNotEmpty) ...[
          const Text('Observations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
          const SizedBox(height: 12),
          ...observations.map((obs) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(obs.toString(), style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
              )),
          const SizedBox(height: 24),
        ],
        if (breakdown.isNotEmpty) ...[
          const Text('Balance Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: breakdown.entries.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(12)),
              child: Text('${e.key}: ${e.value}', style: const TextStyle(fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalyzeView(Map<String, dynamic> payload) {
    final platforms = payload['platforms'] as Map<String, dynamic>? ?? {};
    final suppressions = payload['suppressions']?.toString() ?? '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
          child: Row(
            children: [
              const Icon(Icons.block_rounded, color: Colors.red, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Suppressions', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  Text(suppressions, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.red)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Platform Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
        const SizedBox(height: 16),
        ...platforms.entries.map((e) {
          final p = e.value as Map<String, dynamic>;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.outline.withValues(alpha: 0.1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetric('Spend', p['ad_spend']?.toString() ?? '0', Icons.attach_money),
                    _buildMetric('ROAS', p['roas']?.toString() ?? '0', Icons.trending_up),
                    _buildMetric('ROI', p['roi']?.toString() ?? '0', Icons.percent),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetric('Impressions', p['impressions']?.toString() ?? '0', Icons.visibility),
                    _buildMetric('Clicks', p['clicks']?.toString() ?? '0', Icons.ads_click),
                    _buildMetric('CTR', p['ctr']?.toString() ?? '0', Icons.mouse),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppTheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final image = ad['image_url'] ?? '';
    final title = ad['product'] ?? ad['headline'] ?? 'Special Offer';
    final price = ad['price'] != null ? '₹${ad['price']}' : '';
    final reason = ad['reason'] ?? '';
    final link = ad['action_link'] ?? '';

    return GestureDetector(
      onTap: () => _launchUrl(link),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2C1654), Color(0xFF130926)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 2)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image.isNotEmpty)
              Image.network(image, height: 160, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(height: 100, color: Colors.black26)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
                      if (price.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                          child: Text(price, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (reason.isNotEmpty)
                    Text(reason, style: const TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item) {
    final image = item['image_url'] ?? '';
    final title = item['product'] ?? item['title'] ?? 'Unknown Product';
    final price = item['price'] ?? '';
    final platform = item['platform'] ?? 'Store';
    final rating = item['rating']?.toString() ?? '-';
    final offer = item['offer'] ?? '';
    final delivery = item['delivery'] ?? '';
    final link = item['link'] ?? '';

    return GestureDetector(
      onTap: () => _launchUrl(link),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outline.withValues(alpha: 0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image.isNotEmpty)
              SizedBox(
                width: 120,
                height: 140,
                child: Image.network(image, fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(color: Colors.black12, child: const Icon(Icons.image_not_supported, color: Colors.white24))),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                        const Spacer(),
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(rating, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildBadge(platform, Icons.storefront_rounded, Colors.blue),
                        if (offer.isNotEmpty) _buildBadge(offer, Icons.local_offer_rounded, Colors.green),
                        if (delivery.isNotEmpty) _buildBadge(delivery, Icons.local_shipping_rounded, Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

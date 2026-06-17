import 'package:flutter/material.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class NormalUserCards extends StatelessWidget {
  final SessionState state;

  const NormalUserCards({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildLocationCard(),
        const SizedBox(height: 12),
        _buildObjectCard(context),
        const SizedBox(height: 12),
        _buildBehaviorCard(),
        const SizedBox(height: 12),
        _buildInteractionCard(),
        const SizedBox(height: 12),
        _buildSuggestionsCard(context),
      ],
    );
  }

  Widget _buildLocationCard() {
    final lat = state.latitude;
    final lon = state.longitude;
    final locationText = (lat != null && lon != null) 
        ? '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}' 
        : 'Unknown Location';

    return _buildCard(
      icon: Icons.location_on_rounded,
      iconColor: Colors.redAccent,
      title: 'Current Location',
      content: locationText,
    );
  }

  Widget _buildObjectCard(BuildContext context) {
    final gazeTarget = state.lastBIEFrame?.gazeTarget ?? 'None';
    final salientObjects = state.topSalientObjects.join(', ');

    VoidCallback? onTap;
    if (state.suggestedProducts.isNotEmpty) {
      onTap = () => _launchWithWait(context, state.suggestedProducts.first.id);
    }

    return _buildCard(
      icon: Icons.center_focus_strong_rounded,
      iconColor: Colors.blueAccent,
      title: 'Detected Object',
      content: gazeTarget != 'unknown' ? gazeTarget : (salientObjects.isNotEmpty ? salientObjects : 'No salient objects'),
      onTap: onTap,
    );
  }

  Widget _buildBehaviorCard() {
    final behavioralState = state.lastBIEFrame?.behavioralState ?? 'Idle';
    final stateConfidence = state.lastBIEFrame?.stateConfidence ?? 0.0;
    final intentScore = state.lastBIEFrame?.intentScore ?? 0.0;
    final commerceRelevance = state.lastBIEFrame?.salienceScore ?? 0.0;

    return _buildCard(
      icon: Icons.psychology_rounded,
      iconColor: Colors.deepPurpleAccent,
      title: 'Behavioral State Analysis',
      content: '$behavioralState  (conf: ${(stateConfidence * 100).toStringAsFixed(0)}%)\nIntent Score: ${(intentScore * 100).toStringAsFixed(0)}%  |  Relevance: ${(commerceRelevance * 100).toStringAsFixed(0)}%',
    );
  }

  Widget _buildInteractionCard() {
    final utterance = state.lastInteractionResponse?.lastUtterance ?? 'Awaiting interaction...';

    return _buildCard(
      icon: Icons.record_voice_over_rounded,
      iconColor: Colors.teal,
      title: 'Interaction Response',
      content: utterance,
    );
  }

  Widget _buildSuggestionsCard(BuildContext context) {
    final suggestions = state.suggestedProducts;
    
    if (suggestions.isEmpty) {
      return _buildCard(
        icon: Icons.shopping_bag_rounded,
        iconColor: Colors.orangeAccent,
        title: 'Product Suggestions',
        content: 'No suggestions available yet.',
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.shopping_bag_rounded, color: Colors.orangeAccent),
                    SizedBox(width: 8),
                    Text('Product Suggestions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                TextButton(
                  onPressed: () => GoRouter.of(context).push('/interested'),
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...suggestions.take(2).map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () => _launchWithWait(context, p.id),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      if (p.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(p.imageUrl, width: 40, height: 40, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 40),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('\$${p.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, color: AppTheme.primary, size: 20),
                        onPressed: () => _launchWithWait(context, p.id),
                      ),
                    ],
                  ),
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  void _launchWithWait(BuildContext context, String productUrl) async {
    if (productUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No e-commerce links found for this product.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final uri = Uri.tryParse(productUrl);
    if (uri != null && uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, redirecting to the page...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.teal,
        ),
      );
      Future.delayed(const Duration(seconds: 2), () async {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not launch the link.'), backgroundColor: Colors.redAccent),
            );
          }
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid product link.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Widget _buildCard({required IconData icon, required Color iconColor, required String title, required String content, VoidCallback? onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(content, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

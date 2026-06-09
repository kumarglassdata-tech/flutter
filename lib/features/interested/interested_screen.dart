import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/navigation/back_navigation.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class InterestedScreen extends StatelessWidget {
  const InterestedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionProvider>().state;
    final items = state.suggestedProducts;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => goBackOr(context, '/home'),
        ),
        title: const Text('Interested Items', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: items.isEmpty
          ? const Center(child: Text('No interested items yet.', style: TextStyle(color: AppTheme.onSurfaceVariant)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.8,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final product = items[i];
                return GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(product.id);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: product.imageUrl.isNotEmpty
                                  ? Image.network(product.imageUrl, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported, size: 48, color: AppTheme.primary)))
                                  : const Center(child: Icon(Icons.shopping_bag_rounded, size: 48, color: AppTheme.primary)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Icon(Icons.open_in_new_rounded, color: AppTheme.primary, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: i * 100), duration: 400.ms),
                );
              },
            ),
    );
  }
}

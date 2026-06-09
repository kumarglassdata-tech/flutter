import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartglass_flutter/core/navigation/back_navigation.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = [
      ('Smart Glasses Pro', 'Delivered', '22 May 2026', '\$199.00', Icons.visibility_rounded),
      ('Wireless Earbuds', 'Processing', '28 May 2026', '\$89.00', Icons.headset_rounded),
      ('Fitness Band', 'Shipped', '30 May 2026', '\$49.00', Icons.watch_rounded),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => goBackOr(context, '/home'),
        ),
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final (name, status, date, price, icon) = orders[i];
          Color statusColor;
          switch (status) {
            case 'Delivered':
              statusColor = const Color(0xFF22C55E);
            case 'Shipped':
              statusColor = const Color(0xFF3B82F6);
            default:
              statusColor = const Color(0xFFF59E0B);
          }
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: AppTheme.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(date,
                            style: const TextStyle(
                                color: AppTheme.onSurfaceVariant, fontSize: 12)),
                        Text(price,
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: i * 100), duration: 400.ms);
        },
      ),
    );
  }
}

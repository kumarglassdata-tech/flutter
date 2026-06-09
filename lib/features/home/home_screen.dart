import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/features/shell/app_shell.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:smartglass_flutter/core/models/engine_models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLaunchingUrl = false;

  Future<void> _launchUrl(String urlString) async {
    if (_isLaunchingUrl) return;
    if (urlString.isEmpty) return;

    setState(() => _isLaunchingUrl = true);
    
    // Show premium visual feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Opening store link...',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        await launchUrl(url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open link: $urlString'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunchingUrl = false);
      }
    }
  }

  void _openEcommerceForObject(BuildContext context, String objectName, List<EcomAdProduct> suggestions) async {
    if (suggestions.isNotEmpty) {
      final normalizedObj = objectName.toLowerCase();
      // Try to find a product suggestion matching the object name with a valid link
      final match = suggestions.firstWhere(
        (p) => p.name.toLowerCase().contains(normalizedObj) && (p.id.startsWith('http://') || p.id.startsWith('https://')),
        orElse: () => EcomAdProduct(id: '', name: '', price: 0.0, imageUrl: ''),
      );
      if (match.id.isNotEmpty) {
        await _launchUrl(match.id);
        return;
      }

      // Fallback to the first available valid link in suggestions
      final fallback = suggestions.firstWhere(
        (p) => p.id.startsWith('http://') || p.id.startsWith('https://'),
        orElse: () => EcomAdProduct(id: '', name: '', price: 0.0, imageUrl: ''),
      );
      if (fallback.id.isNotEmpty) {
        await _launchUrl(fallback.id);
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No e-commerce links found in payload for $objectName'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openEcommerceForProduct(BuildContext context, EcomAdProduct product) async {
    if (product.id.startsWith('http://') || product.id.startsWith('https://')) {
      await _launchUrl(product.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No direct e-commerce link in product payload: ${product.name}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final session = context.watch<SessionProvider>();
    final salientObjects = session.state.topSalientObjects;
    final suggestedProducts = session.state.suggestedProducts;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Morning' : hour < 17 ? 'Afternoon' : 'Evening';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu_rounded), onPressed: AppShell.openDrawer),
        title: const Text('Home', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              'Hi ${auth.username.isNotEmpty ? auth.username : "User"}, Good $greeting 👋',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideX(begin: -0.1),

            const SizedBox(height: 4),

            Text(
              'Welcome to SmartGlass Platform',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.onSurfaceVariant),
            ).animate().fadeIn(delay: 100.ms),

            if (salientObjects.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Top Salient Objects',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.onSurfaceVariant),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: salientObjects.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(
                          salientObjects[index],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                        ),
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        onPressed: () => _openEcommerceForObject(context, salientObjects[index], suggestedProducts),
                      ),
                    );
                  },
                ),
              ).animate().fadeIn(delay: 200.ms),
            ],

            const SizedBox(height: 28),

            // Status banner
            _StatusBanner(isLoggedIn: auth.isLoggedIn)
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.1),

            const SizedBox(height: 20),

            // Focus and Behavioral Intent Metrics Panel
            _EngineMetricsPanel(
              lastBIEFrame: session.state.lastBIEFrame,
              isSessionActive: session.state.isSessionActive,
            )
                .animate()
                .fadeIn(delay: 250.ms, duration: 400.ms)
                .slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Category grid
            Text('Quick Access',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700))
                .animate()
                .fadeIn(delay: 300.ms),

            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.2,
              children: [
                _CategoryCard(
                  title: 'Interested Items',
                  icon: Icons.favorite_border_rounded,
                  gradient: const [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
                  iconColor: const Color(0xFF9C27B0),
                  delay: 400,
                  onTap: () => auth.isLoggedIn
                      ? context.push('/interested')
                      : context.go('/login?target=${Uri.encodeComponent('/interested')}'),
                ),
                _CategoryCard(
                  title: 'Connected Devices',
                  icon: Icons.devices_rounded,
                  gradient: const [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                  iconColor: const Color(0xFF2196F3),
                  delay: 500,
                  onTap: () => auth.isLoggedIn
                      ? context.push('/devices')
                      : context.go('/login?target=${Uri.encodeComponent('/devices')}'),
                ),
                _CategoryCard(
                  title: 'Settings',
                  icon: Icons.settings_rounded,
                  gradient: const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                  iconColor: const Color(0xFF4CAF50),
                  delay: 600,
                  onTap: () => auth.isLoggedIn
                      ? context.push('/settings')
                      : context.go('/login?target=${Uri.encodeComponent('/settings')}'),
                ),
                _CategoryCard(
                  title: 'About',
                  icon: Icons.info_outline_rounded,
                  gradient: const [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                  iconColor: const Color(0xFFFF9800),
                  delay: 700,
                  onTap: () => context.push('/about'),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Recommendations
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recommendations',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                TextButton(
                    onPressed: () {},
                    child: const Text('See all')),
              ],
            ).animate().fadeIn(delay: 800.ms),

            const SizedBox(height: 16),

            SizedBox(
              height: 200,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...salientObjects.map((obj) {
                    return _ProductCard(
                      name: obj.isNotEmpty ? (obj[0].toUpperCase() + obj.substring(1)) : obj,
                      price: 'Salient Target',
                      icon: Icons.center_focus_strong_rounded,
                      color: AppTheme.primary,
                      delay: 100,
                      imageUrl: '',
                      onTap: () => _openEcommerceForObject(context, obj, suggestedProducts),
                    );
                  }),
                  ...suggestedProducts.map((prod) {
                    return _ProductCard(
                      name: prod.name,
                      price: '\$${prod.price.toStringAsFixed(2)}',
                      icon: Icons.shopping_bag_rounded,
                      color: AppTheme.primary,
                      delay: 100,
                      imageUrl: prod.imageUrl,
                      onTap: () => _openEcommerceForProduct(context, prod),
                    );
                  }),
                  if (salientObjects.isEmpty && suggestedProducts.isEmpty) ...const [
                    _ProductCard(
                      name: 'Smart Glasses Pro',
                      price: '\$199.00',
                      icon: Icons.visibility_rounded,
                      color: Color(0xFF3B82F6),
                      delay: 900,
                    ),
                    _ProductCard(
                      name: 'Wireless Earbuds',
                      price: '\$89.00',
                      icon: Icons.headset_rounded,
                      color: Color(0xFF8B5CF6),
                      delay: 1000,
                    ),
                    _ProductCard(
                      name: 'Fitness Band',
                      price: '\$49.00',
                      icon: Icons.watch_rounded,
                      color: Color(0xFF10B981),
                      delay: 1100,
                    ),
                    _ProductCard(
                      name: 'AI Camera',
                      price: '\$299.00',
                      icon: Icons.camera_alt_rounded,
                      color: Color(0xFFF59E0B),
                      delay: 1200,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool isLoggedIn;
  const _StatusBanner({required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLoggedIn
              ? [const Color(0xFF3B82F6), const Color(0xFF1E40AF)]
              : [const Color(0xFF64748B), const Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isLoggedIn ? const Color(0xFF3B82F6) : const Color(0xFF64748B))
                .withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isLoggedIn ? Icons.check_circle_rounded : Icons.login_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLoggedIn ? 'Session Active' : 'Not Signed In',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
              Text(
                isLoggedIn
                    ? 'SmartGlass runtime ready'
                    : 'Sign in to unlock full features',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final Color iconColor;
  final int delay;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.iconColor,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF1A2B3D)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms).scale(
        begin: const Offset(0.9, 0.9),
        delay: Duration(milliseconds: delay),
        duration: 350.ms,
        curve: Curves.easeOutBack);
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final String price;
  final IconData icon;
  final Color color;
  final int delay;
  final String? imageUrl;
  final VoidCallback? onTap;

  const _ProductCard({
    required this.name,
    required this.price,
    required this.icon,
    required this.color,
    required this.delay,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImg = imageUrl != null && imageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 90,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  image: hasImg
                      ? DecorationImage(
                          image: NetworkImage(imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasImg ? null : Center(child: Icon(icon, color: color, size: 42)),
              ),
              const SizedBox(height: 12),
              Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(price,
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(
        delay: Duration(milliseconds: delay), duration: 400.ms);
  }
}

class _EngineMetricsPanel extends StatelessWidget {
  final BIEFrame? lastBIEFrame;
  final bool isSessionActive;

  const _EngineMetricsPanel({
    required this.lastBIEFrame,
    required this.isSessionActive,
  });

  @override
  Widget build(BuildContext context) {
    final gaze = lastBIEFrame?.gazeTarget ?? 'None';
    final salience = lastBIEFrame?.salienceScore ?? 0.0;
    final intent = lastBIEFrame?.intent ?? 'None';
    final confidence = lastBIEFrame?.confidence ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Focus & Behavioral Intent',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface,
                    ),
              ),
              const Spacer(),
              if (isSessionActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.green, size: 8),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'OFFLINE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _MetricRow(
            label: 'Gaze Focus',
            value: gaze,
            icon: Icons.remove_red_eye_outlined,
            iconColor: Colors.blue,
          ),
          const SizedBox(height: 12),
          _MetricProgressRow(
            label: 'Salience Score',
            value: salience,
            icon: Icons.track_changes_rounded,
            color: Colors.amber[700]!,
          ),
          const SizedBox(height: 12),
          _MetricProgressRow(
            label: 'Intent Confidence ($intent)',
            value: confidence,
            icon: Icons.insights_rounded,
            color: Colors.teal[600]!,
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _MetricProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _MetricProgressRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

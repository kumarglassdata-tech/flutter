import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/features/shell/app_shell.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu_rounded), onPressed: AppShell.openDrawer),
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                ),
                shape: BoxShape.circle,
                image: auth.photoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(auth.photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: auth.photoUrl.isEmpty
                  ? Center(
                      child: Text(
                        auth.username.isNotEmpty
                            ? auth.username.substring(0, 1).toUpperCase()
                            : (auth.email.isNotEmpty ? auth.email.substring(0, 1).toUpperCase() : 'U'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w800),
                      ),
                    )
                  : null,
            ).animate().fadeIn(duration: 400.ms).scale(
                begin: const Offset(0.7, 0.7), duration: 500.ms,
                curve: Curves.easeOutBack),

            const SizedBox(height: 16),

            Text(
              auth.username.isNotEmpty ? auth.username : 'User',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ).animate().fadeIn(delay: 200.ms),

            Text(
              auth.email.isNotEmpty ? auth.email : 'No email',
              style: const TextStyle(color: AppTheme.onSurfaceVariant),
            ).animate().fadeIn(delay: 300.ms),

            const Text(
              'Customer ID: SG12345',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ).animate().fadeIn(delay: 350.ms),

            const SizedBox(height: 28),

            // Options
            Card(
              child: Column(
                children: [
                  _ProfileOption(
                    icon: Icons.edit_rounded,
                    title: 'Edit Info',
                    delay: 400,
                    onTap: () => context.push('/edit-info'),
                  ),
                  const Divider(height: 1),
                  _ProfileOption(
                    icon: Icons.receipt_long_rounded,
                    title: 'Orders',
                    delay: 450,
                    onTap: () => context.push('/orders'),
                  ),
                  const Divider(height: 1),
                  _ProfileOption(
                    icon: Icons.favorite_rounded,
                    title: 'Interested Items',
                    delay: 500,
                    onTap: () => context.push('/interested'),
                  ),
                  const Divider(height: 1),
                  _ProfileOption(
                    icon: Icons.devices_rounded,
                    title: 'Connected Devices',
                    delay: 550,
                    onTap: () => context.push('/devices'),
                  ),
                  const Divider(height: 1),
                  _ProfileOption(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    delay: 600,
                    onTap: () => context.push('/settings'),
                  ),
                  const Divider(height: 1),
                  _ProfileOption(
                    icon: Icons.info_outline_rounded,
                    title: 'About',
                    delay: 650,
                    onTap: () => context.push('/about'),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) context.go('/home');
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ).animate().fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final int delay;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/features/shell/app_shell.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu_rounded), onPressed: AppShell.openDrawer),
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: 'Profile',
            delay: 0,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primary.withOpacity(0.2),
                    backgroundImage: auth.photoUrl.isNotEmpty ? NetworkImage(auth.photoUrl) : null,
                    child: auth.photoUrl.isEmpty
                        ? Text(
                            auth.username.isNotEmpty 
                                ? auth.username[0].toUpperCase() 
                                : (auth.email.isNotEmpty ? auth.email[0].toUpperCase() : '?'),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          )
                        : null,
                  ),
                ),
              ),
              _SettingsInfo('Username', auth.username.isNotEmpty ? auth.username : 'Not logged in'),
              _SettingsInfo('Email', auth.email.isNotEmpty ? auth.email : 'Not logged in'),
            ],
          ),
          _SettingsSection(
            title: 'Runtime Configuration',
            delay: 100,
            children: [
              _SettingsToggle('Auto-start on boot', false, (_) {}),
              _SettingsToggle('Persistent Service', true, (_) {}),
              _SettingsToggle('Debug Mode', true, (_) {}),
            ],
          ),
          _SettingsSection(
            title: 'Hardware',
            delay: 300,
            children: [
              const _SettingsInfo('Primary Camera', 'Back (Default)'),
              _SettingsToggle('Low Power BLE', false, (_) {}),
            ],
          ),
          _SettingsSection(
            title: 'Developer Validation',
            delay: 400,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Salience UI Threshold: ${(settings.salienceThreshold * 100).toInt()}%'),
                    Slider(
                      value: settings.salienceThreshold,
                      min: 0.1,
                      max: 1.0,
                      divisions: 90,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => settings.setSalienceThreshold(v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Build Version: 1.0.0-PROTOTYPE',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.onSurfaceVariant),
            ),
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final int delay;

  const _SettingsSection({
    required this.title,
    required this.children,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                    color: AppTheme.primary, fontWeight: FontWeight.w700),
          ),
        ),
        Card(
          child: Column(children: children),
        ),
        const SizedBox(height: 16),
      ],
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms);
  }
}

class _SettingsInfo extends StatelessWidget {
  final String label;
  final String value;
  const _SettingsInfo(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: Text(value,
          style: const TextStyle(
              color: AppTheme.onSurfaceVariant, fontSize: 13)),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const _SettingsToggle(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppTheme.primary,
      activeTrackColor: AppTheme.primary.withValues(alpha: 0.4),
    );
  }
}

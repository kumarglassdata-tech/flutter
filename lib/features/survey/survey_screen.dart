import 'package:flutter/material.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  bool _isRedirecting = false;

  Future<void> _launchSurvey() async {
    setState(() {
      _isRedirecting = true;
    });

    final Uri url = Uri.parse('https://myna-ah-dev.glassdata.ai/');
    
    // Artificial delay to show the spinner clearly as requested
    await Future.delayed(const Duration(milliseconds: 800));

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the survey link.')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isRedirecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Survey (Ecom)', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surface,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.shopping_cart_checkout_rounded,
                size: 80,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Ecom Ad Handler',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tap the button below to open the E-Commerce handler in your browser securely.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              if (_isRedirecting)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Redirecting securely...',
                      style: TextStyle(color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _launchSurvey,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text(
                      'Open Survey Link',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

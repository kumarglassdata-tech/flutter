import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/navigation/app_router.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/services/camera_service.dart';
import 'package:smartglass_flutter/core/services/meta_glasses_sdk_service.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';

import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await WakelockPlus.enable();

  // Load persisted state before app starts
  final auth = AuthProvider();
  final settings = SettingsProvider();
  await auth.load();
  await settings.load();

  final cameraService = CameraService();
  final session = SessionProvider(
    cameraService,
    metaSdkService: const MetaGlassesSdkService(),
  );

  // Hook global platform and framework errors to stream directly into the Diagnostics tab
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    session.logEvent('Flutter Error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    session.logEvent('Platform Error: $error');
    return true;
  };

  runApp(SmartGlassApp(auth: auth, settings: settings, session: session));
}

class SmartGlassApp extends StatelessWidget {
  final AuthProvider auth;
  final SettingsProvider settings;
  final SessionProvider session;

  const SmartGlassApp({
    super.key,
    required this.auth,
    required this.settings,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: session),
      ],
      child: Builder(
        builder: (context) {
          // Watch auth so router updates on login/logout
          final authProvider = context.watch<AuthProvider>();
          final settingsProvider = context.watch<SettingsProvider>();
          final router = createRouter(authProvider);
          return MaterialApp.router(
            title: 'Smart Myna',
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: settingsProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return child ?? const SizedBox();
            },
          );
        },
      ),
    );
  }
}

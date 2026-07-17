import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/navigation/app_router.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/services/camera_service.dart';
import 'package:smartglass_flutter/core/services/titan_sdk_service.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:smartglass_flutter/core/services/location_service.dart';

import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize env and Wakelock before constructing providers
  // otherwise EnvConfig will throw NotInitializedError and silently crash Dart
  await dotenv.load(fileName: ".env");
  await WakelockPlus.enable();

  // Create providers synchronously
  final auth = AuthProvider();
  final settings = SettingsProvider();
  final cameraService = CameraService();
  final session = SessionProvider(
    cameraService,
    titanSdkService: TitanSdkService(),
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
        ChangeNotifierProvider(create: (_) => LocationService()),
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
            themeMode: ThemeMode.light,
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

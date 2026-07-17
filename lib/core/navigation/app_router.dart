import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/features/splash/splash_screen.dart';
import 'package:smartglass_flutter/features/auth/login_screen.dart';
import 'package:smartglass_flutter/features/shell/app_shell.dart';
import 'package:smartglass_flutter/features/home/home_screen.dart';
import 'package:smartglass_flutter/features/dashboard/dashboard_screen.dart';
import 'package:smartglass_flutter/features/profile/profile_screen.dart';
import 'package:smartglass_flutter/features/profile/edit_info_screen.dart';
import 'package:smartglass_flutter/features/devices/devices_screen.dart';
import 'package:smartglass_flutter/features/devices/device_control_screen.dart';
import 'package:smartglass_flutter/features/devices/connected_devices_screen.dart';
import 'package:smartglass_flutter/features/diagnostics/diagnostics_screen.dart';
import 'package:smartglass_flutter/features/settings/settings_screen.dart';
import 'package:smartglass_flutter/features/orders/orders_screen.dart';
import 'package:smartglass_flutter/features/about/about_screen.dart';
import 'package:smartglass_flutter/features/engine_inspector/engine_inspector_screen.dart';
import 'package:smartglass_flutter/features/interested/interested_screen.dart';
import 'package:smartglass_flutter/features/debug/test_context_engine_screen.dart';

import 'package:smartglass_flutter/features/onboarding/personalize_feed_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: auth,
    initialLocation: '/splash',
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final hasPreferences = auth.hasPreferences;
      final isLogin = state.matchedLocation.startsWith('/login');
      final isSplash = state.matchedLocation == '/splash';
      final isAbout = state.matchedLocation == '/about';
      final isHome = state.matchedLocation == '/home';
      final isPersonalize = state.matchedLocation == '/personalize-feed';

      // Always allow splash, login, about, and home
      if (isSplash || isAbout || isLogin) return null;
      
      // If not logged in and trying to access a protected route (home is protected but we used to let it slide? No, let's protect it)
      if (!loggedIn) {
        final target = state.matchedLocation;
        return '/login?target=${Uri.encodeComponent(target)}';
      }

      // If logged in, but no preferences, force to personalize
      if (loggedIn && !hasPreferences && !isPersonalize) {
        return '/personalize-feed';
      }

      // If logged in, has preferences, and tries to go to personalize, send to home
      if (loggedIn && hasPreferences && isPersonalize) {
        return '/home';
      }

      // If logged in but trying to access admin-only routes and is not admin
      final isAdminRoute = state.matchedLocation.startsWith('/diagnostics') ||
          state.matchedLocation.startsWith('/engine-inspector');
      if (isAdminRoute && !auth.isAdmin) {
        return '/home';
      }
      return null;
    },
    routes: [
      // Splash — no shell
      GoRoute(
        path: '/splash',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),

      // Personalize Feed — no shell
      GoRoute(
        path: '/personalize-feed',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PersonalizeFeedScreen(),
      ),

      // Login — no shell
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final target = state.uri.queryParameters['target'];
          return LoginScreen(targetRoute: target);
        },
      ),

      // About — no shell
      GoRoute(
        path: '/about',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AboutScreen(),
      ),

      // Interested Items — no shell
      GoRoute(
        path: '/interested',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const InterestedScreen(),
      ),

      // Orders — no shell
      GoRoute(
        path: '/orders',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OrdersScreen(),
      ),

      // Edit Info — no shell
      GoRoute(
        path: '/edit-info',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditInfoScreen(),
      ),

      // Device Control — no shell, accessible via /device/:mac
      GoRoute(
        path: '/device/:deviceId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final deviceId = state.pathParameters['deviceId'] ?? 'Unknown';
          return DeviceControlScreen(deviceId: Uri.decodeComponent(deviceId));
        },
      ),

      // Shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/fop',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/devices',
            builder: (context, state) => const DevicesScreen(),
          ),
          GoRoute(
            path: '/connected-devices',
            builder: (context, state) => const ConnectedDevicesScreen(),
          ),
          GoRoute(
            path: '/diagnostics',
            builder: (context, state) => const DiagnosticsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/engine-inspector',
            builder: (context, state) => const EngineInspectorScreen(),
          ),
          GoRoute(
            path: '/test-context',
            builder: (context, state) => const TestContextEngineScreen(),
          ),
        ],
      ),
    ],
  );
}

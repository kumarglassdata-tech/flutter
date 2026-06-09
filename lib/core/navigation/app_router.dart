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
import 'package:smartglass_flutter/features/diagnostics/diagnostics_screen.dart';
import 'package:smartglass_flutter/features/settings/settings_screen.dart';
import 'package:smartglass_flutter/features/orders/orders_screen.dart';
import 'package:smartglass_flutter/features/about/about_screen.dart';
import 'package:smartglass_flutter/features/engine_inspector/engine_inspector_screen.dart';
import 'package:smartglass_flutter/features/interested/interested_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final isLogin = state.matchedLocation.startsWith('/login');
      final isSplash = state.matchedLocation == '/splash';
      final isAbout = state.matchedLocation == '/about';

      // Always allow splash, login, and about
      if (isSplash || isAbout) return null;
      // If not logged in and trying to access protected route
      if (!loggedIn && !isLogin) {
        final target = state.matchedLocation;
        return '/login?target=${Uri.encodeComponent(target)}';
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

      // Device Control — no shell
      GoRoute(
        path: '/devices/:deviceId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final deviceId = state.pathParameters['deviceId'] ?? 'Unknown';
          return DeviceControlScreen(deviceId: deviceId);
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
        ],
      ),
    ],
  );
}

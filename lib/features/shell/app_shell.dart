import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:smartglass_flutter/core/providers/auth_provider.dart';
import 'package:smartglass_flutter/core/providers/session_provider.dart';
import 'package:smartglass_flutter/core/theme/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartglass_flutter/features/shell/widgets/myna_assistant_bottom_sheet.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  static void openDrawer() {
    scaffoldKey.currentState?.openDrawer();
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late SessionProvider _sessionProvider;
  String _lastCheckedUtterance = '';
  bool _isBottomSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sessionProvider = context.read<SessionProvider>();
    _sessionProvider.addListener(_onSessionUpdate);
  }

  @override
  void dispose() {
    _sessionProvider.removeListener(_onSessionUpdate);
    super.dispose();
  }

  void _onSessionUpdate() {
    if (!mounted) return;
    final utterance = _sessionProvider.state.lastInteractionResponse?.lastUtterance ?? '';
    if (utterance != _lastCheckedUtterance && utterance.isNotEmpty) {
      _lastCheckedUtterance = utterance;
      final text = utterance.toLowerCase();
      if (text.contains('hey myna') || text.contains('hello myna') || text.contains('myna')) {
        if (!_isBottomSheetOpen) {
          _isBottomSheetOpen = true;
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (ctx) => const MynaAssistantBottomSheet(),
          ).whenComplete(() {
            _isBottomSheetOpen = false;
          });
        }
      }
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      key: AppShell.scaffoldKey,
      body: Row(
        children: [
          // Side rail for wide screens (web/tablet)
          if (MediaQuery.of(context).size.width >= 720)
            _SideRail(currentLocation: location, auth: auth),
          Expanded(child: widget.child),
        ],
      ),
      floatingActionButton: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (ctx) => const MynaAssistantBottomSheet(),
          );
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF2563EB),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
            ],
          ),
          child: Center(
            child: ClipOval(
              child: Image.asset(
                "assets/images/myna_bot.png",
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
      // Bottom nav for mobile
      bottomNavigationBar: MediaQuery.of(context).size.width < 720
          ? _BottomNav(currentLocation: location, auth: auth)
          : null,
      drawer: _AppDrawer(auth: auth),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom Navigation Bar (mobile)
// ---------------------------------------------------------------------------
class _BottomNav extends StatelessWidget {
  final String currentLocation;
  final AuthProvider auth;
  const _BottomNav({required this.currentLocation, required this.auth});

  @override
  Widget build(BuildContext context) {
    final items = _navItems(context, auth);
    final currentIndex = _currentIndex(currentLocation);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => _onTap(context, i, auth),
        elevation: 0,
        backgroundColor: Colors.transparent,
        destinations: items
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.icon, color: AppTheme.primary),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Side Rail (web/tablet)
// ---------------------------------------------------------------------------
class _SideRail extends StatelessWidget {
  final String currentLocation;
  final AuthProvider auth;
  const _SideRail({required this.currentLocation, required this.auth});

  @override
  Widget build(BuildContext context) {
    final items = _navItems(context, auth);
    final currentIndex = _currentIndex(currentLocation);

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) => _onTap(context, i, auth),
      labelType: NavigationRailLabelType.all,
      backgroundColor: AppTheme.surface,
      indicatorColor: AppTheme.primary.withValues(alpha: 0.15),
      selectedIconTheme: const IconThemeData(color: AppTheme.primary),
      selectedLabelTextStyle: const TextStyle(
          color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/smart_myna_logo.png',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Smart Myna',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary)),
          ],
        ),
      ),
      destinations: items
          .map((item) => NavigationRailDestination(
                icon: Icon(item.icon),
                label: Text(item.label),
              ))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Drawer
// ---------------------------------------------------------------------------
class _AppDrawer extends StatelessWidget {
  final AuthProvider auth;
  const _AppDrawer({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/smart_myna_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Smart Myna',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    Text('Smart Myna Shopping App',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          _drawerItem(context, Icons.bluetooth, 'Pair Devices', '/devices'),
          _drawerItem(context, Icons.home_rounded, 'Home', '/home'),
          _drawerItem(context, Icons.bar_chart_rounded, 'Live Session (FOP)', '/fop'),
          _drawerItem(context, Icons.devices_rounded, 'Connected Devices', '/devices'),
          if (auth.isAdmin) ...[
            _drawerItem(context, Icons.monitor_heart_rounded, 'Diagnostics', '/diagnostics'),
            _drawerItem(context, Icons.analytics_rounded, 'Engine Inspector', '/engine-inspector'),
          ],
          _drawerItem(context, Icons.settings_rounded, 'Settings', '/settings'),
          Consumer<SettingsProvider>(
            builder: (context, settings, _) => SwitchListTile(
              title: const Text('Dark Mode'),
              secondary: const Icon(Icons.dark_mode_rounded),
              value: settings.isDarkMode,
              onChanged: (val) => settings.setDarkMode(val),
              activeColor: AppTheme.primary,
            ),
          ),
          _drawerItem(context, Icons.account_circle_rounded, 'Profile', '/profile'),
          _drawerItem(context, Icons.info_rounded, 'About', '/about'),
          const Spacer(),
          const Divider(),
          if (auth.isLoggedIn)
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
              title: const Text('Logout',
                  style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                await auth.logout();
                if (context.mounted) context.go('/home');
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.login_rounded, color: AppTheme.primary),
              title: const Text('Login',
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                context.go('/login?target=/home');
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.onSurfaceVariant),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        context.push(route);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared nav helpers
// ---------------------------------------------------------------------------
class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}

List<_NavItem> _navItems(BuildContext context, AuthProvider auth) => const [
      _NavItem('HOME', Icons.home_rounded, '/home'),
      _NavItem('FOP', Icons.bar_chart_rounded, '/fop'),
      _NavItem('PROFILE', Icons.account_circle_rounded, '/profile'),
    ];

int _currentIndex(String location) {
  if (location.startsWith('/fop')) return 1;
  if (location.startsWith('/profile')) return 2;
  return 0;
}

void _onTap(BuildContext context, int index, AuthProvider auth) {
  final routes = ['/home', '/fop', '/profile'];
  final route = routes[index];
  if (!auth.isLoggedIn && route != '/home') {
    context.go('/login?target=${Uri.encodeComponent(route)}');
  } else {
    context.push(route);
  }
}

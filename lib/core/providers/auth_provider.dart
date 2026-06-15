import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Predefined credentials (matching the original Android app)
// ---------------------------------------------------------------------------
class Credential {
  final String email;
  final String username;
  final String password;
  const Credential(this.email, this.username, this.password);
}

const predefinedCredentials = [
  Credential('davidkumar@glassdata.ai', 'David K GD', 'david@Admin123'),
  Credential('padmsunk@glassdata.ai', 'SanthelM GD', 'santhel@Admin123'),
  Credential('padsum@glassdata.ai', 'SanthelM GD', 'santhel@Admin123'),
  Credential('manojd@glassdata.ai', 'ManojD GD', 'manoj@Admin123'),
  Credential('kumargandhudi@glassdata.ai', 'hackerr03', 'devops1067'),
  Credential('demo@glassdata.ai', 'GlassData', 'Glass@123'),
];

// ---------------------------------------------------------------------------
// AuthProvider — replaces SessionPreferences + login logic
// ---------------------------------------------------------------------------
class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String _username = '';
  String _email = '';

  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get email => _email;
  bool get isAdmin => _isLoggedIn && (_email.toLowerCase() == 'kumargandhudi@glassdata.ai' || _username.toLowerCase() == 'hackerr03' );

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _username = prefs.getString('username') ?? '';
    _email = prefs.getString('email') ?? '';
    notifyListeners();
  }

  /// Returns error message or null on success
  Future<String?> login(String usernameOrEmail, String password) async {
    final match = predefinedCredentials.where((c) {
      return (c.email.toLowerCase() == usernameOrEmail.trim().toLowerCase() ||
              c.username.toLowerCase() == usernameOrEmail.trim().toLowerCase()) &&
          c.password == password;
    }).firstOrNull;

    if (match == null) return 'Invalid credentials. Please try again.';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('username', match.username);
    await prefs.setString('email', match.email);

    _isLoggedIn = true;
    _username = match.username;
    _email = match.email;
    notifyListeners();
    return null;
  }

  Future<void> loginDemo() async {
    // Demo login disabled
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _username = '';
    _email = '';
    notifyListeners();
  }

  Future<void> updateProfile(String newUsername, String newEmail) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', newUsername);
    await prefs.setString('email', newEmail);
    _username = newUsername;
    _email = newEmail;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// SettingsProvider — replaces SessionPreferences settings fields
// ---------------------------------------------------------------------------
class SettingsProvider extends ChangeNotifier {
  bool _useMockMeta = false;
  bool _autoLoginDemoMode = false;
  String _preferredCamera = 'PHONE';
  bool _isDarkMode = false;
  double _salienceThreshold = 0.75;

  bool get useMockMeta => _useMockMeta;
  bool get autoLoginDemoMode => _autoLoginDemoMode;
  String get preferredCamera => _preferredCamera;
  bool get isDarkMode => _isDarkMode;
  double get salienceThreshold => _salienceThreshold;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _useMockMeta = prefs.getBool('useMockMeta') ?? false;
    _autoLoginDemoMode = prefs.getBool('autoLoginDemoMode') ?? false;
    _preferredCamera = prefs.getString('preferredCamera') ?? 'PHONE';
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _salienceThreshold = prefs.getDouble('salienceThreshold') ?? 0.75;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    (await SharedPreferences.getInstance()).setBool('isDarkMode', value);
    notifyListeners();
  }

  Future<void> setUseMockMeta(bool value) async {
    _useMockMeta = value;
    (await SharedPreferences.getInstance()).setBool('useMockMeta', value);
    notifyListeners();
  }

  Future<void> setAutoLoginDemoMode(bool value) async {
    _autoLoginDemoMode = value;
    (await SharedPreferences.getInstance()).setBool('autoLoginDemoMode', value);
    notifyListeners();
  }

  Future<void> setPreferredCamera(String value) async {
    _preferredCamera = value;
    (await SharedPreferences.getInstance()).setString('preferredCamera', value);
    notifyListeners();
  }

  Future<void> setSalienceThreshold(double value) async {
    _salienceThreshold = value;
    (await SharedPreferences.getInstance()).setDouble('salienceThreshold', value);
    notifyListeners();
  }
}

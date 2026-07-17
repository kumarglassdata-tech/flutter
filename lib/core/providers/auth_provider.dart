import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:smartglass_flutter/core/services/db_service.dart';

// ---------------------------------------------------------------------------
// AuthProvider — Google Auth + PostgreSQL Sync + Email/Password
// ---------------------------------------------------------------------------
class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String _username = '';
  String _email = '';
  String _photoUrl = '';

  int? _userId;
  bool _hasPreferences = true;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  
  final DbService _dbService = DbService();

  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get email => _email;
  String get photoUrl => _photoUrl;
  bool get hasPreferences => _hasPreferences;
  int? get userId => _userId;
  
  bool get isAdmin => _isLoggedIn && (_email.toLowerCase() == 'kumargandhudi@glassdata.ai' || _email.toLowerCase() == 'davidkumar@glassdata.ai');

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _username = prefs.getString('username') ?? '';
    _email = prefs.getString('email') ?? '';
    _photoUrl = prefs.getString('photoUrl') ?? '';
    _userId = prefs.getInt('userId');
    _hasPreferences = prefs.getBool('hasPreferences') ?? true;
    notifyListeners();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> setHasPreferences(bool value) async {
    _hasPreferences = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasPreferences', value);
    notifyListeners();
  }

  /// Sign up with email and password
  Future<String?> signUpWithEmail(String email, String password, String displayName) async {
    try {
      final hash = _hashPassword(password);
      await _dbService.createEmailUser(
        email: email.trim().toLowerCase(),
        passwordHash: hash,
        displayName: displayName.trim(),
      );
      
      // Auto-login after sign up
      return loginWithEmail(email, password);
    } catch (e) {
      debugPrint('Sign Up Error: $e');
      return 'Sign up failed. Email might already be in use.';
    }
  }

  /// Log in with email and password
  Future<String?> loginWithEmail(String email, String password) async {
    try {
      final hash = _hashPassword(password);
      final user = await _dbService.authenticateEmailUser(
        email: email.trim().toLowerCase(),
        passwordHash: hash,
      );

      if (user == null) {
        return 'Invalid email or password.';
      }

      final uid = user['id'] as int?;
      final hasPref = uid != null ? await _dbService.hasPreferences(uid) : true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', user['display_name'] ?? 'User');
      await prefs.setString('email', user['email']);
      await prefs.setString('photoUrl', user['photo_url'] ?? '');
      if (uid != null) await prefs.setInt('userId', uid);
      await prefs.setBool('hasPreferences', hasPref);

      _isLoggedIn = true;
      _username = user['display_name'] ?? 'User';
      _email = user['email'];
      _photoUrl = user['photo_url'] ?? '';
      _userId = uid;
      _hasPreferences = hasPref;
      
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Login Error: $e');
      // If it's a known exception from DbService, show it directly
      if (e is Exception) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        return msg;
      }
      return 'Login failed: $e';
    }
  }

  /// Initiates Google Sign-In and stores user in Postgres
  Future<String?> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return 'Sign-in aborted by user.';
      }

      // Upsert into Postgres
      final uid = await _dbService.upsertUser(
        googleId: account.id,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );

      final hasPref = uid != null ? await _dbService.hasPreferences(uid) : true;

      // Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', account.displayName ?? 'User');
      await prefs.setString('email', account.email);
      await prefs.setString('photoUrl', account.photoUrl ?? '');
      if (uid != null) await prefs.setInt('userId', uid);
      await prefs.setBool('hasPreferences', hasPref);

      _isLoggedIn = true;
      _username = account.displayName ?? 'User';
      _email = account.email;
      _photoUrl = account.photoUrl ?? '';
      _userId = uid;
      _hasPreferences = hasPref;
      
      notifyListeners();
      return null; // Success
    } catch (error) {
      debugPrint('Google Sign-In Error: $error');
      return 'Authentication failed: $error';
    }
  }

  Future<void> loginDemo() async {
    // Disabled
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _username = '';
    _email = '';
    _photoUrl = '';
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
  bool _autoLoginDemoMode = false;
  String _preferredCamera = 'PHONE';
  bool _isDarkMode = false;
  double _salienceThreshold = 0.75;
  bool get autoLoginDemoMode => _autoLoginDemoMode;
  String get preferredCamera => _preferredCamera;
  bool get isDarkMode => _isDarkMode;
  double get salienceThreshold => _salienceThreshold;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
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

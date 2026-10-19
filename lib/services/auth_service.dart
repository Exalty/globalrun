import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyPasswordHash = 'user_pwd_hash';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyUserPhoto = 'user_photo';
  static const String _keyUserWallet = 'user_wallet_balance';

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Helper untuk hashing SHA-256 (Non-Firebase otentikasi mandiri)
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // Cek ketersediaan sensor biometrik (Fingerprint/FaceID)
  Future<bool> canCheckBiometrics() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  // Autentikasi menggunakan Fingerprint / FaceID
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Pindai sidik jari Anda untuk masuk ke Global Virtual Race',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // Pendaftaran Pengguna Baru
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email.trim().toLowerCase());
    await prefs.setString(_keyPasswordHash, hashPassword(password));
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setBool(_keyBiometricEnabled, true);
    await prefs.setDouble(_keyUserWallet, 250.0); // Default saldo awal USD
    return true;
  }

  // Login Manual dengan Email & Password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_keyUserEmail);
    final savedHash = prefs.getString(_keyPasswordHash);

    // Akun default demo jika belum pernah register
    if (savedEmail == null) {
      if (email.trim().toLowerCase() == 'runner@virtualrace.com' && password == 'runner123') {
        await prefs.setString(_keyUserName, 'Virtual Runner Pro');
        await prefs.setString(_keyUserEmail, 'runner@virtualrace.com');
        await prefs.setString(_keyPasswordHash, hashPassword('runner123'));
        await prefs.setBool(_keyIsLoggedIn, true);
        await prefs.setBool(_keyBiometricEnabled, true);
        await prefs.setDouble(_keyUserWallet, 150.0);
        return true;
      }
      return false;
    }

    if (savedEmail == email.trim().toLowerCase() && savedHash == hashPassword(password)) {
      await prefs.setBool(_keyIsLoggedIn, true);
      return true;
    }

    return false;
  }

  // Cek Status Login Saat Buka Aplikasi
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Cek Apakah Biometrik Diaktifkan
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  // Ambil Data Profil
  Future<Map<String, dynamic>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyUserName) ?? 'Virtual Runner',
      'email': prefs.getString(_keyUserEmail) ?? 'runner@virtualrace.com',
      'wallet': prefs.getDouble(_keyUserWallet) ?? 150.0,
      'photo': prefs.getString(_keyUserPhoto) ?? '',
    };
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
  }
}

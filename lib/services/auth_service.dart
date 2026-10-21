import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
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
  static const String _keyJwtToken = 'jwt_token';

  // Base URL backend Node.js REST API
  // 10.0.2.2 untuk Android emulator, 192.168.110.5 untuk perangkat fisik via Wi-Fi lokal, localhost untuk desktop/web
  static const String baseUrl = 'http://192.168.110.5:5000';
  static const String emulatorUrl = 'http://10.0.2.2:5000';

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

  // Pendaftaran Pengguna Baru (Terhubung ke Node.js REST API + fallback lokal)
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();

    // 1. Coba sinkronisasi ke REST API Backend (Bcrypt + PostgreSQL)
    for (final url in [baseUrl, emulatorUrl]) {
      try {
        final response = await http.post(
          Uri.parse('$url/api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'full_name': name.trim(),
            'email': cleanEmail,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          if (data['token'] != null) {
            await prefs.setString(_keyJwtToken, data['token']);
          }
          break;
        }
      } catch (_) {
        // Fallback jika backend belum terhubung/offline
      }
    }

    // 2. Simpan kredensial & status di penyimpanan lokal
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, cleanEmail);
    await prefs.setString(_keyPasswordHash, hashPassword(password));
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setBool(_keyBiometricEnabled, true);
    await prefs.setDouble(_keyUserWallet, 250.0);
    return true;
  }

  // Login dengan Email & Password (Bcrypt & JWT via Backend + fallback lokal)
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();

    // 1. Coba login melalui REST API Node.js (JWT & Bcrypt)
    for (final url in [baseUrl, emulatorUrl]) {
      try {
        final response = await http.post(
          Uri.parse('$url/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': cleanEmail,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['token'] != null) {
            await prefs.setString(_keyJwtToken, data['token']);
            if (data['user'] != null) {
              await prefs.setString(_keyUserName, data['user']['full_name'] ?? 'Virtual Runner');
              await prefs.setString(_keyUserEmail, data['user']['email'] ?? cleanEmail);
            }
            await prefs.setBool(_keyIsLoggedIn, true);
            await prefs.setBool(_keyBiometricEnabled, true);
            return true;
          }
        }
      } catch (_) {
        // Fallback ke penyimpanan lokal jika server offline
      }
    }

    // 2. Fallback verifikasi lokal jika server sedang offline
    final savedEmail = prefs.getString(_keyUserEmail);
    final savedHash = prefs.getString(_keyPasswordHash);

    // Akun default demo jika belum pernah register
    if (savedEmail == null) {
      if (cleanEmail == 'runner@virtualrace.com' && password == 'runner123') {
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

    if (savedEmail == cleanEmail && savedHash == hashPassword(password)) {
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

  // Ambil Token JWT yang tersimpan
  Future<String?> getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyJwtToken);
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
      'hasToken': prefs.getString(_keyJwtToken) != null,
    };
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyJwtToken);
  }
}

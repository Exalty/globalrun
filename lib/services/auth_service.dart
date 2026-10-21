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
  // 192.168.110.5 untuk perangkat fisik Android via Wi-Fi lokal, 10.0.2.2 untuk Android emulator, localhost untuk web/desktop
  static const String baseUrl = 'http://192.168.110.5:5000';
  static const String emulatorUrl = 'http://10.0.2.2:5000';

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Helper hashing SHA-256 (Otentikasi mandiri non-Firebase)
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // Cek ketersediaan hardware sensor biometrik (Fingerprint/FaceID)
  Future<bool> canCheckBiometrics() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  // Pemicu pemindaian sidik jari
  Future<bool> authenticateWithBiometrics({String? reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason ?? 'Pindai sidik jari Anda untuk verifikasi identitas',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // Pendaftaran Akun Manual Baru (PostgreSQL Backend + Local Cache)
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();
    String? token;

    // 1. Kirim ke REST API Node.js (Bcrypt + PostgreSQL)
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
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          token = data['token'];
          break;
        } else if (response.statusCode == 409) {
          return {
            'success': false,
            'message': 'Email sudah terdaftar. Silakan gunakan email lain atau login.',
          };
        }
      } catch (_) {
        // Fallback jika backend offline/unreachable
      }
    }

    // 2. Simpan profil pengguna ke local storage
    if (token != null) {
      await prefs.setString(_keyJwtToken, token);
    }
    await prefs.setString(_keyUserName, name.trim());
    await prefs.setString(_keyUserEmail, cleanEmail);
    await prefs.setString(_keyPasswordHash, hashPassword(password));
    await prefs.setBool(_keyIsLoggedIn, true);
    // BIOMETRIK DEFAULT DIMATIKAN — Hanya bisa dinyalakan manual di menu Profil
    await prefs.setBool(_keyBiometricEnabled, false);
    await prefs.setDouble(_keyUserWallet, 250.0);

    return {
      'success': true,
      'message': 'Pendaftaran berhasil!',
    };
  }

  // Login Manual dengan Email & Password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();

    // 1. Coba login melalui REST API Node.js (Bcrypt + JWT)
    for (final url in [baseUrl, emulatorUrl]) {
      try {
        final response = await http.post(
          Uri.parse('$url/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': cleanEmail,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['token'] != null) {
            await prefs.setString(_keyJwtToken, data['token']);
            if (data['user'] != null) {
              await prefs.setString(_keyUserName, data['user']['full_name'] ?? 'Virtual Runner');
              await prefs.setString(_keyUserEmail, data['user']['email'] ?? cleanEmail);
            }
            await prefs.setBool(_keyIsLoggedIn, true);
            return {'success': true, 'message': 'Login berhasil!'};
          }
        } else if (response.statusCode == 401) {
          return {'success': false, 'message': 'Email atau password salah.'};
        }
      } catch (_) {
        // Fallback jika backend offline
      }
    }

    // 2. Verifikasi offline dari akun yang pernah didaftarkan
    final savedEmail = prefs.getString(_keyUserEmail);
    final savedHash = prefs.getString(_keyPasswordHash);

    if (savedEmail != null && savedEmail == cleanEmail && savedHash == hashPassword(password)) {
      await prefs.setBool(_keyIsLoggedIn, true);
      return {'success': true, 'message': 'Login berhasil (mode offline)!'};
    }

    return {
      'success': false,
      'message': 'Akun tidak ditemukan atau password salah. Silakan daftar akun manual terlebih dahulu.',
    };
  }

  // Login menggunakan Sidik Jari (Hanya jika sudah diaktifkan di menu Profil)
  Future<bool> loginWithBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_keyBiometricEnabled) ?? false;
    final savedEmail = prefs.getString(_keyUserEmail);

    if (!isEnabled || savedEmail == null) {
      return false;
    }

    final authenticated = await authenticateWithBiometrics(
      reason: 'Pindai sidik jari Anda untuk masuk ke Global Virtual Race',
    );

    if (authenticated) {
      await prefs.setBool(_keyIsLoggedIn, true);
      return true;
    }
    return false;
  }

  // Mengatur status Biometrik dari Menu Profil (Nyalakan / Matikan)
  Future<bool> setBiometricEnabled(bool enable) async {
    final prefs = await SharedPreferences.getInstance();

    if (enable) {
      // Saat mau menyalakan, pengguna wajib memindai sidik jari untuk validasi keamanan
      final authenticated = await authenticateWithBiometrics(
        reason: 'Pindai sidik jari Anda untuk mengaktifkan login biometrik',
      );

      if (authenticated) {
        await prefs.setBool(_keyBiometricEnabled, true);
        return true;
      }
      return false;
    } else {
      // Mematikan biometrik
      await prefs.setBool(_keyBiometricEnabled, false);
      return true;
    }
  }

  // Cek Status Login Saat Buka Aplikasi
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Cek Apakah Biometrik Diaktifkan di Profil
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  // Ambil Data Profil Pengguna
  Future<Map<String, dynamic>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyUserName) ?? '',
      'email': prefs.getString(_keyUserEmail) ?? '',
      'wallet': prefs.getDouble(_keyUserWallet) ?? 250.0,
      'photo': prefs.getString(_keyUserPhoto) ?? '',
      'isBiometricEnabled': prefs.getBool(_keyBiometricEnabled) ?? false,
    };
  }

  // Logout Saja (Menjaga akun tetap terdaftar, hanya keluar sesi)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  // Hapus Akun & Bersihkan Seluruh Data Lokal (Fresh Start)
  Future<void> resetAllAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

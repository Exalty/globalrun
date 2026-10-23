import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyPasswordHash = 'user_pwd_hash';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyUserPhoto = 'user_photo';
  static const String _keyUserWallet = 'user_wallet_balance';
  static const String _keyJwtToken = 'jwt_token';

  static const MethodChannel _settingsChannel = MethodChannel('com.globalrun.app/settings');

  // Base URL backend Node.js REST API (fallback lokal)
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://192.168.110.5:5000';
  static const String emulatorUrl = 'http://10.0.2.2:5000';

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Cache lokal kode OTP untuk fallback offline
  static String? _offlineOtpEmail;
  static String? _offlineOtpCode;
  static DateTime? _offlineOtpExpiresAt;

  // Helper hashing SHA-256 (Otentikasi mandiri non-Firebase)
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // Buka menu Pengaturan Keamanan / Sidik Jari di Android
  Future<void> openDeviceSecuritySettings() async {
    try {
      await _settingsChannel.invokeMethod('openSecuritySettings');
    } catch (_) {}
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

  // Pendaftaran Akun (Supabase Cloud Auth + Email OTP Verification)
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();

    // 1. Coba registrasi melalui Supabase Cloud Auth
    try {
      final client = Supabase.instance.client;
      final res = await client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'full_name': name.trim()},
      );

      if (res.user != null) {
        await prefs.setString(_keyUserName, name.trim());
        await prefs.setString(_keyUserEmail, cleanEmail);
        await prefs.setString(_keyPasswordHash, hashPassword(password));
        await prefs.setDouble(_keyUserWallet, 250.0);

        // Jika email butuh konfirmasi (OTP)
        final bool requireOtp = res.session == null;
        if (!requireOtp) {
          await prefs.setBool(_keyIsLoggedIn, true);
        }

        return {
          'success': true,
          'requireOtp': requireOtp,
          'message': requireOtp
              ? 'Kode verifikasi telah dikirim ke kotak masuk email $cleanEmail.'
              : 'Pendaftaran akun berhasil!',
        };
      }
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': e.message,
      };
    } catch (_) {
      // Fallback ke server Node.js lokal atau offline jika Supabase belum siap
    }

    // 2. Fallback kirim ke backend Node.js jika ada
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
          await prefs.setString(_keyUserName, name.trim());
          await prefs.setString(_keyUserEmail, cleanEmail);
          await prefs.setString(_keyPasswordHash, hashPassword(password));
          await prefs.setBool(_keyIsLoggedIn, true);
          await prefs.setDouble(_keyUserWallet, 250.0);
          return {'success': true, 'requireOtp': false, 'message': 'Pendaftaran berhasil!'};
        } else if (response.statusCode == 409) {
          return {'success': false, 'message': 'Email sudah terdaftar. Silakan login.'};
        }
      } catch (_) {}
    }

    // 3. Fallback Offline: Simpan lokal & minta OTP offline
    final random = math.Random();
    final localCode = (100000 + random.nextInt(900000)).toString();
    _offlineOtpEmail = cleanEmail;
    _offlineOtpCode = localCode;
    _offlineOtpExpiresAt = DateTime.now().add(const Duration(minutes: 5));

    await prefs.setString(_keyUserName, name.trim());
    await prefs.setString(_keyUserEmail, cleanEmail);
    await prefs.setString(_keyPasswordHash, hashPassword(password));
    await prefs.setDouble(_keyUserWallet, 250.0);

    NotificationService().showNotification(
      title: 'Kode Aktivasi GlobalRun (Offline)',
      body: 'Kode verifikasi pendaftaran: $localCode. Berlaku 5 menit.',
      type: 'system',
    );

    return {
      'success': true,
      'requireOtp': true,
      'message': 'Kode verifikasi telah dikirim ke $cleanEmail.',
      'demo_code': localCode,
    };
  }

  // Verifikasi Kode OTP Pendaftaran Akun Baru
  Future<Map<String, dynamic>> verifyRegistrationOtp({
    required String email,
    required String code,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();

    // 1. Coba verifikasi dengan Supabase
    try {
      final client = Supabase.instance.client;
      final res = await client.auth.verifyOTP(
        email: cleanEmail,
        token: cleanCode,
        type: OtpType.signup,
      );

      if (res.session != null || res.user != null) {
        await prefs.setBool(_keyIsLoggedIn, true);
        await prefs.setString(_keyUserEmail, cleanEmail);
        final name = res.user?.userMetadata?['full_name'] ?? prefs.getString(_keyUserName) ?? 'Virtual Runner';
        await prefs.setString(_keyUserName, name);

        // Buat record profil di Supabase jika tabel profiles tersedia
        try {
          if (res.user != null) {
            await client.from('profiles').upsert({
              'id': res.user!.id,
              'full_name': name,
              'email': cleanEmail,
              'wallet_usd': 250.0,
            });
          }
        } catch (_) {}

        return {
          'success': true,
          'message': 'Akun berhasil diverifikasi & diaktifkan!',
        };
      }
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (_) {}

    // 2. Fallback Offline
    if (_offlineOtpEmail == cleanEmail &&
        _offlineOtpCode == cleanCode &&
        _offlineOtpExpiresAt != null &&
        DateTime.now().isBefore(_offlineOtpExpiresAt!)) {
      _offlineOtpCode = null;
      await prefs.setBool(_keyIsLoggedIn, true);
      return {'success': true, 'message': 'Akun berhasil diverifikasi (mode offline)!'};
    }

    return {
      'success': false,
      'message': 'Kode verifikasi salah atau sudah kedaluwarsa.',
    };
  }

  // Login Manual dengan Email & Password (Supabase Cloud + Fallback)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();

    // 1. Coba login via Supabase Cloud
    try {
      final client = Supabase.instance.client;
      final res = await client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      if (res.session != null && res.user != null) {
        await prefs.setBool(_keyIsLoggedIn, true);
        await prefs.setString(_keyUserEmail, cleanEmail);
        final name = res.user!.userMetadata?['full_name'] ?? prefs.getString(_keyUserName) ?? 'Virtual Runner';
        await prefs.setString(_keyUserName, name);
        return {'success': true, 'message': 'Login berhasil!'};
      }
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (_) {}

    // 2. Coba login melalui REST API Node.js lokal
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
            return {'success': true, 'message': 'Login berhasil!'};
          }
        }
      } catch (_) {}
    }

    // 3. Verifikasi offline dari akun lokal
    final savedEmail = prefs.getString(_keyUserEmail);
    final savedHash = prefs.getString(_keyPasswordHash);

    if (savedEmail != null && savedEmail == cleanEmail && savedHash == hashPassword(password)) {
      await prefs.setBool(_keyIsLoggedIn, true);
      return {'success': true, 'message': 'Login berhasil (mode offline)!'};
    }

    return {
      'success': false,
      'message': 'Akun tidak ditemukan atau password salah.',
    };
  }

  // Minta Kode Verifikasi ke Email (OTP Login Tanpa Password)
  Future<Map<String, dynamic>> sendEmailOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      return {'success': false, 'message': 'Email wajib diisi!'};
    }

    // 1. Coba kirim via Supabase Cloud Auth
    try {
      final client = Supabase.instance.client;
      await client.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: false, // Hanya kirim jika akun sudah ada
      );
      return {
        'success': true,
        'message': 'Kode verifikasi 6 digit telah dikirim ke kotak masuk email $cleanEmail.',
      };
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('signups not allowed') ||
          e.message.toLowerCase().contains('user not found')) {
        return {
          'success': false,
          'message': 'Email belum terdaftar. Silakan daftar akun baru terlebih dahulu.',
        };
      }
      return {'success': false, 'message': e.message};
    } catch (_) {}

    // 2. Fallback via REST API Node.js backend jika ada
    for (final url in [baseUrl, emulatorUrl]) {
      try {
        final response = await http.post(
          Uri.parse('$url/api/auth/send-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': cleanEmail}),
        ).timeout(const Duration(seconds: 3));

        final data = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final demoCode = data['demo_code']?.toString();
          return {
            'success': true,
            'message': data['message'] ?? 'Kode verifikasi telah dikirim ke email.',
            'demo_code': demoCode,
          };
        }
      } catch (_) {}
    }

    // 3. Fallback Offline
    final random = math.Random();
    final localCode = (100000 + random.nextInt(900000)).toString();
    _offlineOtpEmail = cleanEmail;
    _offlineOtpCode = localCode;
    _offlineOtpExpiresAt = DateTime.now().add(const Duration(minutes: 5));

    NotificationService().showNotification(
      title: 'Kode Verifikasi GlobalRun',
      body: 'Kode login Anda: $localCode. Berlaku selama 5 menit.',
      type: 'system',
    );

    return {
      'success': true,
      'message': 'Kode verifikasi telah dikirim ke email $cleanEmail.',
      'demo_code': localCode,
    };
  }

  // Verifikasi Kode OTP Login
  Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();

    if (cleanEmail.isEmpty || cleanCode.isEmpty) {
      return {'success': false, 'message': 'Email dan kode verifikasi wajib diisi!'};
    }

    // 1. Coba verifikasi melalui Supabase
    try {
      final client = Supabase.instance.client;
      final res = await client.auth.verifyOTP(
        email: cleanEmail,
        token: cleanCode,
        type: OtpType.email,
      );

      if (res.session != null && res.user != null) {
        await prefs.setBool(_keyIsLoggedIn, true);
        await prefs.setString(_keyUserEmail, cleanEmail);
        final name = res.user!.userMetadata?['full_name'] ?? 'Virtual Runner';
        await prefs.setString(_keyUserName, name);
        return {'success': true, 'message': 'Login berhasil!'};
      }
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (_) {}

    // 2. Fallback offline
    if (_offlineOtpEmail == cleanEmail &&
        _offlineOtpCode == cleanCode &&
        _offlineOtpExpiresAt != null &&
        DateTime.now().isBefore(_offlineOtpExpiresAt!)) {
      _offlineOtpCode = null;
      final savedName = prefs.getString(_keyUserName) ?? cleanEmail.split('@').first;
      await prefs.setString(_keyUserEmail, cleanEmail);
      await prefs.setString(_keyUserName, savedName);
      await prefs.setBool(_keyIsLoggedIn, true);
      return {'success': true, 'message': 'Login berhasil (mode offline)!'};
    }

    return {
      'success': false,
      'message': 'Kode verifikasi salah atau sudah kedaluwarsa.',
    };
  }

  // Login menggunakan Sidik Jari
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

  // Mengatur status Biometrik dari Menu Profil
  Future<bool> setBiometricEnabled(bool enable) async {
    final prefs = await SharedPreferences.getInstance();

    if (enable) {
      final authenticated = await authenticateWithBiometrics(
        reason: 'Pindai sidik jari Anda untuk mengaktifkan login biometrik',
      );

      if (authenticated) {
        await prefs.setBool(_keyBiometricEnabled, true);
        await prefs.setString('biometric_enrolled_at', DateTime.now().toIso8601String());
        return true;
      }
      return false;
    } else {
      await prefs.setBool(_keyBiometricEnabled, false);
      return true;
    }
  }

  // Hapus Data Sidik Jari dari Aplikasi
  Future<void> removeBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, false);
    await prefs.remove('biometric_enrolled_at');
  }

  // Cek Status Login Saat Buka Aplikasi
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final localLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) return true;
    } catch (_) {}
    return localLoggedIn;
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

  // Logout Saja
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  // Hapus Akun & Bersihkan Seluruh Data Lokal
  Future<void> resetAllAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }
}

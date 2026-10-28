import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyPasswordHash = 'user_pwd_hash';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyUserPhoto = 'user_photo';
  static const String _keyUserWallet = 'user_wallet_balance';
  static const String _keyJwtToken = 'jwt_token';
  static const String _keyUserId = 'user_id';

  static const MethodChannel _settingsChannel = MethodChannel('com.globalrun.app/settings');

  // Base URL backend Node.js REST API (Database Lokal PostgreSQL)
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://192.168.110.5:5000';
  static const String emulatorUrl = 'http://10.0.2.2:5000';
  static const String localhostUrl = 'http://localhost:5000';

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Ambil ID Akun Saat Ini (Supabase UUID atau Lokal Key)
  Future<String?> getCurrentUserId() async {
    try {
      final supaUser = Supabase.instance.client.auth.currentUser;
      if (supaUser != null) return supaUser.id;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId) ?? prefs.getString(_keyUserEmail);
  }

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

  // ─── DUAL DATABASE REGISTRATION (Lokal PostgreSQL + Online Supabase) ────────
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();

    bool localSuccess = false;
    bool onlineSuccess = false;
    String? token;

    // 1. Simpan ke DATABASE LOKAL (Node.js REST API + PostgreSQL Lokal)
    for (final url in [baseUrl, emulatorUrl, localhostUrl]) {
      try {
        final response = await http.post(
          Uri.parse('$url/api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'full_name': cleanName,
            'email': cleanEmail,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          token = data['token'];
          localSuccess = true;
          break;
        } else if (response.statusCode == 409) {
          // Jika email sudah terdaftar di database lokal
          localSuccess = true;
          break;
        }
      } catch (_) {
        // Lanjutkan jika server lokal offline
      }
    }

    // 2. Simpan ke DATABASE ONLINE (Supabase Cloud PostgreSQL)
    try {
      final client = Supabase.instance.client;
      final res = await client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'full_name': cleanName},
      );

      if (res.user != null) {
        onlineSuccess = true;
        // Simpan data profil ke tabel public.profiles di Supabase
        try {
          await client.from('profiles').upsert({
            'id': res.user!.id,
            'full_name': cleanName,
            'email': cleanEmail,
            'wallet_usd': 0.0,
          });
          await prefs.setString(_keyUserId, res.user!.id);
        } catch (_) {}
      }
    } catch (_) {
      // Lanjutkan jika supabase offline/koneksi lambat
    }

    // 3. Simpan Sesi Pengguna ke Local Storage (Aktif & Siap Pakai)
    if (token != null) {
      await prefs.setString(_keyJwtToken, token);
    }
    await prefs.setString(_keyUserName, cleanName);
    await prefs.setString(_keyUserEmail, cleanEmail);
    await prefs.setString(_keyPasswordHash, hashPassword(password));
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setDouble(_keyUserWallet, 0.0);

    return {
      'success': true,
      'localSaved': localSuccess,
      'onlineSaved': onlineSuccess,
      'message': 'Pendaftaran berhasil! Akun Anda aktif di database.',
    };
  }

  // ─── DUAL DATABASE LOGIN (Lokal PostgreSQL + Online Supabase) ───────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();

    // 1. Coba verifikasi dengan DATABASE LOKAL (Node.js REST API + PostgreSQL)
    for (final url in [baseUrl, emulatorUrl, localhostUrl]) {
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
            return {'success': true, 'source': 'local', 'message': 'Login berhasil (Database Lokal)!'};
          }
        }
      } catch (_) {
        // Fallback ke Supabase jika server lokal tidak aktif
      }
    }

    // 2. Coba verifikasi dengan DATABASE ONLINE (Supabase Cloud)
    try {
      final client = Supabase.instance.client;
      final res = await client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      if (res.session != null && res.user != null) {
        await prefs.setBool(_keyIsLoggedIn, true);
        await prefs.setString(_keyUserEmail, cleanEmail);
        await prefs.setString(_keyUserId, res.user!.id);
        var name = res.user!.userMetadata?['full_name'] ?? prefs.getString(_keyUserName) ?? 'Virtual Runner';
        
        // Ambil profil & saldo akun asli dari database Supabase
        try {
          final profileData = await client.from('profiles').select().eq('id', res.user!.id).maybeSingle();
          if (profileData != null) {
            final wallet = (profileData['wallet_usd'] as num?)?.toDouble() ?? 0.0;
            await prefs.setDouble(_keyUserWallet, wallet);
            if (profileData['full_name'] != null && (profileData['full_name'] as String).isNotEmpty) {
              name = profileData['full_name'];
            }
            if (profileData['avatar_url'] != null && (profileData['avatar_url']).toString().isNotEmpty) {
              final avatar = profileData['avatar_url'].toString();
              await prefs.setString(_keyUserPhoto, avatar);
              await prefs.setString('${_keyUserPhoto}_${res.user!.id}', avatar);
            }
          }
        } catch (_) {}

        await prefs.setString(_keyUserName, name);
        return {'success': true, 'source': 'online', 'message': 'Login berhasil (Database Online Supabase)!'};
      }
    } catch (_) {
      // Fallback ke offline cache
    }

    // 3. Fallback Offline Cache: verifikasi dari hash kredensial yang pernah tersimpan
    final savedEmail = prefs.getString(_keyUserEmail);
    final savedHash = prefs.getString(_keyPasswordHash);

    if (savedEmail != null && savedEmail == cleanEmail && savedHash == hashPassword(password)) {
      await prefs.setBool(_keyIsLoggedIn, true);
      return {'success': true, 'source': 'cache', 'message': 'Login berhasil (Mode Cache Offline)!'};
    }

    return {
      'success': false,
      'message': 'Email atau password salah. Silakan periksa kembali akun Anda.',
    };
  }

  // Cek Status Koneksi Kedua Database (Untuk Indikator UI Tugas)
  Future<Map<String, dynamic>> checkDatabaseStatus() async {
    bool localConnected = false;
    bool onlineConnected = false;

    // Cek Database Lokal
    for (final url in [baseUrl, emulatorUrl, localhostUrl]) {
      try {
        final res = await http.get(Uri.parse('$url/api/health')).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          localConnected = true;
          break;
        }
      } catch (_) {}
    }

    // Cek Database Online (Supabase Cloud)
    try {
      final client = Supabase.instance.client;
      await client.from('profiles').select().limit(1).timeout(const Duration(seconds: 2));
      onlineConnected = true;
    } catch (_) {
      // Jika session auth ready, anggap terhubung
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) onlineConnected = true;
      } catch (_) {}
    }

    return {
      'local': localConnected,
      'online': onlineConnected,
      'localLabel': 'PostgreSQL Lokal (Port 5000)',
      'onlineLabel': 'Supabase Cloud (PostgreSQL)',
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

  // Sinkronisasi saldo akun ke Supabase Cloud
  Future<void> _syncWalletToCloud(double newWallet) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client.from('profiles').update({'wallet_usd': newWallet}).eq('id', user.id);
      }
    } catch (e) {
      // Offline fallback
    }
  }

  // Ambil Data Profil Pengguna (Sinkron Cloud & Cache Lokal)
  Future<Map<String, dynamic>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = await getCurrentUserId();
    double wallet = prefs.getDouble(_keyUserWallet) ?? 0.0;
    String name = (uid != null ? prefs.getString('${_keyUserName}_$uid') : null) ??
        prefs.getString(_keyUserName) ??
        '';
    String photo = (uid != null ? prefs.getString('${_keyUserPhoto}_$uid') : null) ??
        prefs.getString(_keyUserPhoto) ??
        '';

    // Tarik saldo & profil terbaru dari Supabase jika online
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final data = await client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 2));
        if (data != null) {
          if (data['wallet_usd'] != null) {
            wallet = (data['wallet_usd'] as num).toDouble();
            await prefs.setDouble(_keyUserWallet, wallet);
          }
          if (data['full_name'] != null && (data['full_name'] as String).isNotEmpty) {
            name = data['full_name'];
            await prefs.setString(_keyUserName, name);
            if (uid != null) await prefs.setString('${_keyUserName}_$uid', name);
          }
          if (data['avatar_url'] != null && (data['avatar_url'] as String).isNotEmpty) {
            final cloudPhoto = data['avatar_url'] as String;
            if (photo.isEmpty || photo.startsWith('http') || !File(photo).existsSync()) {
              photo = cloudPhoto;
              await prefs.setString(_keyUserPhoto, photo);
              if (uid != null) await prefs.setString('${_keyUserPhoto}_$uid', photo);
            }
          }
        }
      }
    } catch (_) {}

    return {
      'name': name,
      'email': prefs.getString(_keyUserEmail) ?? '',
      'wallet': wallet,
      'photo': photo,
      'isBiometricEnabled': prefs.getBool(_keyBiometricEnabled) ?? false,
    };
  }

  // Perbarui Nama dan/atau Foto Profil Pengguna
  Future<void> updateProfile({String? name, String? photoPath}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = await getCurrentUserId();

    if (name != null && name.trim().isNotEmpty) {
      final cleanName = name.trim();
      await prefs.setString(_keyUserName, cleanName);
      if (uid != null) {
        await prefs.setString('${_keyUserName}_$uid', cleanName);
      }
      try {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user != null) {
          await client.from('profiles').update({'full_name': cleanName}).eq('id', user.id);
          await client.auth.updateUser(UserAttributes(data: {'full_name': cleanName}));
        }
      } catch (_) {}
    }

    if (photoPath != null) {
      if (photoPath.isEmpty) {
        await prefs.setString(_keyUserPhoto, '');
        if (uid != null) {
          await prefs.setString('${_keyUserPhoto}_$uid', '');
        }
        try {
          final client = Supabase.instance.client;
          final user = client.auth.currentUser;
          if (user != null) {
            await client.from('profiles').update({'avatar_url': ''}).eq('id', user.id);
          }
        } catch (_) {}
      } else {
        // Simpan lokal terlebih dahulu agar UI instan
        await prefs.setString(_keyUserPhoto, photoPath);
        if (uid != null) {
          await prefs.setString('${_keyUserPhoto}_$uid', photoPath);
        }

        // Upload ke Supabase Storage Bucket 'avatars'
        try {
          final client = Supabase.instance.client;
          final user = client.auth.currentUser;
          if (user != null && !photoPath.startsWith('http')) {
            final file = File(photoPath);
            if (await file.exists()) {
              final ext = photoPath.split('.').last.toLowerCase();
              final safeExt = (ext == 'png' || ext == 'webp') ? ext : 'jpg';
              final fileName = '${user.id}_avatar.$safeExt';

              // Upload ke bucket avatars (upsert = true untuk overwrite)
              await client.storage.from('avatars').upload(
                fileName,
                file,
                fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
              );

              // Ambil Public URL CDN
              final publicUrl = client.storage.from('avatars').getPublicUrl(fileName);
              final publicUrlWithTimestamp = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

              await prefs.setString(_keyUserPhoto, publicUrlWithTimestamp);
              if (uid != null) {
                await prefs.setString('${_keyUserPhoto}_$uid', publicUrlWithTimestamp);
              }
              await client.from('profiles').update({'avatar_url': publicUrlWithTimestamp}).eq('id', user.id);
            }
          }
        } catch (e) {
          // Fallback lokal jika upload gagal atau offline
        }
      }
    }
  }

  double _round4(double v) => (v * 10000).round() / 10000;

  Future<double> getWalletUsd() async {
    final profile = await getUserProfile();
    return (profile['wallet'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> addToWallet(double usd) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble(_keyUserWallet) ?? 0.0;
    final updated = _round4(current + usd);
    await prefs.setDouble(_keyUserWallet, updated);
    await _syncWalletToCloud(updated);
  }

  /// false jika saldo tidak cukup (saldo tidak berubah).
  Future<bool> deductFromWallet(double usd) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble(_keyUserWallet) ?? 0.0;
    if (usd <= 0 || current + 0.0001 < usd) return false;
    final updated = _round4(current - usd);
    await prefs.setDouble(_keyUserWallet, updated);
    await _syncWalletToCloud(updated);
    return true;
  }

  // Logout Saja (Bersihkan cache sesi agar akun berikutnya tidak mewarisi saldo)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyUserWallet);
    await prefs.remove(_keyUserId);
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

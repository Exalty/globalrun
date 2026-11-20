import 'dart:io';
import 'package:flutter/services.dart';

/// Utilitas penerjemah galat teknis/mesin (DNS lookup, Socket, Supabase Paused,
/// Timeout, PlatformException, format HTML) menjadi kalimat bahasa manusia yang
/// santun, mudah dipahami, dan solutif bagi pengguna awam.
class HumanError {
  /// Mengonversi sembarang objek error/exception teknis menjadi pesan ramah pengguna.
  static String toMessage(dynamic error, {String? defaultMessage}) {
    if (error == null) {
      return defaultMessage ?? 'Terjadi kendala sementara. Silakan coba sesaat lagi.';
    }

    // Jika error adalah PlatformException (misal: Biometrik / Izin OS)
    if (error is PlatformException) {
      return _mapPlatformException(error);
    }

    // Jika error adalah SocketException
    if (error is SocketException) {
      return 'Tidak dapat terhubung ke jaringan internet. Periksa koneksi Wi-Fi atau data seluler Anda.';
    }

    final raw = error.toString();
    final lower = raw.toLowerCase();

    // 1. Supabase Paused / Server Maintenance / Cloudflare 503 / 521 / 522
    if (lower.contains('project is paused') ||
        lower.contains('database paused') ||
        lower.contains('paused project') ||
        lower.contains('503') ||
        lower.contains('521') ||
        lower.contains('522') ||
        lower.contains('service unavailable') ||
        lower.contains('server is down') ||
        lower.contains('maintenance') ||
        lower.contains('pemeliharaan') ||
        lower.contains('<!doctype html>')) {
      return 'Layanan database online sedang dalam pemeliharaan berkala. Jika Anda pernah masuk sebelumnya, Anda tetap dapat login dalam Mode Offline.';
    }

    // 2. DNS Host Lookup Gagal (Host tidak ditemukan / offline / domain paused)
    if (lower.contains('failed host lookup') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('clientexception') ||
        lower.contains('socketexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('broken pipe') ||
        lower.contains('software caused connection abort')) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda atau coba beberapa saat lagi.';
    }

    // 3. Timeout / Koneksi Lambat
    if (lower.contains('timeout') ||
        lower.contains('timeoutexception') ||
        lower.contains('timed out') ||
        lower.contains('deadline exceeded')) {
      return 'Waktu koneksi habis saat menghubungi server. Mohon periksa kestabilan sinyal internet Anda.';
    }

    // 4. Kredensial Login / Autentikasi
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_grant') ||
        lower.contains('invalid credential') ||
        lower.contains('wrong password') ||
        lower.contains('invalid username or password')) {
      return 'Email atau kata sandi tidak cocok. Silakan periksa kembali.';
    }

    // 5. Email Sudah Terdaftar
    if (lower.contains('user already registered') ||
        lower.contains('already registered') ||
        lower.contains('user already exists') ||
        lower.contains('duplicate key') ||
        lower.contains('email already in use')) {
      return 'Email ini sudah terdaftar. Silakan langsung masuk menggunakan kata sandi Anda.';
    }

    // 6. Validasi Format Email / Password
    if (lower.contains('password should be at least 6 characters') ||
        lower.contains('password must be at least')) {
      return 'Kata sandi minimal harus 6 karakter.';
    }
    if (lower.contains('invalid email') || lower.contains('unable to validate email address')) {
      return 'Format alamat email tidak valid. Contoh yang benar: nama@domain.com.';
    }

    // 7. Limit / Terlalu Banyak Percobaan
    if (lower.contains('too many requests') ||
        lower.contains('rate limit') ||
        lower.contains('rate_limit') ||
        lower.contains('over_rate_limit') ||
        lower.contains('429')) {
      return 'Terlalu banyak percobaan. Harap tunggu sekitar 1 menit sebelum mencoba kembali.';
    }

    // 8. Izin Perangkat (Kamera, Galeri, Penyimpanan)
    if (lower.contains('permission_denied') ||
        lower.contains('permission denied') ||
        lower.contains('access denied') ||
        lower.contains('camera permission') ||
        lower.contains('storage permission') ||
        lower.contains('photo_access_denied')) {
      return 'Izin akses perangkat belum diberikan. Silakan aktifkan izin di Pengaturan Aplikasi HP Anda.';
    }

    // 9. Hardware / Sensor Biometrik
    if (lower.contains('notenrolled') || lower.contains('not enrolled')) {
      return 'Belum ada sidik jari yang didaftarkan. Silakan daftarkan sidik jari di Pengaturan Keamanan HP Anda.';
    }
    if (lower.contains('lockedout') || lower.contains('permanentlylockedout')) {
      return 'Sensor sidik jari terkunci sementara karena beberapa kali salah coba. Tunggu beberapa detik.';
    }

    // 10. Blockchain Gas / Saldo Relayer
    if (lower.contains('insufficient funds') || lower.contains('gas required exceeds')) {
      return 'Saldo gas fee pada jaringan blockchain relayer sedang tidak mencukupi untuk mencetak transaksi ini.';
    }

    // Jika pesan sudah berupa kalimat bahasa Indonesia yang rapi (tidak mengandung kata kunci teknis), tampilkan langsung
    if (!_looksLikeTechnicalString(raw)) {
      return raw;
    }

    // Fallback default yang aman dan ramah
    return defaultMessage ?? 'Terjadi kendala sementara pada sistem. Silakan coba sesaat lagi.';
  }

  /// Mendeteksi apakah error disebabkan oleh matinya server atau koneksi offline.
  static bool isOfflineOrMaintenance(dynamic error) {
    if (error == null) return false;
    final lower = error.toString().toLowerCase();
    return lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('project is paused') ||
        lower.contains('503') ||
        lower.contains('521') ||
        lower.contains('522') ||
        lower.contains('clientexception') ||
        lower.contains('network') ||
        lower.contains('timeout');
  }

  /// Memetakan error spesifik PlatformException sistem OS
  static String _mapPlatformException(PlatformException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();

    if (code == 'notenrolled' || message.contains('not enrolled')) {
      return 'Belum ada sidik jari yang didaftarkan di Pengaturan HP Anda.';
    }
    if (code == 'lockedout' || code == 'permanentlylockedout' || message.contains('locked out')) {
      return 'Sensor sidik jari terkunci sementara karena terlalu banyak percobaan salah. Coba lagi dalam 30 detik.';
    }
    if (code == 'passcodenotset' || message.contains('passcode not set')) {
      return 'Kunci layar (PIN/Pola) belum diaktifkan di HP Anda.';
    }
    if (code == 'notavailable' || message.contains('not available')) {
      return 'Sensor biometrik tidak tersedia pada perangkat ini.';
    }
    if (code == 'photo_access_denied' || message.contains('permission')) {
      return 'Izin akses kamera atau galeri foto belum diberikan.';
    }

    return 'Kendala sensor perangkat. Silakan coba gunakan kata sandi Anda.';
  }

  /// Memeriksa apakah string terlihat seperti exception/terminal mentah
  static bool _looksLikeTechnicalString(String s) {
    final lower = s.toLowerCase();
    return lower.contains('exception') ||
        lower.contains('error:') ||
        lower.contains('http ') ||
        lower.contains('errno') ||
        lower.contains('stack trace') ||
        lower.contains('{') ||
        lower.contains('}') ||
        lower.contains('null') ||
        lower.contains('failed host lookup') ||
        lower.contains('supabase') ||
        lower.contains('.dart') ||
        lower.contains('line ');
  }
}

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runcompete/utils/human_error.dart';

void main() {
  group('HumanError Translation Tests', () {
    test('Translates DNS Host Lookup failure into friendly connection message', () {
      const rawError = "ClientException: Failed host lookup: 'sgrphzxpdpivbxbdiknb.supabase.co' (OS Error: No address associated with hostname, errno = 7)";
      final msg = HumanError.toMessage(rawError);

      expect(msg, contains('Tidak dapat terhubung ke server'));
      expect(msg.contains('ClientException'), isFalse);
      expect(msg.contains('errno'), isFalse);
      expect(msg.contains('sgrphzxpdpivbxbdiknb'), isFalse);
    });

    test('Translates Supabase project paused / HTTP 503 into friendly maintenance message', () {
      const rawError = "AuthException(message: Project is paused, statusCode: 503)";
      final msg = HumanError.toMessage(rawError);

      expect(msg, contains('pemeliharaan berkala'));
      expect(msg.contains('AuthException'), isFalse);
      expect(msg.contains('503'), isFalse);
    });

    test('Translates HTML error response (e.g. Cloudflare / gateway 503)', () {
      const rawError = "FormatException: Unexpected character (at character 1) <!DOCTYPE html><html><head><title>503 Service Unavailable</title></head>...";
      final msg = HumanError.toMessage(rawError);

      expect(msg, contains('pemeliharaan'));
      expect(msg.contains('<!DOCTYPE html>'), isFalse);
    });

    test('Translates SocketException connection refused', () {
      const socketErr = SocketException("Connection refused, errno = 111");
      final msg = HumanError.toMessage(socketErr);

      expect(msg, contains('Tidak dapat terhubung ke jaringan internet'));
      expect(msg.contains('errno'), isFalse);
    });

    test('Translates invalid credentials', () {
      const raw = "AuthException(message: Invalid login credentials, statusCode: 400)";
      final msg = HumanError.toMessage(raw);

      expect(msg, equals('Email atau kata sandi tidak cocok. Silakan periksa kembali.'));
    });

    test('Translates user already registered', () {
      const raw = "AuthException(message: User already registered, statusCode: 422)";
      final msg = HumanError.toMessage(raw);

      expect(msg, equals('Email ini sudah terdaftar. Silakan langsung masuk menggunakan kata sandi Anda.'));
    });

    test('Translates PlatformException NotEnrolled', () {
      final pe = PlatformException(code: 'NotEnrolled', message: 'No fingerprints enrolled');
      final msg = HumanError.toMessage(pe);

      expect(msg, contains('Belum ada sidik jari yang didaftarkan'));
      expect(msg.contains('NotEnrolled'), isFalse);
    });

    test('Passes clean Indonesian messages through without mangling', () {
      const clean = 'Nama lengkap wajib diisi!';
      final msg = HumanError.toMessage(clean);

      expect(msg, equals('Nama lengkap wajib diisi!'));
    });

    test('Correctly identifies offline/maintenance status', () {
      expect(HumanError.isOfflineOrMaintenance("Failed host lookup"), isTrue);
      expect(HumanError.isOfflineOrMaintenance("Project is paused"), isTrue);
      expect(HumanError.isOfflineOrMaintenance("Invalid login credentials"), isFalse);
    });
  });
}

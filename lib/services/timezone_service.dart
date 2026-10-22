import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Asal data offset suatu zona waktu.
enum TimezoneSource { api, local, defaultOffset }

class TimezoneModel {
  final String label;
  final String code; // e.g., WIB, WITA, WIT, GMT, JST, EST
  final int offsetHours; // dibulatkan, dipertahankan agar UI lama tetap jalan
  final int? offsetSeconds; // offset presisi (mendukung +05:30 dsb.)
  final String flag;
  final String? ianaTz; // nama zona IANA

  const TimezoneModel({
    required this.label,
    required this.code,
    required this.offsetHours,
    required this.flag,
    this.offsetSeconds,
    this.ianaTz,
  });

  /// Offset presisi dalam detik.
  int get totalOffsetSeconds => offsetSeconds ?? offsetHours * 3600;

  TimezoneModel copyWith({int? offsetHours, int? offsetSeconds}) {
    final secs = offsetSeconds ??
        (offsetHours != null ? offsetHours * 3600 : this.offsetSeconds);
    return TimezoneModel(
      label: label,
      code: code,
      offsetHours: secs != null ? (secs / 3600).round() : this.offsetHours,
      offsetSeconds: secs,
      flag: flag,
      ianaTz: ianaTz,
    );
  }
}

class _ZoneResult {
  final TimezoneModel zone;
  final TimezoneSource source;
  const _ZoneResult(this.zone, this.source);
}

class TimezoneService extends ChangeNotifier {
  // ─── Singleton ──────────────────────────────────────────────────────
  static final TimezoneService _instance = TimezoneService._internal();
  factory TimezoneService() => _instance;
  TimezoneService._internal();

  static const String _prefSelectedTimezone = 'selected_timezone_code';

  // ─── API Config (TimeAPI.io, tanpa API key) ────────────────────────
  static const String _apiHost = 'timeapi.io';
  static const String _apiPath = '/api/timezone/zone';
  static const Duration _timeout = Duration(seconds: 8);

  // ─── State ─────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _tzDbReady = false;
  String? _lastError;
  DateTime? _lastUpdated;
  int _selectedIndex = 0;
  final Map<String, TimezoneSource> _zoneSources = {};

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  DateTime? get lastUpdated => _lastUpdated;

  int get _apiCount =>
      _zoneSources.values.where((s) => s == TimezoneSource.api).length;
  int get _localCount =>
      _zoneSources.values.where((s) => s == TimezoneSource.local).length;

  /// True jika minimal satu zona berhasil diambil dari API.
  bool get hasApiData => _apiCount > 0;

  /// Sumber data dominan untuk ditampilkan di UI.
  TimezoneSource get overallSource {
    if (_apiCount > 0) return TimezoneSource.api;
    if (_localCount > 0) return TimezoneSource.local;
    return TimezoneSource.defaultOffset;
  }

  /// Label siap tampil di UI, misalnya di bawah daftar zona waktu.
  String get sourceLabel {
    final total = supportedZones.length;
    if (_zoneSources.isEmpty) return 'Sumber: offset bawaan';
    if (_apiCount == total) return 'Sumber: API (TimeAPI.io)';
    if (_apiCount > 0) {
      return 'Sumber: API ($_apiCount/$total zona), sisanya hitungan lokal';
    }
    if (_localCount > 0) {
      return 'Sumber: perhitungan lokal (API tidak tersedia)';
    }
    return 'Sumber: offset bawaan';
  }

  TimezoneSource sourceOf(TimezoneModel zone) =>
      _zoneSources[zone.code] ?? TimezoneSource.defaultOffset;

  // ─── Daftar zona waktu yang didukung ───────────────────────────────
  List<TimezoneModel> supportedZones = const [
    TimezoneModel(label: 'Indonesia Barat (WIB)', code: 'WIB', offsetHours: 7, flag: '🇮🇩', ianaTz: 'Asia/Jakarta'),
    TimezoneModel(label: 'Indonesia Tengah (WITA)', code: 'WITA', offsetHours: 8, flag: '🇮🇩', ianaTz: 'Asia/Makassar'),
    TimezoneModel(label: 'Indonesia Timur (WIT)', code: 'WIT', offsetHours: 9, flag: '🇮🇩', ianaTz: 'Asia/Jayapura'),
    TimezoneModel(label: 'London / UTC (GMT)', code: 'GMT', offsetHours: 0, flag: '🇬🇧', ianaTz: 'Europe/London'),
    TimezoneModel(label: 'Tokyo (JST)', code: 'JST', offsetHours: 9, flag: '🇯🇵', ianaTz: 'Asia/Tokyo'),
    TimezoneModel(label: 'New York (EDT/EST)', code: 'EST', offsetHours: -4, flag: '🇺🇸', ianaTz: 'America/New_York'),
    TimezoneModel(label: 'Sydney (AEST)', code: 'AEST', offsetHours: 10, flag: '🇦🇺', ianaTz: 'Australia/Sydney'),
    TimezoneModel(label: 'Dubai (GST)', code: 'GST', offsetHours: 4, flag: '🇦🇪', ianaTz: 'Asia/Dubai'),
  ];

  TimezoneModel get selectedTimezone => supportedZones[_selectedIndex];

  // ─── Inisialisasi ─────────────────────────────────────────────────
  Future<void> init() async {
    // Siapkan database zona waktu lokal untuk fallback offline
    try {
      tzdata.initializeTimeZones();
      _tzDbReady = true;
    } catch (e) {
      debugPrint('⚠️ TimezoneService: gagal memuat database zona waktu lokal: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefSelectedTimezone);
    if (savedCode != null) {
      final idx = supportedZones.indexWhere((z) => z.code == savedCode);
      if (idx >= 0) _selectedIndex = idx;
    }
    notifyListeners();

    await fetchTimezonesFromApi();
  }

  // ─── Ambil offset: API → hitungan lokal → offset bawaan ────────────
  Future<void> fetchTimezonesFromApi() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    // Semua zona diambil paralel agar cepat
    final results = await Future.wait(supportedZones.map(_resolveZone));

    supportedZones = results.map((r) => r.zone).toList();
    _zoneSources
      ..clear()
      ..addEntries(results.map((r) => MapEntry(r.zone.code, r.source)));

    if (_apiCount > 0) {
      _lastUpdated = DateTime.now();
      debugPrint('✅ TimezoneService: $_apiCount/${supportedZones.length} zona dari API (TimeAPI.io), '
          '$_localCount dari hitungan lokal');
    } else if (_localCount > 0) {
      _lastError = 'API zona waktu tidak tersedia, memakai perhitungan lokal';
      _lastUpdated = DateTime.now();
      debugPrint('⚠️ TimezoneService: API gagal, memakai hitungan lokal (database IANA)');
    } else {
      _lastError = 'Gagal mengambil data zona waktu';
      debugPrint('⚠️ TimezoneService: API dan hitungan lokal gagal, memakai offset bawaan');
    }

    for (final z in supportedZones) {
      debugPrint('   ${z.flag} ${z.code}: ${getOffsetLabel(z)} [${sourceOf(z).name}]');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<_ZoneResult> _resolveZone(TimezoneModel zone) async {
    final iana = zone.ianaTz;
    if (iana == null) return _ZoneResult(zone, TimezoneSource.defaultOffset);

    // 1) API eksternal
    try {
      final uri = Uri.https(_apiHost, _apiPath, {'timeZone': iana});
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final seconds = (data['currentUtcOffset']?['seconds'] as num?)?.toInt();
        if (seconds != null) {
          return _ZoneResult(
              zone.copyWith(offsetSeconds: seconds), TimezoneSource.api);
        }
        debugPrint('⚠️ TimezoneService: format respons tak terduga untuk $iana');
      } else {
        debugPrint('⚠️ TimezoneService: $iana HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ TimezoneService: gagal fetch $iana: $e');
    }

    // 2) Fallback lokal: database IANA (sudah menghitung DST)
    if (_tzDbReady) {
      try {
        final location = tz.getLocation(iana);
        final seconds = tz.TZDateTime.now(location).timeZoneOffset.inSeconds;
        return _ZoneResult(
            zone.copyWith(offsetSeconds: seconds), TimezoneSource.local);
      } catch (e) {
        debugPrint('⚠️ TimezoneService: hitungan lokal gagal untuk $iana: $e');
      }
    }

    // 3) Terakhir: offset bawaan
    return _ZoneResult(zone, TimezoneSource.defaultOffset);
  }

  // ─── Pilih Zona Waktu ──────────────────────────────────────────────
  Future<void> setSelectedTimezone(TimezoneModel zone) async {
    final idx = supportedZones.indexWhere((z) => z.code == zone.code);
    if (idx < 0 || idx == _selectedIndex) return;

    _selectedIndex = idx;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSelectedTimezone, zone.code);
  }

  // ─── Format waktu untuk zona tertentu ──────────────────────────────
  String formatForZone(DateTime utcTime, TimezoneModel zone) {
    final converted =
        utcTime.toUtc().add(Duration(seconds: zone.totalOffsetSeconds));
    final formatter = DateFormat('EEE, d MMM yyyy • HH:mm');
    return '${formatter.format(converted)} ${zone.code}';
  }

  static String getRelativeCountdown(DateTime utcTime) {
    final now = DateTime.now().toUtc();
    final diff = utcTime.difference(now);

    if (diff.isNegative) {
      final abs = diff.abs();
      if (abs.inMinutes < 60) return 'Dimulai ${abs.inMinutes} mnt lalu';
      if (abs.inHours < 24) return 'Dimulai ${abs.inHours} jam lalu';
      return 'Event Sedang Berlangsung / Selesai';
    }

    if (diff.inDays > 0) {
      return 'Dalam ${diff.inDays} hari ${diff.inHours % 24} jam';
    } else if (diff.inHours > 0) {
      return 'Dalam ${diff.inHours} jam ${diff.inMinutes % 60} mnt';
    } else {
      return 'Dalam ${diff.inMinutes} menit!';
    }
  }

  /// Label offset untuk UI, mis. "UTC+7", "UTC-4", "UTC+5:30".
  String getOffsetLabel(TimezoneModel zone) {
    final total = zone.totalOffsetSeconds;
    final sign = total >= 0 ? '+' : '-';
    final absMinutes = total.abs() ~/ 60;
    final h = absMinutes ~/ 60;
    final m = absMinutes % 60;
    return m == 0
        ? 'UTC$sign$h'
        : 'UTC$sign$h:${m.toString().padLeft(2, '0')}';
  }
}
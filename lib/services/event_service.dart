import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/race_event.dart';

class EventService extends ChangeNotifier {
  // URLs for physical device, emulator, and localhost
  static String get _cloudUrl => dotenv.env['PUBLIC_TUNNEL_URL'] ?? 'https://globalrun.vercel.app';
  static String get _primaryUrl => dotenv.env['API_BASE_URL'] ?? 'http://192.168.110.5:5000';
  static const String _emulatorUrl = 'http://10.0.2.2:5000';
  static const String _localUrl = 'http://localhost:5000';

  // Endpoint API Publik Resmi RunSignup dengan filter rentang lomba (maksimal 3 hari lampau s/d 90 hari mendatang)
  static String _buildRunSignupApiUrl() {
    final now = DateTime.now().toUtc();
    final threeDaysAgo = now.subtract(const Duration(days: 3));
    final startStr =
        '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';
    final ninetyDaysLater = now.add(const Duration(days: 90));
    final endStr =
        '${ninetyDaysLater.year}-${ninetyDaysLater.month.toString().padLeft(2, '0')}-${ninetyDaysLater.day.toString().padLeft(2, '0')}';

    return 'https://runsignup.com/Rest/races?format=json&results_per_page=16&start_date=$startStr&end_date=$endStr&event_type=running_race';
  }

  static const String _cacheKey = 'cached_race_events_json';

  List<RaceEvent> _events = RaceEvent.sampleEvents();
  bool _isLoading = false;
  bool _isLiveFromBackend = false;
  String? _errorMessage;

  List<RaceEvent> get events => _events;
  bool get isLoading => _isLoading;
  bool get isLiveFromBackend => _isLiveFromBackend;
  String? get errorMessage => _errorMessage;

  EventService() {
    _loadCachedEvents();
  }

  void _safeNotifyListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  // Load cache from local storage first for instant display
  Future<void> _loadCachedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        _events = decoded.map((item) => RaceEvent.fromJson(item)).toList();
        _safeNotifyListeners();
      }
    } catch (_) {
      // Keep sampleEvents if cache fails
    }
  }

  // Fetch live events from Backend API (which connects to RunSignup & PostgreSQL)
  Future<void> fetchEvents({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    final urlsToTry = [
      _cloudUrl,
      _primaryUrl,
      _emulatorUrl,
      _localUrl,
    ];

    bool success = false;

    // 1. Coba ambil dari Backend REST API (Vercel Cloud atau Server Lokal)
    for (final base in urlsToTry) {
      try {
        final uri = Uri.parse('$base/api/events${forceRefresh ? '?refresh=true' : ''}');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['events'] is List) {
            final List<dynamic> list = data['events'];
            _events = list.map((item) => RaceEvent.fromJson(item)).toList();
            _isLiveFromBackend = true;
            _errorMessage = null;
            success = true;

            // Save to persistent cache
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_cacheKey, jsonEncode(list));

            break;
          }
        }
      } catch (e) {
        // Continue to try next URL
      }
    }

    // 2. Jika backend offline/tertutup, ambil LANGSUNG dari RunSignup Open REST API (Live Feed Global)
    if (!success) {
      try {
        final uri = Uri.parse(_buildRunSignupApiUrl());
        final response = await http.get(uri).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic> && data['races'] is List) {
            final List<dynamic> raceList = data['races'];
            final liveRaces = raceList
                .map((item) => RaceEvent.fromRunSignup(item as Map<String, dynamic>))
                .toList();

            final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 3));
            // Filter hanya lomba yang belum lewat, atau baru lewat maksimal 3 hari
            final validLiveRaces = liveRaces.where((r) => !r.startTimeUtc.isBefore(cutoff)).toList();

            // Gabungkan dengan lomba utama terkurasi (Tokyo, Maybank Bali, Borobudur)
            final combined = <RaceEvent>[];
            combined.addAll(RaceEvent.sampleEvents().where((s) => !s.startTimeUtc.isBefore(cutoff)));
            for (final live in validLiveRaces) {
              if (!combined.any((c) => c.title.toLowerCase() == live.title.toLowerCase())) {
                combined.add(live);
              }
            }

            _events = combined;
            _isLiveFromBackend = true;
            _errorMessage = null;
            success = true;

            // Simpan cache lokal
            final prefs = await SharedPreferences.getInstance();
            final cachedData = _events.map((e) => e.toJson()).toList();
            await prefs.setString(_cacheKey, jsonEncode(cachedData));
          }
        }
      } catch (e) {
        debugPrint('[EventService] RunSignup Direct API fetch error: $e');
      }
    }

    // 3. Coba ambil dari database Supabase Cloud (tabel race_events) jika API eksternal gagal
    if (!success) {
      try {
        final client = Supabase.instance.client;
        final rows = await client
            .from('race_events')
            .select('*')
            .order('id', ascending: true);
        if (rows.isNotEmpty) {
          _events = rows.map((item) => RaceEvent.fromJson(item)).toList();
          _isLiveFromBackend = true;
          _errorMessage = null;
          success = true;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, jsonEncode(rows));
        }
      } catch (e) {
        debugPrint('[EventService] Supabase fetch fallback: $e');
      }
    }

    if (!success) {
      if (_events.isEmpty) {
        _events = RaceEvent.sampleEvents();
      }
      _isLiveFromBackend = false;
      _errorMessage = 'Menggunakan cache offline lomba.';
    }

    _isLoading = false;
    _safeNotifyListeners();
  }
}


import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/race_event.dart';

class EventService extends ChangeNotifier {
  // URLs for physical device, emulator, and localhost
  static String get _primaryUrl => dotenv.env['API_BASE_URL'] ?? 'http://192.168.110.5:5000';
  static const String _emulatorUrl = 'http://10.0.2.2:5000';
  static const String _localUrl = 'http://localhost:5000';

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
      _primaryUrl,
      _emulatorUrl,
      _localUrl,
    ];

    bool success = false;

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


import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyRate {
  final String code; // USD, IDR, EUR, GBP, JPY, SGD
  final String symbol;
  final String name;
  final double ratePerUsd; // base 1 USD = rate

  const CurrencyRate({
    required this.code,
    required this.symbol,
    required this.name,
    required this.ratePerUsd,
  });

  CurrencyRate copyWith({double? ratePerUsd}) {
    return CurrencyRate(
      code: code,
      symbol: symbol,
      name: name,
      ratePerUsd: ratePerUsd ?? this.ratePerUsd,
    );
  }
}

class CurrencyService extends ChangeNotifier {
  // ─── Singleton ──────────────────────────────────────────────────────
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  // ─── Pref key ──────────────────────────────────────────────────────
  static const String _prefSelectedCurrency = 'selected_currency';

  // ─── API Config (Free, no key required) ────────────────────────────
  static const String _apiBaseUrl = 'https://open.er-api.com/v6/latest/USD';

  // ─── State ─────────────────────────────────────────────────────────
  String _selectedCurrency = 'USD';
  bool _isLoading = false;
  bool _hasApiData = false;
  String? _lastError;
  DateTime? _lastUpdated;

  String get selectedCurrency => _selectedCurrency;
  bool get isLoading => _isLoading;
  bool get hasApiData => _hasApiData;
  String? get lastError => _lastError;
  DateTime? get lastUpdated => _lastUpdated;

  // ─── Metadata mata uang (symbol & nama) ────────────────────────────
  static const Map<String, Map<String, String>> _currencyMeta = {
    'USD': {'symbol': '\$', 'name': 'US Dollar'},
    'IDR': {'symbol': 'Rp', 'name': 'Indonesian Rupiah'},
    'EUR': {'symbol': '€', 'name': 'Euro'},
    'GBP': {'symbol': '£', 'name': 'British Pound'},
    'JPY': {'symbol': '¥', 'name': 'Japanese Yen'},
    'SGD': {'symbol': 'S\$', 'name': 'Singapore Dollar'},
    'AUD': {'symbol': 'A\$', 'name': 'Australian Dollar'},
  };

  // ─── Default fallback rates (saat API offline) ────────────────────
  static const Map<String, double> _fallbackRates = {
    'USD': 1.0,
    'IDR': 16250.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'JPY': 154.5,
    'SGD': 1.35,
    'AUD': 1.52,
  };

  // ─── Rates yang aktif (diperbarui dari API atau fallback) ──────────
  Map<String, CurrencyRate> currencies = {};

  // ─── Inisialisasi ─────────────────────────────────────────────────
  /// Dipanggil sekali saat app startup. Memuat preferensi & fetch API.
  Future<void> init() async {
    // Load fallback terlebih dahulu agar UI bisa langsung render
    _loadFallbackRates();

    // Load preferensi mata uang yang disimpan user
    final prefs = await SharedPreferences.getInstance();
    _selectedCurrency = prefs.getString(_prefSelectedCurrency) ?? 'USD';
    notifyListeners();

    // Fetch real-time dari API
    await fetchRatesFromApi();
  }

  void _loadFallbackRates() {
    currencies = {};
    for (final entry in _fallbackRates.entries) {
      final meta = _currencyMeta[entry.key];
      currencies[entry.key] = CurrencyRate(
        code: entry.key,
        symbol: meta?['symbol'] ?? entry.key,
        name: meta?['name'] ?? entry.key,
        ratePerUsd: entry.value,
      );
    }
  }

  // ─── Fetch dari API Eksternal ──────────────────────────────────────
  /// Mengambil kurs terbaru dari open.er-api.com (gratis, tanpa API key).
  /// Endpoint: GET https://open.er-api.com/v6/latest/USD
  Future<void> fetchRatesFromApi() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(_apiBaseUrl),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['result'] == 'success' && data['rates'] != null) {
          final Map<String, dynamic> apiRates = data['rates'];

          // Update hanya mata uang yang kita support
          for (final code in _currencyMeta.keys) {
            if (apiRates.containsKey(code)) {
              final apiRate = (apiRates[code] as num).toDouble();
              final meta = _currencyMeta[code]!;
              currencies[code] = CurrencyRate(
                code: code,
                symbol: meta['symbol']!,
                name: meta['name']!,
                ratePerUsd: apiRate,
              );
            }
          }

          _hasApiData = true;
          _lastUpdated = DateTime.now();
          _lastError = null;

          debugPrint('✅ CurrencyService: Kurs berhasil diperbarui dari API');
          debugPrint('   Contoh: 1 USD = ${currencies["IDR"]?.ratePerUsd} IDR');
          debugPrint('   Contoh: 1 USD = ${currencies["EUR"]?.ratePerUsd} EUR');
          debugPrint('   Contoh: 1 USD = ${currencies["JPY"]?.ratePerUsd} JPY');
        } else {
          _lastError = 'Format respons API tidak valid';
          debugPrint('⚠️ CurrencyService: Format API tidak valid');
        }
      } else {
        _lastError = 'API error: HTTP ${response.statusCode}';
        debugPrint('⚠️ CurrencyService: HTTP ${response.statusCode}');
      }
    } catch (e) {
      _lastError = 'Gagal terhubung ke API kurs: $e';
      debugPrint('⚠️ CurrencyService: Gagal fetch API → menggunakan fallback');
      debugPrint('   Error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Pilih Mata Uang ──────────────────────────────────────────────
  Future<void> setSelectedCurrency(String code) async {
    if (_selectedCurrency == code) return;
    _selectedCurrency = code;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSelectedCurrency, code);
  }

  // ─── Konversi ──────────────────────────────────────────────────────
  double convert(double amountUsd, String targetCurrencyCode) {
    final rate = currencies[targetCurrencyCode]?.ratePerUsd ?? 1.0;
    return amountUsd * rate;
  }

  String formatCurrency(double amountUsd, String targetCurrencyCode) {
    final rate = currencies[targetCurrencyCode] ?? currencies['USD']!;
    final converted = amountUsd * rate.ratePerUsd;

    if (rate.code == 'IDR' || rate.code == 'JPY') {
      final formatter = NumberFormat('#,###', 'id_ID');
      return '${rate.symbol} ${formatter.format(converted.round())}';
    } else {
      final formatter = NumberFormat('#,##0.00', 'en_US');
      return '${rate.symbol}${formatter.format(converted)}';
    }
  }

  // ─── Backward-compatible static helpers ────────────────────────────
  /// Agar kode lama yang memanggil CurrencyService.formatCurrency(...)
  /// secara statis tetap jalan tanpa error.
  static String formatCurrencyStatic(double amountUsd, String targetCurrencyCode) {
    return _instance.formatCurrency(amountUsd, targetCurrencyCode);
  }

  static double convertStatic(double amountUsd, String targetCurrencyCode) {
    return _instance.convert(amountUsd, targetCurrencyCode);
  }

  /// Label kurs untuk ditampilkan di UI info badge
  String getRateLabel(String code) {
    final rate = currencies[code];
    if (rate == null) return '';
    if (code == 'USD') return '1 USD (base)';
    return '1 USD = ${rate.ratePerUsd.toStringAsFixed(code == 'IDR' || code == 'JPY' ? 0 : 4)} $code';
  }
}

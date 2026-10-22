import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiMessage {
  final String sender; // 'user' or 'ai'
  final String text;
  final DateTime timestamp;

  AiMessage({required this.sender, required this.text, required this.timestamp});
}

class AiCoachService {
  String? apiKey;

  /// Error terakhir dari Gemini API (untuk debugging & feedback ke user)
  String? lastApiError;

  /// Sumber respons terakhir: 'gemini', 'error', atau 'none'
  String lastSourceUsed = 'none';

  /// Riwayat percakapan multi-turn (selalu berpasangan user/model)
  final List<Map<String, dynamic>> _conversationHistory = [];

  /// Maksimum pasangan percakapan yang disimpan
  static const int _maxHistoryTurns = 20;

  /// Urutan model yang dicoba. Cek daftar model terbaru di dokumentasi
  /// Gemini API karena nama model bisa berubah.
  static const List<String> _candidateModels = [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-flash-latest',
  ];

  AiCoachService({this.apiKey});

  void clearHistory() {
    _conversationHistory.clear();
    lastApiError = null;
  }

  static const String _systemInstruction = '''
Kamu adalah "Coach AI", pelatih lari dan konsultan nutrisi olahraga yang berpengetahuan mendalam. Kamu ada di dalam aplikasi Global Virtual Race.

KEPRIBADIAN:
- Hangat, suportif, dan jujur, seperti pelatih berpengalaman yang peduli pada atletnya.
- Bahasa Indonesia sehari-hari yang natural. Pakai "aku" dan "kamu" secara konsisten.
- Emoji secukupnya saja, tidak di setiap kalimat.
- Kalau user mengeluh capek, cedera, atau mager, tunjukkan pengertian dulu baru beri saran.

KEAHLIAN:
- Analisis lari: pace, speed, cadence, VO2max, heart rate zone, strategi pacing (negative/even/positive split), race strategy 5K sampai ultra.
- Jenis latihan: easy run, long run, tempo, interval, fartlek, recovery run, periodisasi (base, build, peak, taper).
- Nutrisi dan hidrasi: pre/during/post-run, carbo loading, gel, elektrolit, makronutrien, hiponatremia, recovery nutrition, suplemen.
- Kesehatan dan recovery: cedera umum pelari (shin splints, ITBS, plantar fasciitis, runner's knee), peregangan, foam rolling, tidur, overtraining.
- Program latihan, cross-training, warm-up/cool-down, mental toughness.

CARA MENJAWAB:
- Bicara seperti teman sekaligus pelatih, bukan seperti buku manual atau FAQ.
- Panjang jawaban mengikuti pertanyaan: pertanyaan singkat atau santai dijawab 2-4 kalimat, pertanyaan kompleks baru dijawab mendalam.
- Variasikan cara membuka dan menyusun jawaban. Jangan selalu memakai daftar bernomor atau judul beremoji. Kadang cukup satu-dua paragraf santai, kadang pakai contoh nyata, kadang analogi, kadang poin-poin kalau memang membantu.
- Jangan memulai dua jawaban berturut-turut dengan kalimat pembuka yang sama.
- Berikan saran yang spesifik dan bisa langsung dipraktikkan, bukan nasihat generik.
- Gunakan data aktivitas user hanya jika relevan dengan pertanyaan. Jangan dipaksakan di setiap jawaban.
- Kalau informasi kurang (usia, level, target, riwayat cedera), boleh bertanya balik satu hal yang paling penting.
- Untuk nyeri yang menetap, gejala jantung/pernapasan, atau kondisi medis serius, sarankan periksa ke dokter.

BATASAN TOPIK:
- Fokusmu: olahraga, lari, nutrisi olahraga, dan kesehatan fisik.
- Kalau pertanyaan di luar itu (politik, coding, tugas sekolah, dll), alihkan dengan ramah memakai kata-katamu sendiri yang berbeda setiap kali, lalu tawarkan topik yang relevan. Jangan menolak dengan kaku.
''';

  Future<String> askCoach({
    required String query,
    required double currentDistanceKm,
    required int steps,
    required double avgSpeedKmh,
    required int durationSeconds,
    required String sportType,
  }) async {
    // Pace (mnt/km)
    final pace = avgSpeedKmh > 0 ? 60.0 / avgSpeedKmh : 0.0;
    var paceMin = pace.floor();
    var paceSec = ((pace - paceMin) * 60).round();
    if (paceSec == 60) {
      paceMin += 1;
      paceSec = 0;
    }
    final paceStr =
        avgSpeedKmh > 0 ? '$paceMin:${paceSec.toString().padLeft(2, '0')}' : '-';

    // Cadence (langkah per menit)
    final cadence =
        durationSeconds > 0 ? (steps / (durationSeconds / 60)).round() : 0;

    final statsContext = 'Aktivitas: $sportType | '
        'Jarak: ${currentDistanceKm.toStringAsFixed(2)} km | '
        'Durasi: ${(durationSeconds / 60).toStringAsFixed(1)} menit | '
        'Kecepatan: ${avgSpeedKmh.toStringAsFixed(1)} km/h | '
        'Pace: $paceStr mnt/km | '
        'Langkah: $steps | '
        'Cadence: $cadence SPM';

    final key = apiKey?.trim() ?? '';
    final hasValidKey = key.length > 10 && !key.contains('ISI_API_KEY');

    if (!hasValidKey) {
      lastSourceUsed = 'error';
      lastApiError = 'API Key belum diatur';
      return '⚠️ API Key Gemini belum diatur.\n\n'
          'Tambahkan `GEMINI_API_KEY` di file `.env`, atau klik ikon 🔑 '
          'di kanan atas untuk memasukkannya.';
    }

    debugPrint('[AI Coach] Memanggil Gemini API...');
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _callGeminiApi(
          apiKey: key,
          query: query,
          statsContext: statsContext,
        );
        if (response != null && response.isNotEmpty) {
          lastSourceUsed = 'gemini';
          lastApiError = null;
          return response;
        }
      } catch (e) {
        lastApiError = e.toString();
        debugPrint('[AI Coach] Exception (attempt ${attempt + 1}): $e');
      }
      if (attempt == 0) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    // Gagal total: tampilkan error asli, bukan template palsu
    lastSourceUsed = 'error';
    final err = lastApiError ?? 'Penyebab tidak diketahui';
    final shortErr = err.length > 300 ? '${err.substring(0, 300)}...' : err;
    return '⚠️ Coach belum bisa terhubung ke Gemini.\n\n'
        'Detail error:\n`$shortErr`\n\n'
        'Coba kirim ulang pesanmu beberapa saat lagi.';
  }

  Future<String?> _callGeminiApi({
    required String apiKey,
    required String query,
    required String statsContext,
  }) async {
    // Tambahkan pesan user ke riwayat
    _conversationHistory.add({
      'role': 'user',
      'parts': [
        {'text': query}
      ]
    });

    // Buang pasangan (user+model) tertua agar riwayat selalu mulai dari 'user'
    while (_conversationHistory.length > _maxHistoryTurns * 2) {
      _conversationHistory.removeRange(0, 2);
    }

    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {
            'text': '$_systemInstruction\n\n'
                'DATA AKTIVITAS USER SAAT INI '
                '(gunakan hanya jika relevan dengan pertanyaan):\n'
                '$statsContext'
          }
        ]
      },
      'contents': _conversationHistory,
      'generationConfig': {
        'temperature': 1.0,
        'topP': 0.95,
        'topK': 40,
        'maxOutputTokens': 4096,
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_ONLY_HIGH'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_ONLY_HIGH'},
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_ONLY_HIGH'
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_ONLY_HIGH'
        },
      ],
    });

    for (final model in _candidateModels) {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');

      try {
        final res = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: body,
            )
            .timeout(const Duration(seconds: 30));

        if (res.statusCode == 200) {
          final json = jsonDecode(res.body);
          final parts = json['candidates']?[0]?['content']?['parts'] as List?;
          final text = parts
              ?.where((p) => p['thought'] != true)
              .map((p) => p['text']?.toString() ?? '')
              .join()
              .trim();

          if (text != null && text.isNotEmpty) {
            _conversationHistory.add({
              'role': 'model',
              'parts': [
                {'text': text}
              ]
            });
            lastApiError = null;
            debugPrint('[AI Coach] Sukses dari $model');
            return text;
          }

          final reason = json['candidates']?[0]?['finishReason'] ??
              json['promptFeedback']?['blockReason'] ??
              'tidak diketahui';
          lastApiError = '[$model] Respons kosong (alasan: $reason)';
          debugPrint('[AI Coach] $lastApiError');
          continue;
        }

        String detail = 'HTTP ${res.statusCode}';
        try {
          final msg = jsonDecode(res.body)['error']?['message'];
          if (msg != null) detail += ': $msg';
        } catch (_) {
          detail += ': ${res.body}';
        }
        lastApiError = '[$model] $detail';
        debugPrint('[AI Coach] $lastApiError');

        // Model tidak ada / kuota habis / server sibuk -> coba model berikutnya
        if ([404, 429, 500, 503].contains(res.statusCode)) continue;
        break; // 400/403: key salah atau request salah, tidak perlu lanjut
      } catch (e) {
        lastApiError = '[$model] $e';
        debugPrint('[AI Coach] Network exception: $e');
      }
    }

    // Gagal: batalkan pesan user terakhir agar riwayat tetap konsisten
    if (_conversationHistory.isNotEmpty &&
        _conversationHistory.last['role'] == 'user') {
      _conversationHistory.removeLast();
    }
    return null;
  }
}
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

  /// Sumber respons terakhir: 'gemini', 'local', atau 'none'
  String lastSourceUsed = 'none';

  /// Riwayat percakapan multi-turn (selalu berpasangan user/model)
  final List<Map<String, dynamic>> _conversationHistory = [];

  /// Maksimum pasangan percakapan yang disimpan
  static const int _maxHistoryTurns = 20;

  /// Urutan model yang dicoba. Cek daftar model terbaru di dokumentasi
  /// Gemini API karena nama model bisa berubah.
  static const List<String> _candidateModels = [
    'gemini-3.5-flash-lite',
    'gemini-3-flash-preview',
    'gemini-3.5-flash',
    'gemini-3.8-flash',
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

    var key = apiKey?.trim() ?? '';
    if (key.startsWith('"') && key.endsWith('"') && key.length > 2) {
      key = key.substring(1, key.length - 1).trim();
    }
    final hasValidKey = key.length > 10 && !key.contains('ISI_API_KEY');

    if (!hasValidKey) {
      lastApiError = 'API Key belum diatur';
      return _localFallback(
        query: query,
        notice: '⚠️ *API Key belum diatur, menampilkan jawaban cadangan offline:*\n\n',
        currentDistanceKm: currentDistanceKm,
        steps: steps,
        avgSpeedKmh: avgSpeedKmh,
        durationSeconds: durationSeconds,
      );
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

    // Gemini gagal: pakai template offline, error asli tetap dicatat di log
    final err = lastApiError ?? 'Penyebab tidak diketahui';
    final shortErr = err.length > 120 ? '${err.substring(0, 120)}...' : err;
    return _localFallback(
      query: query,
      notice: '⚠️ *Gagal terhubung ke Gemini ($shortErr). '
          'Menampilkan jawaban cadangan offline:*\n\n',
      currentDistanceKm: currentDistanceKm,
      steps: steps,
      avgSpeedKmh: avgSpeedKmh,
      durationSeconds: durationSeconds,
    );
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
            .timeout(const Duration(seconds: 12));

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

  /// Jawaban cadangan offline (template). Hanya dipakai jika Gemini tidak tersedia.
  String _localFallback({
    required String query,
    required String notice,
    required double currentDistanceKm,
    required int steps,
    required double avgSpeedKmh,
    required int durationSeconds,
  }) {
    lastSourceUsed = 'local';
    debugPrint('[AI Coach] Menggunakan jawaban cadangan offline');

    if (!_isHealthOrSportsTopic(query)) {
      return '$notice'
          'Wah, kalau soal itu aku nggak jago nih 😅\n\n'
          'Tapi kalau kamu mau tanya seputar:\n'
          '• 🏃 Latihan & strategi balapan\n'
          '• 🥗 Nutrisi & hidrasi olahraga\n'
          '• 💪 Kebugaran & recovery\n'
          '• ⚕️ Pencegahan cedera\n\n'
          'Aku siap bantu! 💪';
    }

    final advice = _generateLocalExpertAdvice(
      query: query,
      currentDistanceKm: currentDistanceKm,
      steps: steps,
      avgSpeedKmh: avgSpeedKmh,
      durationSeconds: durationSeconds,
    );
    return '$notice$advice';
  }

  bool _isHealthOrSportsTopic(String query) {
    final lower = query.toLowerCase();
    const keywords = [
      'lari', 'berlari', 'jogging', 'sprint', 'marathon', 'maraton',
      'sepeda', 'bersepeda', 'cycling', 'bike', 'renang', 'berenang',
      'swimming', 'gym', 'fitness', 'olahraga', 'sport', 'exercise',
      'latihan', 'yoga', 'pilates', 'crossfit', 'hiit', 'cardio',
      'bulutangkis', 'badminton', 'tenis', 'basket', 'futsal', 'bola',
      'tinju', 'boxing', 'muay thai', 'silat',
      'pace', 'kecepatan', 'speed', 'cadence', 'vo2', 'heart rate',
      'detak jantung', 'denyut', 'jantung', 'performa', 'performance',
      'record', 'rekor', 'pr ', 'personal best', 'split', 'interval',
      'tempo', 'fartlek', 'repetisi', 'kompetisi', 'lomba', 'race',
      'balapan', 'turnamen',
      'nutrisi', 'nutrition', 'makan', 'diet', 'kalori', 'calorie',
      'protein', 'karbohidrat', 'carb', 'lemak', 'fat', 'minum', 'hidrasi',
      'hydration', 'air', 'elektrolit', 'electrolyte', 'suplemen',
      'supplement', 'vitamin', 'mineral', 'energi', 'energy', 'gel',
      'carbo loading', 'sarapan', 'gizi',
      'kesehatan', 'health', 'sehat', 'badan', 'tubuh', 'body', 'otot',
      'muscle', 'tulang', 'bone', 'sendi', 'joint', 'cedera', 'injury',
      'sakit', 'nyeri', 'kram', 'cramp', 'peregangan', 'stretching',
      'warm up', 'pemanasan', 'cool down', 'pendinginan', 'recovery',
      'pemulihan', 'istirahat', 'tidur', 'sleep', 'rest', 'berat badan',
      'weight', 'bmi', 'massa', 'lemak tubuh', 'tekanan darah',
      'blood pressure', 'kolesterol', 'napas', 'nafas', 'pernapasan',
      'kebugaran', 'bugar', 'stamina', 'daya tahan', 'endurance',
      'kekuatan', 'strength', 'power', 'plyometric', 'fleksibilitas',
      'flexibility', 'mobilitas', 'mobility', 'postur', 'posture', 'form',
      'teknik',
      'coach', 'tips', 'saran', 'rekomendasi', 'analisis', 'evaluasi',
      'program', 'jadwal', 'plan', 'planning', 'target', 'goal',
      'motivasi', 'semangat', 'mental',
      'sepatu', 'shoes', 'jersey', 'apparel', 'garmin', 'smartwatch',
      'treadmill', 'dumbbell', 'barbell',
      'langkah', 'step', 'jarak', 'distance', 'durasi', 'duration',
      'waktu', 'km', 'kilometer', 'mil', 'mile', 'meter', 'taktik',
      'strategi', 'strategy',
    ];
    for (final k in keywords) {
      if (lower.contains(k)) return true;
    }
    return false;
  }

  /// Pencocokan topik berbasis skor untuk jawaban template offline.
  String _generateLocalExpertAdvice({
    required String query,
    required double currentDistanceKm,
    required int steps,
    required double avgSpeedKmh,
    required int durationSeconds,
  }) {
    final lower = query.toLowerCase();

    final Map<String, Map<String, int>> topicKeywords = {
      'pernapasan': {
        'napas': 5, 'pernapasan': 5, 'nafas': 5, 'bernafas': 5, 'bernapas': 5,
        'breathing': 5, 'breath': 4, 'hirup': 4, 'hembus': 4, 'inhale': 4,
        'exhale': 4, 'oksigen': 3, 'paru': 4, 'sesak': 4, 'ngos': 4,
        'terengah': 4,
      },
      'nutrisi': {
        'nutrisi': 5, 'nutrition': 5, 'makan': 4, 'makanan': 5, 'diet': 5,
        'kalori': 5, 'calorie': 5, 'protein': 4, 'karbohidrat': 5, 'carb': 4,
        'lemak': 3, 'carbo loading': 5, 'gizi': 5, 'sarapan': 4,
        'snack': 3, 'meal': 3, 'porsi': 4,
      },
      'hidrasi': {
        'hidrasi': 5, 'hydration': 5, 'minum': 4, 'dehidrasi': 5,
        'elektrolit': 5, 'electrolyte': 5, 'cairan': 4, 'haus': 4,
        'isotonic': 4, 'air putih': 4,
      },
      'pace_strategi': {
        'pace': 5, 'kecepatan': 4, 'speed': 4, 'taktik': 5, 'strategi': 5,
        'strategy': 5, 'negative split': 5, 'positive split': 5,
        'akselerasi': 4, 'pacing': 5, 'tempo run': 4,
      },
      'analisis_performa': {
        'analisis': 5, 'analisa': 5, 'performa': 5, 'evaluasi': 5,
        'performance': 5, 'statistik': 4, 'data': 3, 'progress': 4,
        'perkembangan': 4, 'peningkatan': 3, 'hasil': 3,
      },
      'cedera': {
        'cedera': 5, 'injury': 5, 'sakit': 4, 'nyeri': 5, 'kram': 5,
        'cramp': 5, 'keseleo': 5, 'terkilir': 5, 'bengkak': 4,
        'radang': 4, 'tendon': 5, 'lutut': 4, 'knee': 4,
        'shin splint': 5, 'plantar': 5, 'achilles': 5,
      },
      'pemanasan': {
        'pemanasan': 5, 'warm up': 5, 'warmup': 5, 'peregangan': 4,
        'stretching': 5, 'dinamis': 3, 'statis': 3, 'sebelum lari': 4,
        'sebelum olahraga': 4, 'persiapan': 3, 'awalan': 3,
      },
      'pendinginan': {
        'pendinginan': 5, 'cool down': 5, 'cooldown': 5,
        'setelah lari': 4, 'setelah olahraga': 4, 'selesai lari': 4,
        'pasca lari': 4, 'pasca race': 4,
      },
      'recovery': {
        'recovery': 5, 'pemulihan': 5, 'pulih': 4, 'istirahat': 4,
        'rest day': 5, 'hari istirahat': 5, 'overtraining': 5,
        'lelah': 4, 'capek': 4, 'cape': 4, 'kelelahan': 5,
        'pegal': 4, 'doms': 5, 'soreness': 5,
      },
      'mental': {
        'mental': 5, 'motivasi': 5, 'semangat': 4, 'fokus': 4,
        'konsentrasi': 4, 'gugup': 4, 'nervous': 4, 'grogi': 4,
        'stres': 4, 'stress': 4, 'psikologi': 5, 'mindset': 5,
        'visualisasi': 5, 'percaya diri': 5, 'takut': 3, 'malas': 4,
        'bosan': 3,
      },
      'sepatu_gear': {
        'sepatu': 5, 'shoes': 5, 'gear': 5, 'perlengkapan': 5,
        'apparel': 4, 'jersey': 4, 'kaos kaki': 4, 'sock': 4,
        'garmin': 4, 'smartwatch': 4, 'insole': 5, 'sole': 4,
        'cushion': 4, 'baju': 3, 'celana': 3, 'pakaian': 3,
      },
      'tidur': {
        'tidur': 5, 'sleep': 5, 'insomnia': 5, 'begadang': 4,
        'bangun pagi': 4, 'jam tidur': 5, 'kualitas tidur': 5,
        'istirahat malam': 4, 'ngantuk': 3,
      },
      'berat_badan': {
        'berat badan': 5, 'weight': 4, 'bmi': 5, 'kurus': 4,
        'gemuk': 4, 'diet': 3, 'defisit kalori': 5, 'surplus': 4,
        'body fat': 5, 'lemak tubuh': 5, 'massa otot': 5,
        'turun berat': 5, 'naik berat': 5,
      },
      'heart_rate': {
        'heart rate': 5, 'detak jantung': 5, 'denyut': 5, 'jantung': 4,
        'hr zone': 5, 'zona jantung': 5, 'bpm': 5, 'denyut nadi': 5,
        'nadi': 4, 'resting heart rate': 5, 'max hr': 5,
      },
      'program_latihan': {
        'program': 4, 'jadwal': 5, 'plan': 4, 'planning': 4,
        'rencana': 4, 'rutinitas': 5, 'routine': 5, 'frekuensi': 4,
        'berapa kali': 4, 'per minggu': 4, 'mingguan': 4,
        'periodisasi': 5, 'base building': 5, 'taper': 5,
        'volume': 3, 'intensitas': 4,
      },
      'cadence_teknik': {
        'cadence': 5, 'teknik': 5, 'form': 4, 'postur': 5, 'posture': 5,
        'foot strike': 5, 'pendaratan kaki': 5, 'langkah': 3,
        'ayunan tangan': 5, 'arm swing': 5, 'heel strike': 5,
        'midfoot': 5, 'forefoot': 5, 'spm': 4,
      },
      'interval': {
        'interval': 5, 'fartlek': 5, 'repetisi': 5, 'repeat': 4,
        'set': 3, 'tempo': 4, 'threshold': 5, 'lactate': 5,
        'laktat': 5, 'vo2max': 5, 'vo2': 5, 'anaerob': 5, 'aerob': 5,
      },
      'jarak_kategori': {
        '10k': 5, '10km': 5, '15k': 5, '15km': 5, '50k': 5, '50km': 5,
        '5k': 4, '5km': 4, '21k': 5, '21km': 5, '42k': 5, '42km': 5,
        'marathon': 5, 'half marathon': 5, 'ultra': 5, 'ultramarathon': 5,
        'bedanya': 4, 'perbedaan': 4, 'jarak tempuh': 4, 'kategori lari': 5,
      },
    };

    String bestTopic = '';
    int bestScore = 0;
    for (final entry in topicKeywords.entries) {
      int score = 0;
      for (final kw in entry.value.entries) {
        if (lower.contains(kw.key)) score += kw.value;
      }
      if (score > bestScore) {
        bestScore = score;
        bestTopic = entry.key;
      }
    }
    if (bestScore < 4) bestTopic = '';

    final pace = avgSpeedKmh > 0 ? (60 / avgSpeedKmh) : 0.0;
    final paceStr = pace > 0 ? pace.toStringAsFixed(1) : '-';
    final distStr = currentDistanceKm.toStringAsFixed(2);
    final speedStr = avgSpeedKmh.toStringAsFixed(1);
    final cadenceVal =
        durationSeconds > 0 ? steps / (durationSeconds / 60) : 0.0;

    switch (bestTopic) {
      case 'pernapasan':
        return '''
🌬️ **Tips Pernapasan untuk Atlet:**

1. **Rhythmic Breathing (2:2):** Hirup lewat hidung 2 langkah, hembuskan lewat mulut 2 langkah agar suplai oksigen stabil.
2. **Intensitas Tinggi:** Beralih ke pola 2:1 (hirup 2 langkah, hembus 1 langkah).
3. **Pernapasan Diafragma:** Bernapaslah dari perut, bukan dada, untuk memaksimalkan kapasitas paru.
4. **Jangan Menahan Napas** saat menanjak atau sprint, karena memicu kelelahan dini dan kram diafragma.
5. **Box Breathing:** Di luar sesi lari, latih pola 4-4-4-4 untuk meningkatkan kontrol napas.

💡 Kalau terengah-engah, perlambat pace dan perpanjang hembusan napas.
''';

      case 'nutrisi':
        return '''
🥗 **Rekomendasi Nutrisi Olahraga:**

1. **Pre-Workout (2-3 jam sebelum):** Karbohidrat kompleks + protein sedang. Contoh: nasi merah + telur + pisang.
2. **Saat Berlari (>60 menit):** 30-60g karbohidrat per jam lewat energy gel, kurma, atau pisang.
3. **Post-Workout (30-45 menit setelah):** Protein + karbohidrat rasio sekitar 1:3. Contoh: susu cokelat, dada ayam & nasi.
4. **Jarak Anda $distStr km:** ${currentDistanceKm > 10 ? 'Untuk jarak panjang, lakukan carbo-loading 2-3 hari sebelum event.' : 'Untuk jarak ini, makanan ringan 1-2 jam sebelumnya sudah cukup.'}

⚠️ Hindari makanan tinggi serat dan lemak 1-2 jam sebelum lari agar pencernaan aman.
''';

      case 'hidrasi':
        return '''
💧 **Panduan Hidrasi untuk Atlet:**

1. **Sebelum:** Minum 400-600 ml air putih 2-3 jam sebelum aktivitas.
2. **Selama:** 150-250 ml setiap 15-20 menit. Jangan tunggu haus.
3. **Sesudah:** Minum sekitar 1,5x cairan yang hilang. Selisih berat badan 1 kg kira-kira 1 liter cairan.
4. **Elektrolit:** Untuk aktivitas >60 menit atau cuaca panas, tambahkan elektrolit untuk mencegah hiponatremia.
5. **Tanda Dehidrasi:** Urine gelap, pusing, kram otot, performa turun mendadak.

💡 Air kelapa muda adalah sumber elektrolit alami yang baik untuk recovery.
''';

      case 'pace_strategi':
        return '''
⚡ **Taktik Pace & Strategi Balapan:**

- Kecepatan rata-rata Anda: **$speedStr km/h** (pace ~$paceStr mnt/km).
- **Negative Split:** Paruh pertama 5-10% lebih lambat, lalu akselerasi di paruh kedua.
- **Even Split:** Untuk pemula, jaga pace konstan dan jangan sprint di awal.
- **Pembagian Race:** Awal konservatif, tengah stabil, 20% akhir akselerasi bertahap.
- **Cadence Ideal:** 170-180 SPM.

💡 Variasi pace lebih dari 15% dari target menandakan strategi yang belum matang.
''';

      case 'analisis_performa':
        return '''
📊 **Analisis Performa Aktivitas Anda:**

| Metrik | Nilai |
|---|---|
| Jarak Tempuh | **$distStr km** |
| Total Langkah | **$steps langkah** |
| Rata-rata Pace | **$paceStr mnt/km** |
| Kecepatan | **$speedStr km/h** |
| Durasi | **${(durationSeconds / 60).toStringAsFixed(1)} menit** |

**Evaluasi:**
${avgSpeedKmh > 12 ? '🔥 Pace di atas rata-rata, performa sprint sangat baik.' : avgSpeedKmh > 8 ? '✅ Pace stabil dan efisien untuk jarak menengah.' : avgSpeedKmh > 5 ? '👍 Ritme jogging yang baik. Naikkan bertahap 5-10% per minggu.' : '🏁 Awal yang baik! Konsistensi adalah kunci.'}
${steps > 0 && durationSeconds > 0 ? '\n📐 Cadence estimasi: ~${cadenceVal.toStringAsFixed(0)} SPM. ${cadenceVal > 170 ? 'Sudah optimal!' : 'Coba naikkan ke 170-180 SPM.'}' : ''}
''';

      case 'cedera':
        return '''
⚠️ **Pencegahan & Penanganan Cedera:**

**Pencegahan:**
- Pemanasan dinamis 5-10 menit sebelum lari.
- Naikkan volume latihan maksimal 10% per minggu.
- Pakai sepatu yang sesuai tipe pronasi kaki.
- Perkuat glutes, core, dan ankle.

**Penanganan Akut (RICE):**
1. **R**est: hentikan aktivitas jika nyeri tajam.
2. **I**ce: kompres es 15-20 menit, 3-4x sehari.
3. **C**ompression: perban elastis untuk mengurangi bengkak.
4. **E**levation: tinggikan area cedera di atas jantung.

**Kram Otot:** Perlambat pace, peregangan ringan, dan asup elektrolit.

🚨 Jika nyeri berlanjut >3 hari atau memburuk, segera periksa ke dokter.
''';

      case 'pemanasan':
        return '''
🔥 **Panduan Pemanasan yang Efektif:**

**Fase 1, Aktivasi (3-5 menit):** Jalan cepat lalu jogging ringan sampai denyut jantung 50-60% max HR.

**Fase 2, Peregangan Dinamis (5-7 menit):**
1. Leg swings 10x per kaki
2. High knees 20x
3. Butt kicks 20x
4. Walking lunges 10x per kaki
5. Arm circles 10x per arah

**Fase 3, Strides (2-3 menit):** Lari 50-80 m dengan akselerasi bertahap, 3-4 repetisi.

⚠️ Hindari peregangan statis sebelum lari karena bisa menurunkan performa otot.
''';

      case 'pendinginan':
        return '''
❄️ **Panduan Pendinginan Pasca Latihan:**

**Fase 1 (5 menit):** Turunkan pace bertahap dari lari ke jogging ringan lalu jalan kaki.

**Fase 2, Peregangan Statis (5-10 menit):** Quad, hamstring, calf, dan hip flexor, masing-masing 20-30 detik per sisi.

**Fase 3, Recovery Aktif:** Foam rolling 5-10 menit, minum air/elektrolit, dan makan snack protein dalam 30 menit.

💡 Cool-down yang baik membantu mengurangi nyeri otot tertunda (DOMS).
''';

      case 'recovery':
        return '''
🔄 **Panduan Recovery & Pemulihan:**

1. **Rest Day:** Minimal 1-2 hari istirahat per minggu, karena otot beradaptasi saat istirahat.
2. **Active Recovery:** Jalan kaki, yoga, atau renang santai di hari istirahat.
3. **Tidur:** Target 7-9 jam per malam.
4. **Nutrisi Recovery:** Protein 1,2-2,0 g/kg berat badan per hari.
5. **Foam Rolling & Stretching:** 10-15 menit setelah sesi.
6. **Tanda Overtraining:** Performa turun, insomnia, denyut istirahat naik, mood swing, sering sakit. Kalau ada 3+ gejala, kurangi volume latihan.

💡 Kamu menjadi kuat saat recovery, bukan saat latihan.
''';

      case 'mental':
        return '''
🧠 **Mental Toughness & Motivasi:**

1. **Goal SMART:** Target yang spesifik, terukur, realistis, relevan, dan punya batas waktu.
2. **Visualisasi:** Bayangkan dirimu berlari dengan ritme sempurna sampai garis finish.
3. **Self-Talk Positif:** Ganti "aku capek" dengan "aku kuat dan tubuhku mampu".
4. **Chunking:** Pecah jarak jadi segmen kecil, misalnya "sampai tiang berikutnya".
5. **Rutinitas Pre-Race:** Ritual konsisten sebelum race untuk menurunkan kecemasan.
6. **Bedakan** ketidaknyamanan latihan dengan nyeri cedera.

💪 Percaya pada proses latihanmu!
''';

      case 'sepatu_gear':
        return '''
👟 **Panduan Perlengkapan Olahraga:**

**Sepatu Lari:**
- Ganti setiap 500-800 km pemakaian.
- Pilih sesuai tipe pronasi: neutral, overpronation, atau supination.
- Jangan pakai sepatu baru langsung untuk race, break-in dulu 50-80 km.

**Pakaian:** Pilih bahan moisture-wicking, bukan katun. Untuk jarak panjang, pakai anti-chafe di area rawan gesekan.

**Aksesori:** GPS watch, headphone bone conduction, dan reflective vest untuk lari malam/subuh.

💡 Sepatu yang tepat lebih penting daripada gadget mahal.
''';

      case 'tidur':
        return '''
😴 **Tidur & Performa Atletik:**

1. **Durasi:** 7-9 jam per malam.
2. **Sleep Hygiene:** Jam tidur konsisten, kamar sejuk (18-20°C), hindari layar gadget 30-60 menit sebelum tidur, hindari kafein setelah jam 14:00.
3. **Power Nap:** 20-30 menit siang hari untuk menambah kewaspadaan.
4. **Dampak Kurang Tidur:** Endurance turun, waktu reaksi melambat, risiko cedera naik.
5. **Pre-Race:** Tidur malam H-2 sama pentingnya dengan malam H-1.

💡 Tidur adalah suplemen gratis paling kuat untuk atlet.
''';

      case 'berat_badan':
        return '''
⚖️ **Manajemen Berat Badan untuk Atlet:**

1. **Fokus pada komposisi tubuh**, bukan hanya angka timbangan.
2. **Menurunkan Berat:** Defisit kalori moderat sekitar 300-500 kkal/hari. Terlalu cepat berisiko kehilangan massa otot dan performa.
3. **Menaikkan Massa Otot:** Surplus kalori kecil + latihan beban 2-3x per minggu + protein cukup.
4. **Hindari diet ekstrem**, karena tubuh atlet butuh bahan bakar.
5. **Timing Makan:** Makan besar 2-3 jam sebelum latihan, snack ringan 30-60 menit sebelumnya.
6. **Monitoring:** Timbang pagi hari dan rata-ratakan per minggu.

💡 Untuk target berat badan yang spesifik, konsultasikan dengan ahli gizi.
''';

      case 'heart_rate':
        return '''
❤️ **Panduan Heart Rate Zone:**

**Estimasi Max HR:** 220 dikurangi usia (rumus umum).

| Zona | % Max HR | Tujuan |
|---|---|---|
| Zona 1 | 50-60% | Recovery ringan, pemanasan |
| Zona 2 | 60-70% | Membangun base endurance |
| Zona 3 | 70-80% | Tempo run |
| Zona 4 | 80-90% | Interval, VO2max |
| Zona 5 | 90-100% | Sprint all-out singkat |

**Praktisnya:** Sekitar 80% latihan di Zona 2 dan 20% di Zona 3-5. Denyut istirahat yang menurun seiring waktu menandakan kebugaran membaik.

💡 Chest strap lebih akurat dibanding sensor optik di pergelangan untuk interval.
''';

      case 'program_latihan':
        return '''
📋 **Panduan Program Latihan Lari:**

**Pemula (0-5K):** 3x per minggu, run/walk interval lalu progresif ke lari non-stop.

**Intermediate (5K-21K):** 4-5x per minggu: 1x long run, 1x tempo, 1x interval/fartlek, 1-2x easy run, 1-2x rest atau cross-training.

**Prinsip:**
- Aturan 10%: naikkan volume maksimal 10% per minggu.
- Aturan 80/20: 80% easy, 20% intens.
- Periodisasi: base, build, peak, taper.

💡 Konsistensi lebih penting daripada intensitas.
''';

      case 'cadence_teknik':
        return '''
🦶 **Teknik Lari & Cadence:**

**Cadence Optimal:** 170-180 SPM.
${steps > 0 && durationSeconds > 0 ? '📊 Cadence Anda saat ini: ~${cadenceVal.toStringAsFixed(0)} SPM. ${cadenceVal >= 170 ? '✅ Sudah optimal!' : '⬆️ Coba langkah lebih pendek dan cepat.'}' : ''}

**Form:**
1. **Postur:** Tegak, sedikit condong ke depan dari ankle.
2. **Foot Strike:** Pendaratan di midfoot.
3. **Ayunan Tangan:** Siku ~90°, ayun maju-mundur, bahu rileks.
4. **Pandangan:** 10-20 meter ke depan.
5. **Hindari overstriding:** kaki mendarat di bawah pusat massa.

💡 Drill A-skip, B-skip, dan high knees 2-3x per minggu membantu koordinasi.
''';

      case 'interval':
        return '''
⏱️ **Latihan Interval & Threshold:**

1. **Short Intervals (200-400 m):** Speed work, 6-10 repetisi, istirahat 1:2.
2. **Long Intervals (800-1600 m):** VO2max, 4-6 repetisi, istirahat 1:1.
3. **Tempo/Threshold:** 20-40 menit di pace "comfortably hard".
4. **Fartlek:** Variasi kecepatan tidak terstruktur, fun dan efektif.

**Contoh:** 5x1000 m di pace 5K dengan jogging 3 menit.

Jangan lakukan interval dua hari berturut-turut.
${avgSpeedKmh > 0 ? '\n📊 Dengan pace Anda ($paceStr mnt/km), target interval sekitar ${(pace * 0.85).toStringAsFixed(1)} mnt/km.' : ''}
''';

      case 'jarak_kategori':
        return '''
🏃 **Perbedaan Lari 10K, 15K, dan 50K (Ultra):**

1. **10K:** Intensitas cukup tinggi (Zona 3-4). Energi dominan glikogen, gel biasanya opsional. Kunci: pace stabil dan toleransi laktat.
2. **15K:** Intensitas menengah (Zona 2-3). Cadangan glikogen mulai terkuras, disarankan 1-2 gel dan hidrasi teratur. Kunci: pacing disiplin.
3. **50K (Ultra):** Intensitas rendah-menengah tapi sangat lama (5-8+ jam). Butuh makanan padat, gel, dan elektrolit konsisten (30-60 g karbo per jam). Kunci: mental, strategi jalan di tanjakan, dan sepatu nyaman.
''';

      default:
        return '''
🏃‍♂️ **Coach Virtual, Ringkasan Aktivitas:**
Jarak: **$distStr km** | Langkah: **$steps** | Pace: **$paceStr mnt/km** | Speed: **$speedStr km/h**

💡 **Tips:**
${currentDistanceKm > 10 ? '🔥 Jarak panjang! Pastikan hidrasi tiap 15-20 menit dan asupan karbohidrat per jam.' : currentDistanceKm > 5 ? '👍 Jarak menengah! Fokus pada ritme napas dan pace konsisten.' : '🏁 Lanjutkan dengan konsisten dan fokus pada form serta napas rileks.'}

Tanyakan topik spesifik, misalnya pernapasan, interval, pemanasan, recovery, heart rate zone, atau program latihan.
''';
    }
  }
}
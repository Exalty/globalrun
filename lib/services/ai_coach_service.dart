import 'dart:convert';
import 'package:http/http.dart' as http;

class AiMessage {
  final String sender; // 'user' or 'ai'
  final String text;
  final DateTime timestamp;

  AiMessage({required this.sender, required this.text, required this.timestamp});
}

class AiCoachService {
  String? apiKey;

  AiCoachService({this.apiKey});

  // Comprehensive rule-based & LLM fallback running/cycling coach
  Future<String> askCoach({
    required String query,
    required double currentDistanceKm,
    required int steps,
    required double avgSpeedKmh,
    required int durationSeconds,
    required String sportType,
  }) async {
    // If user provided a Gemini API Key, attempt live API call
    if (apiKey != null && apiKey!.trim().isNotEmpty) {
      try {
        final response = await _callGeminiApi(
          apiKey: apiKey!.trim(),
          query: query,
          statsContext: 'Sport: $sportType, Distance: ${currentDistanceKm.toStringAsFixed(2)} km, Duration: ${(durationSeconds / 60).toStringAsFixed(1)} min, Speed: ${avgSpeedKmh.toStringAsFixed(1)} km/h, Steps: $steps',
        );
        if (response != null && response.isNotEmpty) {
          return response;
        }
      } catch (e) {
        // Fallback to intelligent local coach
      }
    }

    // Intelligent local coach heuristics
    return _generateLocalExpertAdvice(
      query: query,
      currentDistanceKm: currentDistanceKm,
      steps: steps,
      avgSpeedKmh: avgSpeedKmh,
      durationSeconds: durationSeconds,
      sportType: sportType,
    );
  }

  Future<String?> _callGeminiApi({
    required String apiKey,
    required String query,
    required String statsContext,
  }) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');

    final systemPrompt = '''
Anda adalah Coach AI virtual kelas dunia untuk atlet lari & sepeda dalam aplikasi Global Virtual Race.
Gunakan bahasa Indonesia yang menyemangati, taktis, berbasis sains olahraga, dan nutrisi presisi.
Konteks aktivitas peserta saat ini:
$statsContext
''';

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '$systemPrompt\n\nPertanyaan Atlet: $query'}
          ]
        }
      ]
    });

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final text = json['candidates']?[0]?['content']?[0]?['parts']?[0]?['text'] ??
          json['candidates']?[0]?['content']?['parts']?[0]?['text'];
      return text?.toString();
    }
    return null;
  }

  String _generateLocalExpertAdvice({
    required String query,
    required double currentDistanceKm,
    required int steps,
    required double avgSpeedKmh,
    required int durationSeconds,
    required String sportType,
  }) {
    final lower = query.toLowerCase();

    // Specific topics
    if (lower.contains('nutrisi') || lower.contains('makan') || lower.contains('minum') || lower.contains('energi')) {
      return '''
🥗 **Rekomendasi Nutrisi & Hidrasi Virtual Coach:**
1. **Hidrasi:** Minum 150-250 ml air atau elektrolit setiap 20-30 menit lomba untuk menjaga osmoregulasi.
2. **Karbohidrat Cepat Cerna:** Karena Anda menargetkan jarak ${currentDistanceKm > 0 ? currentDistanceKm.toStringAsFixed(1) : 'panjang'} km, konsumsi energy gel atau pisang (30-60g karbohidrat per jam) saat race berlangsung lebih dari 60 menit.
3. **Recovery Post-Race:** Dalam jendela 45 menit pasca-finish, konsumsi protein dan karbohidrat dengan rasio 3:1 (contoh: susu cokelat, dada ayam & nasi merah) untuk sintesis glikogen otot.
''';
    }

    if (lower.contains('kecepatan') || lower.contains('pace') || lower.contains('taktik') || lower.contains('strategi')) {
      final paceMinKm = avgSpeedKmh > 0 ? (60 / avgSpeedKmh) : 0.0;
      return '''
⚡ **Taktik Pace & Strategi Balapan:**
- Kecepatan rata-rata Anda saat ini: **${avgSpeedKmh.toStringAsFixed(1)} km/h** (Pace: ~${paceMinKm.toStringAsFixed(1)} mnt/km).
- **Strategi Negative Split:** Pertahankan kecepatan 5-10% di bawah batas ambang laktat pada sepertiga awal lomba. Akselerasi bertahap pada 3 km terakhir.
- **Cadence Ideal:** Targetkan cadence langkah kaki di 170-180 SPM (steps per minute) untuk meminimalkan beban benturan lutut.
''';
    }

    if (lower.contains('analisis') || lower.contains('performa') || lower.contains('evaluasi')) {
      final pace = avgSpeedKmh > 0 ? (60 / avgSpeedKmh).toStringAsFixed(1) : '-';
      return '''
📊 **Analisis Performa Latihan/Race:**
- Jarak Tempuh: **${currentDistanceKm.toStringAsFixed(2)} km**
- Total Langkah: **$steps langkah**
- Rata-rata Pace: **$pace mnt/km** (${avgSpeedKmh.toStringAsFixed(1)} km/h)
- Evaluasi: Ritme Anda stabil! Cadence dan akselerasi sensor menunjukkan transfer energi biomekanik yang efisien. Pertahankan postur dada tegak dan relaksasikan bahu.
''';
    }

    if (lower.contains('cedera') || lower.contains('sakit') || lower.contains('kram')) {
      return '''
⚠️ **Tips Pencegahan & Penanganan Kram:**
- Jika mulai terasa kram pada betis atau hamstring, perlambat kecepatan, lakukan peregangan dinamis ringan dan asup elektrolit kaya magnesium & sodium.
- Jangan memaksakan sprint jika ada nyeri tajam pada tendon achilles atau patella. Utamakan 'Finish Strong & Injury-Free'!
''';
    }

    // Default general advice
    return '''
🏃‍♂️ **Coach Virtual:**
"Semangat untuk kompetisi virtual kali ini! Jarak Anda telah mencapai **${currentDistanceKm.toStringAsFixed(2)} km** dengan **$steps langkah**.

💡 **Tips Cepat:**
1. Fokus pada ritme pernapasan 2:2 (2 langkah hirup, 2 langkah hembus).
2. Perhatikan permukaan jalur lari agar beban benturan telapak kaki merata.
3. Anda bisa menanyakan tips nutrisi, strategi negative split, atau analisis performa kapan saja!"
''';
  }
}

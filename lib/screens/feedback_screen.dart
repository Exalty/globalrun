import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _kesanController = TextEditingController();
  final _saranController = TextEditingController();
  double _rating = 5.0;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadSavedFeedback();
  }

  Future<void> _loadSavedFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    final kesan = prefs.getString('saved_kesan');
    final saran = prefs.getString('saved_saran');
    final rating = prefs.getDouble('saved_rating');

    if (kesan != null || saran != null) {
      if (mounted) {
        setState(() {
          _kesanController.text = kesan ?? '';
          _saranController.text = saran ?? '';
          _rating = rating ?? 5.0;
          _isSubmitted = true;
        });
      }
    }
  }

  Future<void> _saveFeedback() async {
    if (_kesanController.text.trim().isEmpty || _saranController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon isi kesan dan saran terlebih dahulu!')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_kesan', _kesanController.text.trim());
    await prefs.setString('saved_saran', _saranController.text.trim());
    await prefs.setDouble('saved_rating', _rating);

    if (mounted) {
      setState(() => _isSubmitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.teal,
          content: Text('Kesan & Saran untuk Mata Kuliah berhasil disimpan secara lokal!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Saran & Kesan Kuliah', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF334155)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.school_rounded, color: Colors.cyanAccent, size: 36),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pemrograman Aplikasi Mobile',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Evaluasi pengalaman belajar & pengembangan proyek Tugas Akhir',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Rating Stars
            const Text(
              'Rating Pengalaman Mata Kuliah:',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amberAccent,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() => _rating = (index + 1).toDouble());
                  },
                );
              }),
            ),

            const SizedBox(height: 16),

            // Kesan Input
            const Text(
              'Kesan Selama Perkuliahan:',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _kesanController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tuliskan kesan menarik, tantangan, atau pengalaman berharga saat mengikuti kuliah...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 20),

            // Saran Input
            const Text(
              'Saran & Masukan untuk Perkuliahan ke Depan:',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _saranController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tuliskan kritik dan saran konstruktif untuk materi, praktikum, atau dosen pengampu...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveFeedback,
                icon: const Icon(Icons.send_rounded, size: 20),
                label: Text(_isSubmitted ? 'PERBARUI KESAN & SARAN' : 'SIMPAN KESAN & SARAN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/duo_theme.dart';

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
        const SnackBar(
          content: Text('Mohon isi kesan dan saran terlebih dahulu!'),
          backgroundColor: DuoColors.heartRed,
          behavior: SnackBarBehavior.floating,
        ),
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
          backgroundColor: DuoColors.questGreen,
          content: Text('Kesan & Saran untuk Mata Kuliah berhasil disimpan!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'SARAN & KESAN',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 18,
            color: palette.textPrimary,
          ),
        ),
        backgroundColor: palette.surface,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: palette.surfaceBorder, width: 2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card (Duolingo 3D)
            DuoCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: palette.primaryBlue.withOpacity(palette.isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.primaryBlue, width: 2),
                    ),
                    child: Center(
                      child: Icon(Icons.school_rounded, color: palette.primaryBlue, size: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PEMROGRAMAN APLIKASI MOBILE',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Evaluasi pengalaman belajar & pengembangan proyek Tugas Akhir',
                          style: TextStyle(color: palette.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Rating Card (Duolingo 3D)
            DuoCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RATING PENGALAMAN KULIAH',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(5, (index) {
                      final isFilled = index < _rating;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = (index + 1).toDouble()),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFilled
                                ? DuoColors.streakGold.withOpacity(0.18)
                                : palette.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFilled ? DuoColors.streakGold : palette.surfaceBorder,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isFilled ? DuoColors.streakGold : palette.textMuted,
                            size: 30,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Kesan Input Card (Duolingo 3D)
            DuoCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KESAN SELAMA PERKULIAHAN',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _kesanController,
                    maxLines: 4,
                    style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Tuliskan kesan menarik, tantangan, atau pengalaman berharga saat mengikuti kuliah...',
                      hintStyle: TextStyle(color: palette.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: palette.background,
                      contentPadding: const EdgeInsets.all(14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.surfaceBorder, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.primaryBlue, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Saran Input Card (Duolingo 3D)
            DuoCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SARAN & MASUKAN PERKULIAHAN',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _saranController,
                    maxLines: 4,
                    style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Tuliskan kritik dan saran konstruktif untuk materi, praktikum, atau fasilitas...',
                      hintStyle: TextStyle(color: palette.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: palette.background,
                      contentPadding: const EdgeInsets.all(14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.surfaceBorder, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.primaryBlue, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit 3D Button
            DuoButton(
              text: _isSubmitted ? 'PERBARUI KESAN & SARAN' : 'SIMPAN KESAN & SARAN',
              width: double.infinity,
              height: 52,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _saveFeedback,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

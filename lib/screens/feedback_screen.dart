import 'package:flutter/material.dart';

import '../theme/duo_theme.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

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
        shape: Border(
          bottom: BorderSide(color: palette.surfaceBorder, width: 2),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DuoCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: palette.primaryBlue.withOpacity(
                        palette.isDark ? 0.18 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.primaryBlue, width: 2),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.school_rounded,
                        color: palette.primaryBlue,
                        size: 28,
                      ),
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
                          'Evaluasi pengalaman belajar dan pengembangan proyek aplikasi mobile.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                    children: List.generate(
                      5,
                      (index) => Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: index < 4
                              ? DuoColors.streakGold.withOpacity(0.18)
                              : palette.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: index < 4
                                ? DuoColors.streakGold
                                : palette.surfaceBorder,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          index < 4
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: index < 4
                              ? DuoColors.streakGold
                              : palette.textMuted,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      '4 out of 5 stars',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                  Text(
                    'Perkuliahan Pemrograman Aplikasi Mobile cukup '
                    'menantang karena kami harus belajar membuat aplikasi, '
                    'mulai dari tampilan sampai fitur-fiturnya. Kata '
                    'Bapak, mata kuliah ini seperti es teh yang nyegerin. '
                    'Tapi setelah ketemu proyek ini, kesegeran es tehnya hilang pak, hhe. ',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                  Text(
                    'Semoga ke depannya makin nyegerin lagi ya, '
                    'Pak. Semoga tantangannya makin banyak dan seru, '
                    'biar yang lain juga merasakan kesegeran es teh itu.',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
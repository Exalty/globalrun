import 'package:flutter/material.dart';
import '../models/race_standing_model.dart';
import '../theme/duo_theme.dart';

class AthleteComparisonDialog extends StatelessWidget {
  final RaceParticipantEntry myEntry;
  final RaceParticipantEntry opponentEntry;
  final String raceTitle;

  const AthleteComparisonDialog({
    super.key,
    required this.myEntry,
    required this.opponentEntry,
    required this.raceTitle,
  });

  static void show(
    BuildContext context, {
    required RaceParticipantEntry myEntry,
    required RaceParticipantEntry opponentEntry,
    required String raceTitle,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AthleteComparisonDialog(
        myEntry: myEntry,
        opponentEntry: opponentEntry,
        raceTitle: raceTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    final timeDiffSec = myEntry.durationSeconds - opponentEntry.durationSeconds;
    final isFaster = timeDiffSec < 0;
    final absDiffSec = timeDiffSec.abs();
    final diffMins = absDiffSec ~/ 60;
    final diffSecs = absDiffSec % 60;
    final diffFormatted = diffMins > 0 ? '${diffMins}m ${diffSecs}d' : '$diffSecs detik';

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: palette.surfaceBorder, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: palette.surfaceBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.compare_arrows_rounded, color: palette.primaryBlue, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KOMPARASI PERFORMA LARI',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        raceTitle,
                        style: TextStyle(color: palette.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Banner Selisih Waktu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (isFaster ? palette.questGreen : palette.streakGold)
                    .withOpacity(palette.isDark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isFaster ? palette.questGreen : palette.streakGold,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isFaster ? Icons.trending_up_rounded : Icons.info_outline_rounded,
                    color: isFaster ? palette.questGreen : palette.streakGold,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      timeDiffSec == 0
                        ? 'Waktu tempuh Anda sama persis dengan pelari ini!'
                        : isFaster
                            ? 'Kamu $diffFormatted lebih cepat dari ${opponentEntry.userName}!'
                            : '${opponentEntry.userName} $diffFormatted lebih cepat dari kamu.',
                      style: TextStyle(
                        color: isFaster ? palette.questGreen : palette.streakGold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Kotak Perbandingan 2 Atlet Berdampingan
            Row(
              children: [
                // Kolom Kamu
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.primaryBlue.withOpacity(palette.isDark ? 0.14 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.primaryBlue, width: 2),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: palette.primaryBlue.withOpacity(0.2),
                          child: Icon(Icons.person_rounded, color: palette.primaryBlue, size: 24),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Kamu',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Peringkat #${myEntry.rank}',
                          style: TextStyle(
                            color: palette.primaryBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: palette.textMuted,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Kolom Lawan
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.surfaceBorder, width: 2),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: palette.surfaceBorder,
                          child: Icon(Icons.person_outline_rounded, color: palette.textSecondary, size: 24),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opponentEntry.userName.replaceAll(' (Kamu)', ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Peringkat #${opponentEntry.rank}',
                          style: TextStyle(
                            color: palette.streakGold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tabel Metrik Komparasi
            _buildMetricRow('Waktu Finish', myEntry.durationFormatted, opponentEntry.durationFormatted, palette),
            _buildMetricRow('Pace Rata-rata', myEntry.paceFormatted, opponentEntry.paceFormatted, palette),
            _buildMetricRow('Kecepatan', '${myEntry.avgSpeedKmh.toStringAsFixed(1)} km/h', '${opponentEntry.avgSpeedKmh.toStringAsFixed(1)} km/h', palette),
            _buildMetricRow('Langkah Kaki', '${myEntry.steps} st', '${opponentEntry.steps} st', palette),
            _buildMetricRow('Anti-Cheat Valid', 'Tervalidasi ✅', 'Tervalidasi ✅', palette),

            const SizedBox(height: 20),
            DuoButton(
              text: 'TUTUP KOMPARASI',
              height: 46,
              backgroundColor: palette.secondaryButton,
              shadowColor: palette.secondaryButtonShadow,
              textColor: palette.textPrimary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String myVal, String oppVal, DuoColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              myVal,
              textAlign: TextAlign.left,
              style: TextStyle(color: palette.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              oppVal,
              textAlign: TextAlign.right,
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

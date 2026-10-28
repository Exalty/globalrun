import 'package:flutter/material.dart';
import '../models/race_standing_model.dart';
import '../services/leaderboard_service.dart';
import '../theme/duo_theme.dart';
import 'race_leaderboard_detail_screen.dart';

class RaceStandingsScreen extends StatefulWidget {
  const RaceStandingsScreen({super.key});

  @override
  State<RaceStandingsScreen> createState() => _RaceStandingsScreenState();
}

class _RaceStandingsScreenState extends State<RaceStandingsScreen> {
  final LeaderboardService _leaderboardService = LeaderboardService();
  List<MyRaceStanding> _standings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStandings();
  }

  Future<void> _loadStandings() async {
    setState(() => _isLoading = true);
    final data = await _leaderboardService.getMyRaceStandings();
    if (mounted) {
      setState(() {
        _standings = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    final goldCount = _standings.where((s) => s.myRank == 1).length;
    final podiumCount = _standings.where((s) => s.myRank <= 3).length;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'PERINGKAT LOMBA SAYA',
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: palette.textPrimary),
            tooltip: 'Segarkan Data',
            onPressed: _loadStandings,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: palette.primaryBlue))
          : RefreshIndicator(
              onRefresh: _loadStandings,
              color: palette.primaryBlue,
              backgroundColor: palette.surface,
              child: _standings.isEmpty
                  ? _buildEmptyState(palette)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Card Rangkuman Prestasi Atlet
                        DuoCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: palette.streakGold.withOpacity(palette.isDark ? 0.20 : 0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: palette.streakGold, width: 1.5),
                                    ),
                                    child: Icon(Icons.emoji_events_rounded, color: palette.streakGold, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'RAPOR PRESTASI KOMPETISI',
                                          style: TextStyle(
                                            color: palette.textPrimary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Riwayat posisi ranking Anda di berbagai event resmi',
                                          style: TextStyle(color: palette.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSummaryStat('${_standings.length}', 'Lomba Selesai', palette.primaryBlue, palette),
                                  _buildSummaryStat('$podiumCount Kali', 'Masuk Podium', palette.streakGold, palette),
                                  _buildSummaryStat('$goldCount Kali', 'Juara 1 Emas', palette.questGreen, palette),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'DAFTAR EVENT YANG SUDAH DIIKUTI',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // List Kartu Event Lomba
                        ..._standings.map((standing) => _buildStandingCard(standing, palette)),
                      ],
                    ),
            ),
    );
  }

  Widget _buildSummaryStat(String value, String label, Color color, DuoColorPalette palette) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: palette.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStandingCard(MyRaceStanding item, DuoColorPalette palette) {
    Color rankColor = palette.primaryBlue;
    String rankBadgeText = 'Peringkat #${item.myRank} dari ${item.totalParticipants} Pelari';

    if (item.myRank == 1) {
      rankColor = palette.streakGold;
      rankBadgeText = '🥇 Peringkat #1 JUARA UTAMA';
    } else if (item.myRank == 2) {
      rankColor = const Color(0xFF94A3B8);
      rankBadgeText = '🥈 Peringkat #2 PODIUM PERAK';
    } else if (item.myRank == 3) {
      rankColor = const Color(0xFFD97706);
      rankBadgeText = '🥉 Peringkat #3 PODIUM PERUNGGU';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DuoCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row Judul & Kategori
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.eventTitle,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.surfaceBorder),
                  ),
                  child: Text(
                    '${item.distanceKm.toStringAsFixed(1)} KM',
                    style: TextStyle(
                      color: palette.primaryBlue,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Badge Ranking
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: rankColor.withOpacity(palette.isDark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: rankColor, width: 1.5),
              ),
              child: Text(
                rankBadgeText,
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Metrik Lari
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.surfaceBorder, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricCell('Waktu Finish', item.durationFormatted, palette),
                  Container(width: 1, height: 24, color: palette.surfaceBorder),
                  _buildMetricCell('Pace Lari', item.paceFormatted, palette),
                  Container(width: 1, height: 24, color: palette.surfaceBorder),
                  _buildMetricCell('Kecepatan', '${item.myAvgSpeedKmh.toStringAsFixed(1)} km/h', palette),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Lihat Klasemen Lengkap
            DuoButton(
              text: 'LIHAT KLASEMEN LOMBA INI',
              height: 44,
              backgroundColor: palette.primaryBlue,
              shadowColor: palette.primaryBlueShadow,
              textColor: Colors.white,
              icon: const Icon(Icons.leaderboard_rounded, color: Colors.white, size: 18),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RaceLeaderboardDetailScreen(
                      eventId: item.eventId,
                      eventTitle: item.eventTitle,
                      distanceKm: item.distanceKm,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCell(String label, String value, DuoColorPalette palette) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: palette.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(DuoColorPalette palette) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: palette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: palette.primaryBlue, width: 2),
              ),
              child: Icon(Icons.emoji_events_outlined, size: 40, color: palette.primaryBlue),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum Ada Peringkat Lomba',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kamu belum pernah menyelesaikan lomba virtual. Ikuti salah satu event di halaman Beranda untuk mencatat namamu di papan peringkat kompetisi!',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            DuoButton(
              text: 'KEMBALI KE BERANDA LOMBA',
              height: 46,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

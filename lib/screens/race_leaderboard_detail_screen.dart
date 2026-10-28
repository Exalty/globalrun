import 'package:flutter/material.dart';
import '../models/race_standing_model.dart';
import '../models/run_record.dart';
import '../services/leaderboard_service.dart';
import '../theme/duo_theme.dart';
import '../widgets/athlete_comparison_dialog.dart';

class RaceLeaderboardDetailScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final double distanceKm;
  final MyRaceStanding? standing;

  const RaceLeaderboardDetailScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.distanceKm,
    this.standing,
  });

  @override
  State<RaceLeaderboardDetailScreen> createState() => _RaceLeaderboardDetailScreenState();
}

class _RaceLeaderboardDetailScreenState extends State<RaceLeaderboardDetailScreen> {
  final LeaderboardService _leaderboardService = LeaderboardService();
  final ScrollController _scrollController = ScrollController();
  List<RaceParticipantEntry> _participants = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final myRecord = widget.standing != null
          ? RunRecord(
              id: 'local_standing_${widget.standing!.eventId}',
              eventId: widget.standing!.eventId,
              eventTitle: widget.standing!.eventTitle,
              startedAt: widget.standing!.completedAt,
              durationSeconds: widget.standing!.myDurationSeconds,
              distanceKm: widget.standing!.distanceKm,
              targetKm: widget.standing!.distanceKm,
              steps: widget.standing!.mySteps,
              completed: true,
              isSimulated: false,
              blockHash: widget.standing!.blockHash,
              points: const [],
            )
          : null;

      final data = await _leaderboardService.getRaceLeaderboard(
        widget.eventId,
        eventTitle: widget.eventTitle,
        myRecord: myRecord,
      );
      if (mounted) {
        setState(() {
          _participants = data;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat klasemen: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _compareWith(RaceParticipantEntry opponent) {
    final myEntry = _participants.where((e) => e.isCurrentUser).firstOrNull;
    if (myEntry == null) return;
    if (opponent.isCurrentUser || opponent.userId == myEntry.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ini akun Anda sendiri! Ketuk pelari lain untuk membandingkan performa.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    AthleteComparisonDialog.show(
      context,
      myEntry: myEntry,
      opponentEntry: opponent,
      raceTitle: widget.eventTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    final myEntry = _participants.where((e) => e.isCurrentUser).firstOrNull;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'PAPAN KLASEMEN',
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
            tooltip: 'Segarkan Klasemen',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: palette.primaryBlue))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: palette.primaryBlue,
              backgroundColor: palette.surface,
              child: Stack(
                children: [
                  ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
                    children: [
                      // Header Event Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.surfaceBorder, width: 2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: palette.streakGold.withOpacity(palette.isDark ? 0.20 : 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: palette.streakGold, width: 1.5),
                              ),
                              child: Icon(Icons.emoji_events_rounded, color: palette.streakGold, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.eventTitle,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.distanceKm.toStringAsFixed(1)} KM • ${_participants.length} Pelari Terverifikasi',
                                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Jika terjadi error saat memuat
                      if (_errorMessage != null && _participants.isEmpty) ...[
                        const SizedBox(height: 30),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 2),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.wifi_off_rounded, size: 54, color: Colors.redAccent),
                              const SizedBox(height: 14),
                              Text(
                                'Gagal Memuat Klasemen',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: palette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _errorMessage ?? 'Terjadi kendala koneksi ke database lomba.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: palette.textMuted),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Coba Lagi'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: palette.primaryBlue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_participants.isEmpty) ...[
                        const SizedBox(height: 30),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.surfaceBorder, width: 2),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.emoji_events_outlined, size: 54, color: palette.textMuted),
                              const SizedBox(height: 14),
                              Text(
                                'Belum Ada Catatan Waktu',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: palette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Belum ada atlet yang menyelesaikan lomba ini. Selesaikan lari sekarang dan jadilah juara pertama di klasemen!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: palette.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Podium 3 Besar (jika ada pelari)
                        _buildPodium3D(palette),
                        const SizedBox(height: 24),

                        Text(
                          'DAFTAR LENGKAP KLASEMEN',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // List Peserta
                        ...List.generate(_participants.length, (index) {
                          final p = _participants[index];
                          return _buildParticipantTile(p, palette);
                        }),
                      ],
                    ],
                  ),

                  // Floating Sticky Bar: Posisi Akun Anda
                  if (myEntry != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.primaryBlue, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primaryBlue.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: palette.primaryBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '#${myEntry.rank}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Posisi Kamu Saat Ini',
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${myEntry.durationFormatted} • Pace ${myEntry.paceFormatted}',
                                    style: TextStyle(color: palette.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Peringkat #${myEntry.rank} dari ${_participants.length}',
                              style: TextStyle(
                                color: palette.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPodium3D(DuoColorPalette palette) {
    final first = _participants[0];
    final second = _participants.length > 1 ? _participants[1] : null;
    final third = _participants.length > 2 ? _participants[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Juara 2 (Perak) - Kiri
        Expanded(
          child: second != null
              ? _buildPodiumColumn(
                  second,
                  height: 120,
                  badge: '2',
                  color: const Color(0xFF94A3B8),
                  palette: palette,
                )
              : const SizedBox(),
        ),
        const SizedBox(width: 8),

        // Juara 1 (Emas) - Tengah
        Expanded(
          child: _buildPodiumColumn(
            first,
            height: 155,
            badge: '1',
            color: palette.streakGold,
            isFirst: true,
            palette: palette,
          ),
        ),
        const SizedBox(width: 8),

        // Juara 3 (Perunggu) - Kanan
        Expanded(
          child: third != null
              ? _buildPodiumColumn(
                  third,
                  height: 100,
                  badge: '3',
                  color: const Color(0xFFD97706),
                  palette: palette,
                )
              : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildPodiumColumn(
    RaceParticipantEntry entry, {
    required double height,
    required String badge,
    required Color color,
    bool isFirst = false,
    required DuoColorPalette palette,
  }) {
    return GestureDetector(
      onTap: () => _compareWith(entry),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFirst)
            const Text('👑', style: TextStyle(fontSize: 20)),
          CircleAvatar(
            radius: isFirst ? 26 : 22,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(
              entry.isCurrentUser ? Icons.person_rounded : Icons.directions_run_rounded,
              color: color,
              size: isFirst ? 28 : 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.isCurrentUser ? 'Kamu' : entry.userName.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          Text(
            entry.durationFormatted,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          // Kotak Podium 3D
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  offset: const Offset(0, 3),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                badge,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: isFirst ? 36 : 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(RaceParticipantEntry p, DuoColorPalette palette) {
    Color rankColor = palette.textMuted;
    if (p.rank == 1) rankColor = palette.streakGold;
    if (p.rank == 2) rankColor = const Color(0xFF94A3B8);
    if (p.rank == 3) rankColor = const Color(0xFFD97706);

    return InkWell(
      onTap: () => _compareWith(p),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: p.isCurrentUser
              ? palette.primaryBlue.withOpacity(palette.isDark ? 0.16 : 0.08)
              : palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: p.isCurrentUser ? palette.primaryBlue : palette.surfaceBorder,
            width: p.isCurrentUser ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#${p.rank}',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: palette.background,
              child: Icon(
                p.isCurrentUser ? Icons.person_rounded : Icons.directions_run_rounded,
                color: p.isCurrentUser ? palette.primaryBlue : palette.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.userName,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Pace ${p.paceFormatted} • ${p.steps} langkah',
                    style: TextStyle(color: palette.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  p.durationFormatted,
                  style: TextStyle(
                    color: p.isCurrentUser ? palette.primaryBlue : palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  p.isCurrentUser ? '(Akun Kamu)' : 'Bandingkan ➔',
                  style: TextStyle(
                    color: p.isCurrentUser ? palette.primaryBlue : palette.primaryBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

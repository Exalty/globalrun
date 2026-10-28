import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/race_standing_model.dart';
import '../models/run_record.dart';
import '../models/race_event.dart';
import 'auth_service.dart';
import 'run_history_service.dart';

class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  /// Mengambil daftar semua event yang pernah diselesaikan oleh akun ini beserta peringkat aslinya
  Future<List<MyRaceStanding>> getMyRaceStandings() async {
    final List<MyRaceStanding> results = [];
    final runHistory = RunHistoryService();
    final authService = AuthService();

    // 1. Ambil seluruh lari yang pernah dicatat oleh akun ini (lokal + supabase cloud)
    final attempts = await runHistory.attemptsByEvent();
    final profile = await authService.getUserProfile();
    final myUserId = await authService.getCurrentUserId() ?? 'me';
    final myName = (profile['name'] as String?)?.trim().isNotEmpty == true
        ? profile['name'] as String
        : 'Saya';

    final sampleEvents = RaceEvent.sampleEvents();

    for (final entry in attempts.entries) {
      final eventId = entry.key;
      final record = entry.value;

      // Hanya tampilkan yang berhasil finish
      if (record.distanceKm <= 0.0) continue;

      // Ambil nama event asli
      String title = record.eventTitle;
      if (title.isEmpty || title.startsWith('Race Event #') || title.startsWith('Virtual Race #')) {
        final match = sampleEvents.firstWhere(
          (e) => e.id == eventId || e.id.replaceAll(RegExp(r'[^0-9]'), '') == eventId.replaceAll(RegExp(r'[^0-9]'), ''),
          orElse: () => sampleEvents.first,
        );
        title = match.title;
      }

      // Ambil klasemen peserta asli lomba ini untuk menentukan peringkat akun saya
      final leaderboard = await getRaceLeaderboard(
        eventId,
        eventTitle: title,
        myRecord: record,
        myUserId: myUserId,
        myName: myName,
      );

      // Cari peringkat saya di antara pelari asli
      int rank = 1;
      final myIdx = leaderboard.indexWhere((e) => e.isCurrentUser);
      if (myIdx != -1) {
        rank = leaderboard[myIdx].rank;
      }

      results.add(MyRaceStanding(
        eventId: eventId,
        eventTitle: title,
        distanceKm: record.distanceKm,
        eventType: record.distanceKm > 25.0 ? 'cycling' : 'run',
        myRank: rank,
        totalParticipants: leaderboard.length,
        myDurationSeconds: record.durationSeconds,
        myAvgSpeedKmh: record.avgSpeedKmh,
        mySteps: record.steps,
        blockHash: record.blockHash,
        polygonscanUrl: record.polygonscanUrl,
        completedAt: record.startedAt,
      ));
    }

    // Urutkan dari event yang terbaru diikuti
    results.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return results;
  }

  /// Mengambil klasemen lengkap dari data asli tabel `race_results` & `profiles` di Supabase
  Future<List<RaceParticipantEntry>> getRaceLeaderboard(
    String eventId, {
    String? eventTitle,
    RunRecord? myRecord,
    String? myUserId,
    String? myName,
  }) async {
    final List<RaceParticipantEntry> list = [];
    final currentUserId = myUserId ?? (await AuthService().getCurrentUserId()) ?? 'me';
    final userProfile = await AuthService().getUserProfile();
    final currentUserName = myName ??
        ((userProfile['name'] as String?)?.trim().isNotEmpty == true
            ? userProfile['name'] as String
            : 'Saya');

    final raceIdNum = int.tryParse(eventId.replaceAll(RegExp(r'[^0-9]'), '')) ?? int.tryParse(eventId);

    // 1. Tarik data real dari Supabase table `race_results`
    try {
      final client = Supabase.instance.client;
      var query = client
          .from('race_results')
          .select('id, user_id, duration_seconds, distance_km, avg_speed_kmh, steps_count, block_hash, is_anti_cheat_verified');

      if (raceIdNum != null) {
        query = query.eq('race_id', raceIdNum);
      }

      final rows = await query.order('duration_seconds', ascending: true).limit(100);

      if (rows.isNotEmpty) {
        // Ambil profil asli user dari tabel `profiles`
        final userIds = rows
            .map((r) => r['user_id']?.toString())
            .whereType<String>()
            .toSet()
            .toList();

        final Map<String, Map<String, dynamic>> profilesMap = {};
        if (userIds.isNotEmpty) {
          try {
            final profRows = await client
                .from('profiles')
                .select('id, full_name, email')
                .filter('id', 'in', userIds);
            for (final p in profRows) {
              final id = p['id']?.toString();
              if (id != null) profilesMap[id] = p;
            }
          } catch (e) {
            debugPrint('[LeaderboardService] Error fetching user profiles: $e');
          }
        }

        for (final row in rows) {
          final uId = row['user_id']?.toString() ?? '';
          final prof = profilesMap[uId];
          final rawName = prof?['full_name'] as String?;
          final email = prof?['email'] as String?;
          final displayName = (rawName != null && rawName.trim().isNotEmpty)
              ? rawName.trim()
              : (email != null && email.isNotEmpty ? email.split('@')[0] : 'Atlet');

          final dur = (row['duration_seconds'] as num?)?.toInt() ?? 0;
          final speed = (row['avg_speed_kmh'] as num?)?.toDouble() ?? 0.0;
          final steps = (row['steps_count'] as num?)?.toInt() ?? 0;
          final bHash = row['block_hash'] as String?;
          final isVerified = row['is_anti_cheat_verified'] as bool? ?? true;
          final isMe = uId == currentUserId;

          list.add(RaceParticipantEntry(
            rank: 1, // akan dihitung ulang saat disortir
            userId: uId,
            userName: isMe ? '$displayName (Kamu)' : displayName,
            avatarUrl: null,
            durationSeconds: dur,
            avgSpeedKmh: speed,
            steps: steps,
            isAntiCheatVerified: isVerified,
            isCurrentUser: isMe,
            blockHash: bHash,
          ));
        }
      }
    } catch (e) {
      debugPrint('[LeaderboardService] Error fetching real race_results: $e');
    }

    // 2. Jika akun user saat ini memiliki rekor finish lari di perangkat lokal
    // dan belum tercatat di data cloud, sertakan ke dalam klasemen
    if (myRecord != null && !list.any((e) => e.isCurrentUser || e.userId == currentUserId)) {
      list.add(RaceParticipantEntry(
        rank: 1,
        userId: currentUserId,
        userName: '$currentUserName (Kamu)',
        avatarUrl: userProfile['photo'] as String?,
        durationSeconds: myRecord.durationSeconds,
        avgSpeedKmh: myRecord.avgSpeedKmh,
        steps: myRecord.steps,
        isAntiCheatVerified: !myRecord.isSimulated,
        isCurrentUser: true,
        blockHash: myRecord.blockHash,
      ));
    }

    // 3. Urutkan berdasarkan durasi tersingkat secara kompetitif (durasi terkecil = peringkat 1)
    list.sort((a, b) {
      if (a.durationSeconds != b.durationSeconds) {
        return a.durationSeconds.compareTo(b.durationSeconds);
      }
      return b.avgSpeedKmh.compareTo(a.avgSpeedKmh);
    });

    // 4. Tetapkan nomor ranking final (1, 2, 3...)
    final List<RaceParticipantEntry> finalSorted = [];
    for (int i = 0; i < list.length; i++) {
      final old = list[i];
      finalSorted.add(RaceParticipantEntry(
        rank: i + 1,
        userId: old.userId,
        userName: old.userName,
        avatarUrl: old.avatarUrl,
        durationSeconds: old.durationSeconds,
        avgSpeedKmh: old.avgSpeedKmh,
        steps: old.steps,
        isAntiCheatVerified: old.isAntiCheatVerified,
        isCurrentUser: old.isCurrentUser,
        blockHash: old.blockHash,
      ));
    }

    return finalSorted;
  }
}

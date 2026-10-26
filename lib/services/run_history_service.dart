import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/run_record.dart';

class RunStats {
  final double totalKm;
  final int raceCount; // jumlah event berbeda yang diikuti
  final int medalCount; // jumlah lari yang berhasil mint medali NFT

  const RunStats({
    required this.totalKm,
    required this.raceCount,
    required this.medalCount,
  });

  static const empty = RunStats(totalKm: 0, raceCount: 0, medalCount: 0);
}

/// Penyimpanan riwayat lari (sinkronisasi Cloud Supabase + Cache Lokal terisolasi per akun).
class RunHistoryService {
  static final RunHistoryService _instance = RunHistoryService._();
  factory RunHistoryService() => _instance;
  RunHistoryService._();

  Future<String> _getUserId() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) return user.id;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? prefs.getString('user_email') ?? 'default_runner';
  }

  Future<String> _indexKey() async => 'run_history_ids_${await _getUserId()}';
  Future<String> _recordKey(String id) async => 'run_record_${await _getUserId()}_$id';

  /// Menyimpan riwayat lari: ke Cache Lokal terisolasi per user & ke Supabase table race_results
  Future<void> save(RunRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final indexKey = await _indexKey();
    final recordKey = await _recordKey(record.id);

    await prefs.setString(recordKey, jsonEncode(record.toJson()));
    final ids = prefs.getStringList(indexKey) ?? <String>[];
    if (!ids.contains(record.id)) ids.insert(0, record.id);
    await prefs.setStringList(indexKey, ids);

    // Sinkronisasi online ke tabel race_results di Supabase Cloud
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client.from('race_results').insert({
          'user_id': user.id,
          'race_id': int.tryParse(record.eventId),
          'distance_km': record.distanceKm,
          'duration_seconds': record.durationSeconds,
          'steps_count': record.steps,
          'avg_speed_kmh': record.avgSpeedKmh,
          'block_hash': record.blockHash,
          'is_anti_cheat_verified': !record.isSimulated,
        });
      }
    } catch (e) {
      debugPrint('Sync race_results to Supabase failed (offline fallback): $e');
    }
  }

  /// Memuat semua riwayat lari milik akun yang sedang aktif
  Future<List<RunRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final indexKey = await _indexKey();
    final ids = prefs.getStringList(indexKey) ?? <String>[];
    final out = <RunRecord>[];

    for (final id in ids) {
      final raw = prefs.getString(await _recordKey(id));
      if (raw == null) continue;
      try {
        out.add(RunRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Run record $id rusak: $e');
      }
    }

    // Tarik data riwayat dari Supabase jika ada lari yang tersimpan di cloud
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final res = await client
            .from('race_results')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 3));

        if (res.isNotEmpty) {
          for (final item in res) {
            final raceIdStr = (item['race_id'] ?? '').toString();
            final remoteId = 'remote_${item['id']}';
            final distance = (item['distance_km'] as num?)?.toDouble() ?? 0.0;

            // Jika belum ada di lokal untuk akun ini, tambahkan
            if (!ids.contains(remoteId) && !out.any((r) => r.eventId == raceIdStr && (r.distanceKm - distance).abs() < 0.01)) {
              final rec = RunRecord(
                id: remoteId,
                eventId: raceIdStr,
                eventTitle: 'Race Event #$raceIdStr',
                startedAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now(),
                durationSeconds: (item['duration_seconds'] as num?)?.toInt() ?? 0,
                distanceKm: distance,
                targetKm: distance,
                steps: (item['steps_count'] as num?)?.toInt() ?? 0,
                completed: true,
                isSimulated: !(item['is_anti_cheat_verified'] as bool? ?? true),
                blockHash: item['block_hash'] as String?,
                points: const [],
              );
              out.add(rec);
              await prefs.setString(await _recordKey(remoteId), jsonEncode(rec.toJson()));
              ids.add(remoteId);
              await prefs.setStringList(indexKey, ids);
            }
          }
        }
      }
    } catch (_) {}

    return out;
  }

  /// Peta eventId -> lari terbaru yang SELESAI (target tercapai).
  Future<Map<String, RunRecord>> completedByEvent() async {
    final all = await loadAll();
    final map = <String, RunRecord>{};
    for (final r in all) {
      if (r.completed) map.putIfAbsent(r.eventId, () => r);
    }
    return map;
  }

  /// Statistik karier dihitung dari riwayat lari akun yang aktif.
  Future<RunStats> computeStats() async {
    final all = await loadAll();
    var totalKm = 0.0;
    final eventIds = <String>{};
    var medals = 0;
    for (final r in all) {
      totalKm += r.distanceKm;
      eventIds.add(r.eventId);
      if (r.blockHash != null) medals++;
    }
    return RunStats(
      totalKm: totalKm,
      raceCount: eventIds.length,
      medalCount: medals,
    );
  }

  /// true = 1 race hanya bisa diikuti sekali (apa pun hasilnya).
  static const bool oneAttemptPerRace = true;

  /// Peta eventId -> lari terbaru untuk event itu milik akun ini.
  Future<Map<String, RunRecord>> attemptsByEvent() async {
    final all = await loadAll();
    final map = <String, RunRecord>{};
    for (final r in all) {
      map.putIfAbsent(r.eventId, () => r);
    }
    return map;
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final recordKey = await _recordKey(id);
    final indexKey = await _indexKey();
    await prefs.remove(recordKey);
    final ids = prefs.getStringList(indexKey) ?? <String>[];
    ids.remove(id);
    await prefs.setStringList(indexKey, ids);
  }
}

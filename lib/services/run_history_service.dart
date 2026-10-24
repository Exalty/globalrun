import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/run_record.dart';

class RunStats {
  final double totalKm;
  final int raceCount;   // jumlah event berbeda yang diikuti
  final int medalCount;  // jumlah lari yang berhasil mint medali NFT

  const RunStats({
    required this.totalKm,
    required this.raceCount,
    required this.medalCount,
  });

  static const empty = RunStats(totalKm: 0, raceCount: 0, medalCount: 0);
}
/// Penyimpanan riwayat lari (satu key per lari + satu key indeks).
class RunHistoryService {
  static final RunHistoryService _instance = RunHistoryService._();
  factory RunHistoryService() => _instance;
  RunHistoryService._();

  static const String _indexKey = 'run_history_ids';
  String _key(String id) => 'run_record_$id';

  Future<void> save(RunRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(record.id), jsonEncode(record.toJson()));
    final ids = prefs.getStringList(_indexKey) ?? <String>[];
    if (!ids.contains(record.id)) ids.insert(0, record.id);
    await prefs.setStringList(_indexKey, ids);
  }

  Future<List<RunRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_indexKey) ?? <String>[];
    final out = <RunRecord>[];
    for (final id in ids) {
      final raw = prefs.getString(_key(id));
      if (raw == null) continue;
      try {
        out.add(RunRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Run record $id rusak: $e');
      }
    }
    return out;
  }
  /// Peta eventId -> lari terbaru yang SELESAI (target tercapai).
  /// loadAll() sudah urut terbaru dulu, jadi putIfAbsent mengambil yang terbaru.
  Future<Map<String, RunRecord>> completedByEvent() async {
    final all = await loadAll();
    final map = <String, RunRecord>{};
    for (final r in all) {
      if (r.completed) map.putIfAbsent(r.eventId, () => r);
    }
    return map;
  }
  /// Statistik karier dihitung dari riwayat lari yang tersimpan.
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
  /// Set false saat testing.
  static const bool oneAttemptPerRace = true;

  /// Peta eventId -> lari terbaru untuk event itu (selesai atau tidak).
  Future<Map<String, RunRecord>> attemptsByEvent() async {
    final all = await loadAll(); // urut terbaru dulu
    final map = <String, RunRecord>{};
    for (final r in all) {
      map.putIfAbsent(r.eventId, () => r);
    }
    return map;
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(id));
    final ids = prefs.getStringList(_indexKey) ?? <String>[];
    ids.remove(id);
    await prefs.setStringList(_indexKey, ids);
  }
}
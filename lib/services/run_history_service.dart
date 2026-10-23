import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/run_record.dart';

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

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(id));
    final ids = prefs.getStringList(_indexKey) ?? <String>[];
    ids.remove(id);
    await prefs.setStringList(_indexKey, ids);
  }
}
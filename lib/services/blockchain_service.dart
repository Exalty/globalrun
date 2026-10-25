import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/blockchain_record.dart';

class BlockchainService {
  static const String _storageKey = 'global_race_blockchain_ledger';

  static const String _genesisPrev =
      '0000000000000000000000000000000000000000000000000000000000000000';
  static const String _genesisTimestamp = '2026-01-01T00:00:00Z';
  static const String _genesisTitle = 'Global Virtual Race Genesis';

  // Judul lama yang dulu dipakai saat menghitung hash genesis (versi awal).
  // Dipertahankan agar ledger lama di HP tetap dianggap valid.
  static const String _legacyGenesisHashTitle =
      'Global Virtual Race Foundation Genesis Block';

  final List<Block> _chain = [];

  /// Selesai saat ledger sudah dimuat dari penyimpanan.
  /// Semua pemanggil yang butuh data rantai harus `await ready` dulu.
  late final Future<void> ready;

  List<Block> get chain => List.unmodifiable(_chain);

  /// Jumlah medali (tanpa blok genesis).
  int get medalCount => _chain.where((b) => !b.isGenesis).length;

  // Singleton: semua BlockchainService() di app memakai satu instance yang sama,
  // sehingga rantai di memori tidak pernah berbeda antar layar.
  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;

  BlockchainService._internal() {
    ready = _initLedger();
  }

  // ───────────────────────── INIT / STORAGE ─────────────────────────

  Future<void> _initLedger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey);

      if (jsonList != null && jsonList.isNotEmpty) {
        _chain.clear();
        for (final item in jsonList) {
          _chain.add(Block.fromJson(jsonDecode(item) as Map<String, dynamic>));
        }
        return;
      }
    } catch (e) {
      debugPrint('Ledger rusak, membuat ulang dari genesis: $e');
    }

    _chain.clear();
    _chain.add(_createGenesisBlock());
    await _saveLedger();
  }

  Future<void> _saveLedger() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _chain.map((b) => jsonEncode(b.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }

  Block _createGenesisBlock() {
    final hash = Block.calculateHash(
      index: 0,
      timestamp: _genesisTimestamp,
      raceId: 'GENESIS-RACE',
      raceTitle: _genesisTitle,
      participantName: 'Satoshi Runner',
      distanceKm: 0.0,
      durationSeconds: 0,
      stepsCount: 0,
      avgSpeedKmh: 0.0,
      previousHash: _genesisPrev,
    );

    return Block(
      index: 0,
      timestamp: _genesisTimestamp,
      raceId: 'GENESIS-RACE',
      raceTitle: _genesisTitle,
      participantName: 'Satoshi Runner',
      distanceKm: 0.0,
      durationSeconds: 0,
      stepsCount: 0,
      avgSpeedKmh: 0.0,
      previousHash: _genesisPrev,
      hash: hash,
    );
  }

  // ───────────────────────── QUERY ─────────────────────────

  /// Blok pada index tertentu, atau null (belum dimuat / tidak ada).
  Block? blockAt(int index) {
    if (index < 0 || index >= _chain.length) return null;
    return _chain[index];
  }

  /// Medali yang sudah dicetak untuk race + peserta ini, atau null.
  Block? blockForRace(String raceId, String participantName) {
    for (final b in _chain) {
      if (!b.isGenesis &&
          b.raceId == raceId &&
          b.participantName == participantName) {
        return b;
      }
    }
    return null;
  }

  // ───────────────────────── MINT ─────────────────────────

  /// Mencetak medali. Idempotent: jika race + peserta ini sudah punya medali,
  /// blok yang ada dikembalikan (tidak ada duplikat).
  Future<Block> mintMedalBlock({
    required String raceId,
    required String raceTitle,
    required String participantName,
    required double distanceKm,
    required int durationSeconds,
    required int stepsCount,
    required double avgSpeedKmh,
  }) async {
    await ready; // pastikan ledger sudah dimuat

    // Bagian di bawah ini sengaja tanpa `await` sampai _chain.add(...),
    // supaya dua mint bersamaan tidak bisa menghasilkan index yang sama.
    final existing = blockForRace(raceId, participantName);
    if (existing != null) return existing;

    final previousBlock = _chain.last;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final index = _chain.length;

    final hash = Block.calculateHash(
      index: index,
      timestamp: timestamp,
      raceId: raceId,
      raceTitle: raceTitle,
      participantName: participantName,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      stepsCount: stepsCount,
      avgSpeedKmh: avgSpeedKmh,
      previousHash: previousBlock.hash,
    );

    final newBlock = Block(
      index: index,
      timestamp: timestamp,
      raceId: raceId,
      raceTitle: raceTitle,
      participantName: participantName,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      stepsCount: stepsCount,
      avgSpeedKmh: avgSpeedKmh,
      previousHash: previousBlock.hash,
      hash: hash,
    );

    _chain.add(newBlock);
    await _saveLedger();
    return newBlock;
  }

  // ───────────────────────── VALIDASI ─────────────────────────

  bool _genesisHashOk(Block b) {
    String h(String title) => Block.calculateHash(
          index: b.index,
          timestamp: b.timestamp,
          raceId: b.raceId,
          raceTitle: title,
          participantName: b.participantName,
          distanceKm: b.distanceKm,
          durationSeconds: b.durationSeconds,
          stepsCount: b.stepsCount,
          avgSpeedKmh: b.avgSpeedKmh,
          previousHash: b.previousHash,
        );
    return b.hash == h(b.raceTitle) || b.hash == h(_legacyGenesisHashTitle);
  }

  /// Index blok pertama yang rusak, atau null jika seluruh rantai valid.
  int? findInvalidBlockIndex() {
    if (_chain.isEmpty) return 0;

    for (var i = 0; i < _chain.length; i++) {
      final current = _chain[i];

      // Urutan index harus berurutan tanpa celah
      if (current.index != i) return i;

      if (i == 0) {
        if (current.previousHash != _genesisPrev || !_genesisHashOk(current)) {
          return 0;
        }
        continue;
      }

      final recalculated = Block.calculateHash(
        index: current.index,
        timestamp: current.timestamp,
        raceId: current.raceId,
        raceTitle: current.raceTitle,
        participantName: current.participantName,
        distanceKm: current.distanceKm,
        durationSeconds: current.durationSeconds,
        stepsCount: current.stepsCount,
        avgSpeedKmh: current.avgSpeedKmh,
        previousHash: current.previousHash,
      );

      if (current.hash != recalculated) return i; // isi blok diubah
      if (current.previousHash != _chain[i - 1].hash) return i; // rantai putus
    }
    return null;
  }

  bool verifyLedgerIntegrity() => findInvalidBlockIndex() == null;
}
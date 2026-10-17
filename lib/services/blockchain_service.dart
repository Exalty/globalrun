import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/blockchain_record.dart';

class BlockchainService {
  static const String _storageKey = 'global_race_blockchain_ledger';
  final List<Block> _chain = [];

  List<Block> get chain => List.unmodifiable(_chain);

  BlockchainService() {
    _initLedger();
  }

  Future<void> _initLedger() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey);

    if (jsonList != null && jsonList.isNotEmpty) {
      _chain.clear();
      for (final item in jsonList) {
        _chain.add(Block.fromJson(jsonDecode(item)));
      }
    } else {
      // Create Genesis block
      _chain.clear();
      final genesis = _createGenesisBlock();
      _chain.add(genesis);
      await _saveLedger();
    }
  }

  Block _createGenesisBlock() {
    const timestamp = '2026-01-01T00:00:00Z';
    const genesisPrev = '0000000000000000000000000000000000000000000000000000000000000000';
    final hash = Block.calculateHash(
      index: 0,
      timestamp: timestamp,
      raceId: 'GENESIS-RACE',
      raceTitle: 'Global Virtual Race Foundation Genesis Block',
      participantName: 'Satoshi Runner',
      distanceKm: 0.0,
      durationSeconds: 0,
      stepsCount: 0,
      avgSpeedKmh: 0.0,
      previousHash: genesisPrev,
    );

    return Block(
      index: 0,
      timestamp: timestamp,
      raceId: 'GENESIS-RACE',
      raceTitle: 'Global Virtual Race Genesis',
      participantName: 'Satoshi Runner',
      distanceKm: 0.0,
      durationSeconds: 0,
      stepsCount: 0,
      avgSpeedKmh: 0.0,
      previousHash: genesisPrev,
      hash: hash,
    );
  }

  Future<Block> mintMedalBlock({
    required String raceId,
    required String raceTitle,
    required String participantName,
    required double distanceKm,
    required int durationSeconds,
    required int stepsCount,
    required double avgSpeedKmh,
  }) async {
    final previousBlock = _chain.isNotEmpty ? _chain.last : _createGenesisBlock();
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

  bool verifyLedgerIntegrity() {
    for (int i = 1; i < _chain.length; i++) {
      final current = _chain[i];
      final previous = _chain[i - 1];

      // Check current block's hash validity
      final recalculatedHash = Block.calculateHash(
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

      if (current.hash != recalculatedHash) {
        return false;
      }

      // Check chain linkage
      if (current.previousHash != previous.hash) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveLedger() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _chain.map((b) => jsonEncode(b.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }
}

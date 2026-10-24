import 'dart:convert';
import 'package:crypto/crypto.dart';

class Block {
  final int index;
  final String timestamp;
  final String raceId;
  final String raceTitle;
  final String participantName;
  final double distanceKm;
  final int durationSeconds;
  final int stepsCount;
  final double avgSpeedKmh;
  final String previousHash;
  final String hash;

  Block({
    required this.index,
    required this.timestamp,
    required this.raceId,
    required this.raceTitle,
    required this.participantName,
    required this.distanceKm,
    required this.durationSeconds,
    required this.stepsCount,
    required this.avgSpeedKmh,
    required this.previousHash,
    required this.hash,
  });

  // ───────────── Metadata NFT (dihitung, TIDAK masuk ke hash) ─────────────
  // Karena tidak ikut dihitung dalam hash, blok lama tetap valid.

  bool get isGenesis => index == 0;

  /// ID token unik, contoh: GVR-0007
  String get tokenId => 'GVR-${index.toString().padLeft(4, '0')}';

  /// Tier medali berdasarkan kecepatan rata-rata (ubah ambang sesuai selera).
  String get tier {
    if (isGenesis) return 'GENESIS';
    if (avgSpeedKmh >= 10.0) return 'GOLD';
    if (avgSpeedKmh >= 7.0) return 'SILVER';
    return 'BRONZE';
  }

  static String calculateHash({
    required int index,
    required String timestamp,
    required String raceId,
    required String raceTitle,
    required String participantName,
    required double distanceKm,
    required int durationSeconds,
    required int stepsCount,
    required double avgSpeedKmh,
    required String previousHash,
  }) {
    final payload =
        '$index|$timestamp|$raceId|$raceTitle|$participantName|$distanceKm|$durationSeconds|$stepsCount|$avgSpeedKmh|$previousHash';
    final bytes = utf8.encode(payload);
    return sha256.convert(bytes).toString();
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'timestamp': timestamp,
        'raceId': raceId,
        'raceTitle': raceTitle,
        'participantName': participantName,
        'distanceKm': distanceKm,
        'durationSeconds': durationSeconds,
        'stepsCount': stepsCount,
        'avgSpeedKmh': avgSpeedKmh,
        'previousHash': previousHash,
        'hash': hash,
      };

  factory Block.fromJson(Map<String, dynamic> json) => Block(
        index: json['index'],
        timestamp: json['timestamp'],
        raceId: json['raceId'],
        raceTitle: json['raceTitle'],
        participantName: json['participantName'],
        distanceKm: (json['distanceKm'] as num).toDouble(),
        durationSeconds: json['durationSeconds'],
        stepsCount: json['stepsCount'],
        avgSpeedKmh: (json['avgSpeedKmh'] as num).toDouble(),
        previousHash: json['previousHash'],
        hash: json['hash'],
      );
}
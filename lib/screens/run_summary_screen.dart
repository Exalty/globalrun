import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/blockchain_record.dart';
import '../models/run_record.dart';
import '../services/blockchain_service.dart';
import 'blockchain_certificate_screen.dart';

/// Ringkasan lari ala Strava: peta rute (fit ke seluruh jejak), statistik, split per KM.
class RunSummaryScreen extends StatelessWidget {
  final RunRecord record;
  final BlockchainService? blockchainService;
  final Block? block;

  const RunSummaryScreen({
    super.key,
    required this.record,
    this.blockchainService,
    this.block,
  });

  @override
  Widget build(BuildContext context) {
    final splits = record.computeSplits();
    final fastest = splits.isEmpty
        ? 1
        : splits.map((s) => s.seconds).reduce((a, b) => a < b ? a : b);
    final slowest = splits.isEmpty
        ? 1
        : splits.map((s) => s.seconds).reduce((a, b) => a > b ? a : b);

    // Medali: pakai blok yang dikirim (lari baru selesai), atau cari di ledger
    // berdasarkan index yang tersimpan di riwayat (lari lama).
    final Block? medal = block ??
        ((record.blockIndex != null && blockchainService != null)
            ? blockchainService!.blockAt(record.blockIndex!)
            : null);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(record.eventTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: Column(
        children: [
          SizedBox(height: 280, child: _buildMap()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Icon(
                      record.completed ? Icons.emoji_events_rounded : Icons.flag_outlined,
                      color: record.completed ? Colors.amber : Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.completed
                            ? 'Target ${record.targetKm} KM tercapai!'
                            : 'Dihentikan sebelum target (${record.targetKm} KM)',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  RunFormat.date(record.startedAt) + (record.isSimulated ? '  •  Simulasi' : ''),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _stat('JARAK', '${record.distanceKm.toStringAsFixed(2)} km'),
                    _stat('WAKTU', RunFormat.duration(record.durationSeconds)),
                    _stat('PACE', '${RunFormat.pace(record.avgPaceSecPerKm)} /km'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _stat('KECEPATAN', '${record.avgSpeedKmh.toStringAsFixed(1)} km/h'),
                    _stat('LANGKAH', '${record.steps}'),
                    _stat('CADENCE',
                        record.durationSeconds > 0
                            ? '${(record.steps / (record.durationSeconds / 60)).round()} spm'
                            : '-'),
                  ],
                ),
                if (splits.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('SPLIT PER KM',
                      style: TextStyle(
                          color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  for (final s in splits)
                    _splitRow(s, fastest, slowest),
                ],
                if (record.blockHash != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Blok #${record.blockIndex}  ${record.blockHash!.substring(0, 24)}...',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
                const SizedBox(height: 16),
                if (medal != null && blockchainService != null)
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlockchainCertificateScreen(
                          blockchainService: blockchainService!,
                          highlightBlock: medal,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.workspace_premium_rounded),
                    label: const Text('Buka Medali NFT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Selesai'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final pts = record.latLngs;
    final hasRoute = pts.length >= 2;
    return FlutterMap(
      options: MapOptions(
        initialCenter: pts.isNotEmpty ? pts.first : const LatLng(-6.2088, 106.8456),
        initialZoom: 16,
        initialCameraFit: hasRoute
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(pts),
                padding: const EdgeInsets.all(40),
                maxZoom: 18,
              )
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.runcompete.virtualrace',
        ),
        if (hasRoute)
          PolylineLayer(
            polylines: [
              Polyline(
                points: pts,
                strokeWidth: 5.0,
                color: Colors.deepOrangeAccent,
                borderStrokeWidth: 2.0,
                borderColor: Colors.white,
              ),
            ],
          ),
        if (pts.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: pts.first,
                width: 28,
                height: 28,
                child: const Icon(Icons.trip_origin_rounded, color: Colors.greenAccent, size: 26),
              ),
              if (hasRoute)
                Marker(
                  point: pts.last,
                  width: 32,
                  height: 32,
                  child: const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 30),
                ),
            ],
          ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _splitRow(RunSplit s, int fastest, int slowest) {
    final range = (slowest - fastest).clamp(1, 1 << 30);
    // Split tercepat = bar terpanjang
    final ratio = 1.0 - ((s.seconds - fastest) / range) * 0.6;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('${s.km}',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.1, 1.0),
                minHeight: 10,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(Colors.cyanAccent),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(RunFormat.pace(s.seconds),
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
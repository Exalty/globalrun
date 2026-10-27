import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/blockchain_record.dart';
import '../models/run_record.dart';
import '../services/blockchain_service.dart';
import '../theme/duo_theme.dart';
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

    final Block? medal = block ??
        ((record.blockIndex != null && blockchainService != null)
            ? blockchainService!.blockAt(record.blockIndex!)
            : null);

    final palette = DuoColors.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          record.eventTitle.toUpperCase(),
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
                      color: record.completed ? DuoColors.streakGold : palette.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.completed
                            ? 'Target ${record.targetKm} KM tercapai!'
                            : 'Dihentikan sebelum target (${record.targetKm} KM)',
                        style: TextStyle(
                            color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  RunFormat.date(record.startedAt) + (record.isSimulated ? '  •  Simulasi' : ''),
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _stat(palette, 'JARAK', '${record.distanceKm.toStringAsFixed(2)} km'),
                    _stat(palette, 'WAKTU', RunFormat.duration(record.durationSeconds)),
                    _stat(palette, 'PACE', '${RunFormat.pace(record.avgPaceSecPerKm)} /km'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _stat(palette, 'KECEPATAN', '${record.avgSpeedKmh.toStringAsFixed(1)} km/h'),
                    _stat(palette, 'LANGKAH', '${record.steps}'),
                    _stat(palette, 'CADENCE',
                        record.durationSeconds > 0
                            ? '${(record.steps / (record.durationSeconds / 60)).round()} spm'
                            : '-'),
                  ],
                ),
                if (splits.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('SPLIT PER KM',
                      style: TextStyle(
                          color: palette.primaryBlue, fontWeight: FontWeight.w900, fontSize: 12)),
                  const SizedBox(height: 8),
                  for (final s in splits)
                    _splitRow(palette, s, fastest, slowest),
                ],
                if (record.blockHash != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Blok #${record.blockIndex}  ${record.blockHash!.substring(0, 24)}...',
                    style: TextStyle(
                        color: palette.textMuted, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
                if (record.polygonscanUrl != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => launchUrl(
                      Uri.parse(record.polygonscanUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.public_rounded, color: DuoColors.questGreen, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Lihat On-Chain di Polygonscan',
                          style: TextStyle(
                            color: DuoColors.questGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (medal != null && blockchainService != null) ...[
                  DuoButton(
                    text: 'BUKA MEDALI NFT',
                    height: 48,
                    backgroundColor: palette.neonCyan,
                    shadowColor: palette.neonCyanShadow,
                    textColor: Colors.black,
                    icon: const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 20),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlockchainCertificateScreen(
                          blockchainService: blockchainService!,
                          highlightBlock: medal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                DuoButton(
                  text: 'SELESAI',
                  height: 48,
                  backgroundColor: palette.secondaryButton,
                  shadowColor: palette.secondaryButtonShadow,
                  textColor: palette.textPrimary,
                  onPressed: () => Navigator.pop(context),
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

  Widget _stat(DuoColorPalette palette, String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.surfaceBorder, width: 1.5),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: palette.textMuted, fontSize: 10, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _splitRow(DuoColorPalette palette, RunSplit s, int fastest, int slowest) {
    final range = (slowest - fastest).clamp(1, 1 << 30);
    final ratio = 1.0 - ((s.seconds - fastest) / range) * 0.6;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('${s.km}',
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.1, 1.0),
                minHeight: 10,
                backgroundColor: palette.surfaceBorder,
                valueColor: AlwaysStoppedAnimation(palette.primaryBlue),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(RunFormat.pace(s.seconds),
                textAlign: TextAlign.right,
                style: TextStyle(color: palette.textPrimary, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

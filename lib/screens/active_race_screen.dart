import 'dart:async';
import 'dart:math' show pi;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../models/race_event.dart';
import '../models/blockchain_record.dart';
import '../models/run_record.dart';
import '../services/sensor_service.dart';
import '../services/location_service.dart';
import '../services/blockchain_service.dart';
import '../services/ai_coach_service.dart';
import '../services/notification_service.dart';
import '../services/run_history_service.dart';
import '../services/auth_service.dart';
import 'ai_coach_screen.dart';
import 'run_summary_screen.dart';

/// Untuk demo: lari hasil simulasi boleh mint NFT. Set false di produksi.
const bool _mintSimulatedRuns = true;

class ActiveRaceScreen extends StatefulWidget {
  final RaceEvent event;
  final BlockchainService blockchainService;
  final AiCoachService aiCoachService;

  const ActiveRaceScreen({
    super.key,
    required this.event,
    required this.blockchainService,
    required this.aiCoachService,
  });

  @override
  State<ActiveRaceScreen> createState() => _ActiveRaceScreenState();
}

class _ActiveRaceScreenState extends State<ActiveRaceScreen> {
  final MapController _mapController = MapController();
  late final LocationTrackingService _location;
  late final MotionSensorService _sensor;

  Timer? _uiTicker;
  bool _isFinishing = false;
  bool _followUser = true;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _location = Provider.of<LocationTrackingService>(context, listen: false);
    _sensor = Provider.of<MotionSensorService>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _guardOrStart());
  }

  /// Jika event ini sudah pernah diikuti, jangan mulai tracking.
  /// Langsung tampilkan hasil lari sebelumnya.
  Future<void> _guardOrStart() async {
    if (RunHistoryService.oneAttemptPerRace) {
      try {
        final prev = (await RunHistoryService().attemptsByEvent())[
            widget.event.id.toString()];
        if (prev != null) {
          if (!mounted) return;
          // Tandai agar dispose() tidak menganggap ini keluar paksa saat race
          _isFinishing = true;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RunSummaryScreen(
                record: prev,
                blockchainService: widget.blockchainService,
              ),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('Cek riwayat race gagal: $e');
      }
    }
    if (mounted) _startRaceSession();
  }

  Future<void> _startRaceSession() async {
    _sensor.resetSteps();
    _location.resetTrack();
    _location.addListener(_onLocationChanged);

    _sensor.startTracking();
    await _location.startTracking();

    NotificationService().showNotification(
      title: 'Race Berlangsung: ${widget.event.title}',
      body: 'Modul GPS & Sensor Anti-Cheat aktif. Jaga ritme langkahmu menuju garis finish.',
      type: 'flag_off',
    );

    // Timer hanya untuk refresh UI + cek target. Waktu lari diambil dari
    // _location.elapsed (berbasis DateTime) sehingga akurat di background.
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isFinishing) return;
      setState(() {});
      if (!_location.isPaused && _location.totalDistanceKm >= widget.event.distanceKm) {
        _finishRace(targetReached: true);
      }
    });
  }

  // Peta mengikuti pelari selama mode follow aktif
  void _onLocationChanged() {
    if (_followUser && _mapReady && _location.hasFix) {
      _mapController.move(_location.currentLocation, _mapController.camera.zoom);
    }
  }

  void _togglePause() {
    if (_location.isPaused) {
      _location.resume();
      _sensor.resume();
    } else {
      _location.pause();
      _sensor.pause();
    }
  }

  Future<void> _confirmStop() async {
    if (_isFinishing) return;
    final reached = _location.totalDistanceKm >= widget.event.distanceKm;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Akhiri lari?', style: TextStyle(color: Colors.white)),
        content: Text(
          reached
              ? 'Target tercapai. Lari akan disimpan dan medali NFT dibuat.'
              : 'Jarak ${_location.totalDistanceKm.toStringAsFixed(2)} / ${widget.event.distanceKm} KM. '
                  'Lari tetap disimpan ke riwayat, tetapi medali NFT hanya diberikan jika target tercapai.'
                  '${RunHistoryService.oneAttemptPerRace ? '\n\nRace ini hanya bisa diikuti sekali, jadi kamu tidak bisa mengulanginya.' : ''}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Lanjut Lari')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            child: const Text('Akhiri'),
          ),
        ],
      ),
    );
    if (ok == true) _finishRace(targetReached: reached);
  }

  Future<void> _finishRace({required bool targetReached}) async {
    if (_isFinishing) return;
    _isFinishing = true;
    _uiTicker?.cancel();
    _location.removeListener(_onLocationChanged);

    // Ambil snapshot data SEBELUM tracking dimatikan
    final durationSec = _location.elapsed.inSeconds;
    final distanceKm = _location.totalDistanceKm;
    final steps = _sensor.stepCount;
    final isSim = _location.usedSimulation;
    final startedAt = _location.startTime ?? DateTime.now();
    final points = _location.trackPoints
        .map((t) => RunPoint(t.position.latitude, t.position.longitude, t.elapsedMs))
        .toList();

    _location.stopTracking();
    _sensor.stopTracking();

    var record = RunRecord(
      id: 'run_${DateTime.now().millisecondsSinceEpoch}',
      eventId: widget.event.id.toString(),
      eventTitle: widget.event.title,
      startedAt: startedAt,
      durationSeconds: durationSec,
      distanceKm: distanceKm,
      targetKm: widget.event.distanceKm.toDouble(),
      steps: steps,
      completed: targetReached,
      isSimulated: isSim,
      points: points,
    );

    Block? minted;
    if (targetReached && (!isSim || _mintSimulatedRuns)) {
      try {
        final avgSpeed = durationSec > 0 ? distanceKm / (durationSec / 3600.0) : 0.0;
        // Nama peserta diambil dari akun yang sedang login
        final profile = await AuthService().getUserProfile();
        final rawName = (profile['name'] as String?)?.trim() ?? '';
        final participant = rawName.isEmpty ? 'Garuda Runner' : rawName;
        minted = await widget.blockchainService.mintMedalBlock(
          raceId: widget.event.id,
          raceTitle: widget.event.title,
          participantName: participant,
          distanceKm: distanceKm,
          durationSeconds: durationSec,
          stepsCount: steps,
          avgSpeedKmh: avgSpeed,
        );
        record = record.withBlock(minted.index, minted.hash);
      } catch (e) {
        debugPrint('Mint gagal: $e');
      }
    }

    // Selalu simpan jejak lari ke riwayat, walau berhenti lebih awal
    try {
      await RunHistoryService().save(record);
    } catch (e) {
      debugPrint('Gagal menyimpan riwayat lari: $e');
    }

    if (minted != null) {
      NotificationService().showNotification(
        title: 'Finish Terverifikasi: ${widget.event.title}',
        body:
            'Selamat! Total jarak ${distanceKm.toStringAsFixed(2)} KM tervalidasi. Medali NFT Blok #${minted.index} tersimpan di blockchain.',
        type: 'achievement',
        payload: 'open_nft',
      );
    } else {
      NotificationService().showNotification(
        title: 'Lari Tersimpan',
        body: '${distanceKm.toStringAsFixed(2)} KM dalam ${RunFormat.duration(durationSec)} masuk ke riwayat lari Anda.',
        type: 'system',
      );
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RunSummaryScreen(
          record: record,
          blockchainService: widget.blockchainService,
          block: minted,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    _location.removeListener(_onLocationChanged);
    if (!_isFinishing) {
      // Keluar paksa: pastikan GPS & sensor tidak menyala terus
      _location.stopTracking();
      _sensor.stopTracking();
    }
    _mapController.dispose();
    super.dispose();
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final sensor = Provider.of<MotionSensorService>(context);
    final location = Provider.of<LocationTrackingService>(context);
    final progressRatio =
        (location.totalDistanceKm / widget.event.distanceKm).clamp(0.0, 1.0);
    final elapsedSec = location.elapsed.inSeconds;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: Text(widget.event.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: const Color(0xFF1E293B),
          actions: [
            IconButton(
              icon: const Icon(Icons.smart_toy_rounded, color: Colors.cyanAccent),
              tooltip: 'Tanya AI Coach',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiCoachScreen(
                      coachService: widget.aiCoachService,
                      currentDistanceKm: location.totalDistanceKm,
                      currentSteps: sensor.stepCount,
                      currentSpeedKmh: location.currentSpeedKmh,
                      durationSeconds: elapsedSec,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(flex: 5, child: _buildMapArea(location, sensor)),
            _buildHud(location, sensor, progressRatio, elapsedSec),
          ],
        ),
      ),
    );
  }

  Widget _buildMapArea(LocationTrackingService location, MotionSensorService sensor) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: location.currentLocation,
            initialZoom: 17,
            onMapReady: () => _mapReady = true,
            onPositionChanged: (camera, hasGesture) {
              // User menggeser peta manual -> matikan auto-follow
              if (hasGesture && _followUser) setState(() => _followUser = false);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.runcompete.virtualrace',
            ),
            if (location.routePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: location.routePoints,
                    strokeWidth: 5.0,
                    color: Colors.cyanAccent,
                    borderStrokeWidth: 1.5,
                    borderColor: Colors.black54,
                  ),
                ],
              ),
            if (location.hasFix)
              MarkerLayer(
                markers: [
                  Marker(
                    point: location.currentLocation,
                    width: 44,
                    height: 44,
                    // Hanya marker yang rebuild saat kompas berubah
                    child: ValueListenableBuilder<double>(
                      valueListenable: location.heading,
                      builder: (_, deg, __) => Transform.rotate(
                        angle: deg * pi / 180.0,
                        child: _buildArrow(),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),

        // Status GPS + tombol simulasi
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: _buildGpsChip(location)),
              if (kDebugMode) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    if (!location.isSimulating) {
                      location.enableSimulation();
                      sensor.enableSimulation();
                    }
                  },
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: Text(location.isSimulating ? 'Simulating' : 'Simulasi Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        location.isSimulating ? Colors.amber : const Color(0xFF1E293B),
                    foregroundColor: location.isSimulating ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),

        if (location.isPaused)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black38,
                alignment: Alignment.center,
                child: const Text('PAUSE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4)),
              ),
            ),
          ),

        if (!_followUser)
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.cyanAccent,
              onPressed: () {
                setState(() => _followUser = true);
                if (_mapReady) _mapController.move(location.currentLocation, 17);
              },
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
      ],
    );
  }

  Widget _buildArrow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.cyanAccent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 3),
        ],
      ),
      child: const Icon(Icons.navigation_rounded, color: Colors.black87, size: 26),
    );
  }

  Widget _buildGpsChip(LocationTrackingService location) {
    final hasError = location.statusMessage != null && !location.isSimulating;
    final String text;
    final Color dot;
    if (hasError) {
      text = location.statusMessage!;
      dot = Colors.redAccent;
    } else if (location.isSimulating) {
      text = 'LBS Mock Simulator GPS';
      dot = Colors.amber;
    } else if (!location.hasFix || location.gpsAccuracy == null) {
      // Belum ada fix asli dari stream GPS
      text = 'Mencari sinyal GPS...';
      dot = Colors.amber;
    } else {
      final acc = location.gpsAccuracy!;
      text = 'Live GPS  ±${acc.round()} m · ${location.fixCount} fix';
      dot = acc <= 15 ? Colors.greenAccent : Colors.amber;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHud(LocationTrackingService location, MotionSensorService sensor,
      double progressRatio, int elapsedSec) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${location.totalDistanceKm.toStringAsFixed(2)} / ${widget.event.distanceKm} KM',
                  style: const TextStyle(
                      color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text('${(progressRatio * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressRatio,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(Colors.cyanAccent),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetricCard(Icons.timer_rounded, 'WAKTU', RunFormat.duration(elapsedSec)),
                const SizedBox(width: 6),
                _buildMetricCard(Icons.speed_rounded, 'PACE',
                    RunFormat.paceFromSpeed(location.currentSpeedKmh)),
                const SizedBox(width: 6),
                _buildMetricCard(Icons.bolt_rounded, 'KM/H',
                    location.currentSpeedKmh.toStringAsFixed(1)),
                const SizedBox(width: 6),
                _buildMetricCard(Icons.directions_walk_rounded, 'STEPS', '${sensor.stepCount}'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.sensors_rounded, color: Colors.amberAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Sensor Gerak: ${sensor.motionState}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  Text('Mag: ${sensor.currentMagnitude.toStringAsFixed(2)} m/s²',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _togglePause,
                    icon: Icon(location.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                    label: Text(location.isPaused ? 'Lanjut' : 'Pause'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _confirmStop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Selesai'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
import 'dart:async';
import 'dart:math' show pi;
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
import '../theme/duo_theme.dart';

/// Untuk demo: lari hasil simulasi boleh mint NFT. Set false di produksi.
const bool _mintSimulatedRuns = true;

/// Tampilkan tombol & kontrol simulasi (percepat / lompat ke finish).
/// Set false di produksi.
const bool _showSimulationTools = true;

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
      builder: (ctx) {
        final palette = DuoColors.of(ctx);
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: palette.surfaceBorder, width: 2),
          ),
          title: Text('Akhiri Lari?', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
          content: Text(
            reached
                ? 'Target tercapai! Lari akan disimpan dan medali NFT dicetak ke blockchain.'
                : 'Jarak ${_location.totalDistanceKm.toStringAsFixed(2)} / ${widget.event.distanceKm} KM. '
                    'Lari tetap disimpan ke riwayat, tetapi medali NFT hanya diberikan jika target tercapai.'
                    '${RunHistoryService.oneAttemptPerRace ? '\n\nRace ini hanya bisa diikuti sekali, jadi kamu tidak bisa mengulanginya.' : ''}',
            style: TextStyle(color: palette.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Lanjut Lari', style: TextStyle(color: palette.textMuted, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: DuoColors.heartRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Akhiri', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
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

  // ───────────────────────── KONTROL SIMULASI (DEMO) ─────────────────────────

  /// Lompat langsung ke garis finish memakai pace simulasi yang dipilih.
  void _skipToFinish() {
    if (_isFinishing) return;
    if (_location.isPaused) {
      _location.resume();
      _sensor.resume();
    }
    if (!_location.isSimulating) {
      _location.enableSimulation();
      _sensor.enableSimulation();
    }
    final skipped = _location.skipSimulationTo(widget.event.distanceKm.toDouble());
    _sensor.addSimulatedSteps((skipped * 1.4).round());
    _finishRace(targetReached: true);
  }

  Widget _simChip(DuoColorPalette palette, String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.primaryBlue : palette.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? palette.primaryBlue : palette.surfaceBorder, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : palette.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _simInfoRow(DuoColorPalette palette, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: palette.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _showSimulationSheet() {
    const speeds = [1, 5, 10, 30];
    const paces = [240, 300, 360, 450, 540]; // detik per KM
    final targetKm = widget.event.distanceKm.toDouble();
    final palette = DuoColors.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: AnimatedBuilder(
          animation: _location,
          builder: (context, child) {
            final pace = _location.simPaceSecPerKm;
            final remainingKm =
                (targetKm - _location.totalDistanceKm).clamp(0.0, targetKm).toDouble();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: DuoColors.streakGold, size: 24),
                      const SizedBox(width: 8),
                      Text('Kontrol Simulasi Lari',
                          style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 17)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Estimasi berdasarkan pace yang dipilih
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.surfaceBorder, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        _simInfoRow(palette, 'Target', '${widget.event.distanceKm} KM'),
                        _simInfoRow(palette, 'Kecepatan rata-rata',
                            '${(3600 / pace).toStringAsFixed(1)} km/h'),
                        _simInfoRow(
                          palette,
                          'Estimasi total waktu',
                          RunFormat.duration((targetKm * pace).round()),
                          valueColor: palette.primaryBlue,
                        ),
                        _simInfoRow(
                          palette,
                          'Sisa waktu',
                          RunFormat.duration((remainingKm * pace).round()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('PACE SIMULASI',
                      style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: paces
                        .map((p) => _simChip(
                              palette,
                              '${RunFormat.pace(p)} /km',
                              pace == p,
                              () => _location.setSimulationPace(p),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),

                  Text('KECEPATAN WAKTU',
                      style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: speeds
                        .map((s) => _simChip(
                              palette,
                              '${s}x',
                              _location.simSpeed == s,
                              () {
                                _location.setSimulationSpeed(s);
                                _sensor.setSimulationSpeed(s);
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  DuoButton(
                    text: 'LOMPAT KE FINISH',
                    height: 48,
                    backgroundColor: DuoColors.streakGold,
                    shadowColor: DuoColors.streakGoldShadow,
                    textColor: Colors.black,
                    icon: const Icon(Icons.fast_forward_rounded, color: Colors.black, size: 20),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _skipToFinish();
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
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
        backgroundColor: palette.background,
        appBar: AppBar(
          iconTheme: IconThemeData(color: palette.textPrimary),
          backgroundColor: palette.surface,
          elevation: 0,
          shape: Border(bottom: BorderSide(color: palette.surfaceBorder, width: 2)),
          title: Text(
            widget.event.title.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontSize: 18,
              color: palette.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.smart_toy_rounded, color: palette.primaryBlue),
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
            Expanded(flex: 5, child: _buildMapArea(palette, location, sensor)),
            _buildHud(palette, location, sensor, progressRatio, elapsedSec),
          ],
        ),
      ),
    );
  }

  Widget _buildMapArea(DuoColorPalette palette, LocationTrackingService location, MotionSensorService sensor) {
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
                      builder: (context, deg, child) => Transform.rotate(
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
              Flexible(child: _buildGpsChip(palette, location)),
              if (_showSimulationTools) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    if (!location.isSimulating) {
                      location.enableSimulation();
                      sensor.enableSimulation();
                    } else {
                      _showSimulationSheet();
                    }
                  },
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: Text(location.isSimulating
                      ? 'Simulasi ${location.simSpeed}x'
                      : 'Simulasi Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        location.isSimulating ? DuoColors.streakGold : palette.surface,
                    foregroundColor: location.isSimulating ? Colors.black : palette.textPrimary,
                    side: BorderSide(color: palette.surfaceBorder, width: 1.5),
                    elevation: 2,
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
              backgroundColor: palette.surface,
              foregroundColor: palette.primaryBlue,
              shape: CircleBorder(side: BorderSide(color: palette.surfaceBorder, width: 1.5)),
              elevation: 2,
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

  Widget _buildGpsChip(DuoColorPalette palette, LocationTrackingService location) {
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
        color: palette.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.surfaceBorder, width: 1.5),
        boxShadow: [
          BoxShadow(color: palette.surfaceShadow, offset: const Offset(0, 2)),
        ],
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
                style: TextStyle(
                    color: palette.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHud(DuoColorPalette palette, LocationTrackingService location, MotionSensorService sensor,
      double progressRatio, int elapsedSec) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: palette.surfaceBorder, width: 2)),
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
                  style: TextStyle(
                      color: palette.primaryBlue, fontWeight: FontWeight.w900, fontSize: 18),
                ),
                Text(
                  '${(progressRatio * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: palette.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressRatio,
                backgroundColor: palette.surfaceBorder,
                valueColor: AlwaysStoppedAnimation(palette.primaryBlue),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetricCard(palette, Icons.timer_rounded, 'WAKTU', RunFormat.duration(elapsedSec)),
                const SizedBox(width: 6),
                _buildMetricCard(palette, Icons.speed_rounded, 'PACE',
                    RunFormat.paceFromSpeed(location.currentSpeedKmh)),
                const SizedBox(width: 6),
                _buildMetricCard(palette, Icons.bolt_rounded, 'KM/H',
                    location.currentSpeedKmh.toStringAsFixed(1)),
                const SizedBox(width: 6),
                _buildMetricCard(palette, Icons.directions_walk_rounded, 'STEPS', '${sensor.stepCount}'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.surfaceBorder, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.sensors_rounded, color: DuoColors.streakGold, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Sensor Gerak: ${sensor.motionState}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Text('Mag: ${sensor.currentMagnitude.toStringAsFixed(2)} m/s²',
                      style: TextStyle(
                          color: palette.textMuted, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DuoButton(
                    text: location.isPaused ? 'LANJUT' : 'PAUSE',
                    height: 48,
                    backgroundColor: palette.secondaryButton,
                    shadowColor: palette.secondaryButtonShadow,
                    textColor: palette.textPrimary,
                    icon: Icon(location.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: palette.textPrimary, size: 20),
                    onPressed: _togglePause,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: DuoButton(
                    text: 'SELESAI',
                    height: 48,
                    backgroundColor: DuoColors.heartRed,
                    shadowColor: DuoColors.heartRedShadow,
                    textColor: Colors.white,
                    icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 20),
                    onPressed: _confirmStop,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(DuoColorPalette palette, IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.surfaceBorder, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: palette.primaryBlue, size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: palette.textMuted, fontSize: 10, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

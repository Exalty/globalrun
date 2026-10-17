import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../models/race_event.dart';
import '../models/blockchain_record.dart';
import '../services/sensor_service.dart';
import '../services/location_service.dart';
import '../services/blockchain_service.dart';
import '../services/ai_coach_service.dart';
import 'ai_coach_screen.dart';
import 'blockchain_certificate_screen.dart';

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
  Timer? _stopwatchTimer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _startRaceSession();
  }

  void _startRaceSession() {
    final sensor = Provider.of<MotionSensorService>(context, listen: false);
    final location = Provider.of<LocationTrackingService>(context, listen: false);

    sensor.resetSteps();
    location.resetTrack();

    sensor.startTracking();
    location.startTracking();

    _isRunning = true;
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRunning) {
        setState(() {
          _elapsedSeconds++;
        });

        // Check race completion
        if (location.totalDistanceKm >= widget.event.distanceKm && !_isFinished) {
          _completeRace();
        }
      }
    });
  }

  void _completeRace() async {
    _isRunning = false;
    _isFinished = true;
    _stopwatchTimer?.cancel();

    final sensor = Provider.of<MotionSensorService>(context, listen: false);
    final location = Provider.of<LocationTrackingService>(context, listen: false);

    final avgSpeed = _elapsedSeconds > 0 ? (location.totalDistanceKm / (_elapsedSeconds / 3600.0)) : 0.0;

    // Mint digital medal to blockchain ledger
    final mintedBlock = await widget.blockchainService.mintMedalBlock(
      raceId: widget.event.id,
      raceTitle: widget.event.title,
      participantName: 'Garuda Runner (User)',
      distanceKm: location.totalDistanceKm,
      durationSeconds: _elapsedSeconds,
      stepsCount: sensor.stepCount,
      avgSpeedKmh: avgSpeed,
    );

    if (!mounted) return;

    _showFinishDialog(mintedBlock);
  }

  void _showFinishDialog(Block block) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 30),
              SizedBox(width: 10),
              Text('FINISH! Selamat!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Anda telah menyelesaikan ${widget.event.title}!', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              _buildDialogRow('Jarak Selesai', '${block.distanceKm.toStringAsFixed(2)} KM'),
              _buildDialogRow('Total Langkah', '${block.stepsCount} steps'),
              _buildDialogRow('Waktu', '${(_elapsedSeconds / 60).toStringAsFixed(1)} menit'),
              _buildDialogRow('Speed Rata-rata', '${block.avgSpeedKmh.toStringAsFixed(1)} km/h'),
              const Divider(color: Colors.white24, height: 20),
              const Text('🔗 Blockchain Minting Success:', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text('Blok #${block.index} Hash: ${block.hash.substring(0, 24)}...', style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlockchainCertificateScreen(
                      blockchainService: widget.blockchainService,
                      highlightBlock: block,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              child: const Text('Buka Medali NFT'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sensor = Provider.of<MotionSensorService>(context);
    final location = Provider.of<LocationTrackingService>(context);

    final progressRatio = (location.totalDistanceKm / widget.event.distanceKm).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(widget.event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    durationSeconds: _elapsedSeconds,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // GPS Map Route Viewer (LBS)
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: location.currentLocation,
                    initialZoom: 16.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.runcompete.virtualrace',
                    ),
                    if (location.routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: location.routePoints,
                            strokeWidth: 5.0,
                            color: Colors.cyanAccent,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: location.currentLocation,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 3),
                              ],
                            ),
                            child: const Icon(Icons.navigation_rounded, color: Colors.black87, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Top Mode Indicator & Simulation Toggle
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(
                              location.isSimulating ? 'LBS Mock Simulator GPS' : 'Live Hardware GPS',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Allow user to trigger simulator for quick testing
                          if (!location.isSimulating) {
                            location.startTracking(simulationMode: true);
                            sensor.startTracking(simulationMode: true);
                          }
                        },
                        icon: const Icon(Icons.bolt_rounded, size: 16),
                        label: Text(location.isSimulating ? 'Simulating' : 'Simulasi Test'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: location.isSimulating ? Colors.amber : const Color(0xFF1E293B),
                          foregroundColor: location.isSimulating ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Race Telemetry & Accelerometer Pedometer HUD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Race Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${location.totalDistanceKm.toStringAsFixed(2)} / ${widget.event.distanceKm} KM',
                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '${(progressRatio * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
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

                // Telemetry Cards: Duration, Speed, Steps (Accelerometer), Motion
                Row(
                  children: [
                    _buildMetricCard(Icons.timer_rounded, 'WAKTU', _formatDuration(_elapsedSeconds)),
                    const SizedBox(width: 8),
                    _buildMetricCard(Icons.speed_rounded, 'SPEED', '${location.currentSpeedKmh.toStringAsFixed(1)} km/h'),
                    const SizedBox(width: 8),
                    _buildMetricCard(Icons.directions_walk_rounded, 'STEPS', '${sensor.stepCount}'),
                  ],
                ),
                const SizedBox(height: 12),

                // Accelerometer Status Banner
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
                      Row(
                        children: [
                          const Icon(Icons.sensors_rounded, color: Colors.amberAccent, size: 18),
                          const SizedBox(width: 8),
                          Text('Sensor Gerak: ${sensor.motionState}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      Text(
                        'Mag: ${sensor.currentMagnitude.toStringAsFixed(2)} m/s²',
                        style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Control Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _completeRace,
                        icon: const Icon(Icons.flag_rounded),
                        label: const Text('Finish Race & Mint NFT'),
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
        ],
      ),
    );
  }

  Widget _buildMetricCard(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

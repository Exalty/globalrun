import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════════
//  MODEL & ENGINE (logika game, tanpa UI)
// ════════════════════════════════════════════════════════════════════

enum GameStatus { ready, playing, paused, over }

enum ControlMode { touch, tilt }

enum ObstacleKind { cone, barrier, car, bin, cyclist }

/// Semua ukuran/posisi memakai satuan "u" = lebar jalan.
/// Sumbu x: -0.5 (tepi kiri jalan) sampai +0.5 (tepi kanan jalan).
class Obstacle {
  final ObstacleKind kind;
  double x;
  double y;
  double vx; // gerak menyamping (khusus pesepeda)
  final double w;
  final double h;
  final double speedFactor; // 1.0 = diam di jalan, >1 mendekat lebih cepat
  final Color color;

  Obstacle({
    required this.kind,
    required this.x,
    required this.w,
    required this.h,
    this.y = -1,
    this.vx = 0,
    this.speedFactor = 1.0,
    this.color = const Color(0xFF9CA3AF),
  });

  Rect get hitbox =>
      Rect.fromCenter(center: Offset(x, y), width: w * 0.85, height: h * 0.85);
}

class GameEngine extends ChangeNotifier {
  static const double roadFrac = 0.64; // lebar jalan terhadap lebar layar
  static const double runnerW = 0.10;
  static const double runnerH = 0.17;
  static const double maxX = 0.5 - runnerW / 2 - 0.01;
  static const double baseSpeed = 1.15; // u per detik
  static const double maxSpeed = 2.7;

  final Random _rnd = Random();

  GameStatus status = GameStatus.ready;
  bool tiltMode = false;
  double tiltTarget = 0;

  double viewH = 2.0;
  double runnerX = 0;
  double runnerY = 1.6;
  double distance = 0;
  double time = 0;
  double speed = baseSpeed;
  int score = 0;

  double _distSinceSpawn = 0;
  double _nextGap = 1.3;
  final List<Obstacle> obstacles = [];

  static const _carColors = [
    Color(0xFFE5E7EB),
    Color(0xFF9CA3AF),
    Color(0xFFB91C1C),
    Color(0xFFFACC15),
    Color(0xFF15803D),
  ];
  static const _bikerColors = [
    Color(0xFFEA580C),
    Color(0xFF0D9488),
    Color(0xFFDB2777),
  ];

  /// Dipanggil dari LayoutBuilder (tanpa notifyListeners).
  void configure(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final roadW = size.width * roadFrac;
    viewH = size.height / roadW;
    runnerY = viewH * 0.80;
  }

  void start() {
    obstacles.clear();
    runnerX = 0;
    tiltTarget = 0;
    distance = 0;
    time = 0;
    speed = baseSpeed;
    score = 0;
    _distSinceSpawn = 0;
    _nextGap = 1.3;
    status = GameStatus.playing;
    notifyListeners();
  }

  void pause() {
    if (status == GameStatus.playing) {
      status = GameStatus.paused;
      notifyListeners();
    }
  }

  void resume() {
    if (status == GameStatus.paused) {
      status = GameStatus.playing;
      notifyListeners();
    }
  }

  /// Geser jari: du dalam satuan lebar jalan.
  void steerBy(double du) {
    runnerX = (runnerX + du).clamp(-maxX, maxX).toDouble();
  }

  /// Kemiringan HP: v dalam rentang -1..1.
  void setTilt(double v) {
    tiltTarget = v.clamp(-1.0, 1.0).toDouble() * maxX;
  }

  void update(double dt) {
    if (status != GameStatus.playing) return;

    time += dt;
    speed = min(maxSpeed, baseSpeed + distance * 0.012);
    final dy = speed * dt;
    distance += dy;
    score = (distance * 8).floor();

    if (tiltMode) {
      runnerX += (tiltTarget - runnerX) * min(1.0, dt * 12);
    }

    for (final o in obstacles) {
      o.y += dy * o.speedFactor;
      if (o.vx != 0) {
        o.x += o.vx * dt;
        if (o.x - o.w / 2 < -0.5 || o.x + o.w / 2 > 0.5) {
          o.vx = -o.vx;
          o.x = o.x.clamp(-0.5 + o.w / 2, 0.5 - o.w / 2).toDouble();
        }
      }
    }
    obstacles.removeWhere((o) => o.y - o.h / 2 > viewH + 0.2);

    _distSinceSpawn += dy;
    if (_distSinceSpawn >= _nextGap) {
      _spawn();
      _distSinceSpawn = 0;
      final t = min(1.0, distance / 120);
      _nextGap = (1.6 - 0.75 * t) + _rnd.nextDouble() * 0.5;
    }

    final r = Rect.fromCenter(
        center: Offset(runnerX, runnerY),
        width: runnerW * 0.8,
        height: runnerH * 0.8);
    for (final o in obstacles) {
      if (r.overlaps(o.hitbox)) {
        status = GameStatus.over;
        break;
      }
    }
    notifyListeners();
  }

  // ─── Spawn rintangan ──────────────────────────────────────────────
  Obstacle _make(ObstacleKind k, double x) {
    Obstacle o;
    switch (k) {
      case ObstacleKind.cone:
        o = Obstacle(kind: k, x: x, w: 0.11, h: 0.11);
        break;
      case ObstacleKind.barrier:
        o = Obstacle(kind: k, x: x, w: 0.40, h: 0.10);
        break;
      case ObstacleKind.car:
        o = Obstacle(
            kind: k,
            x: x,
            w: 0.24,
            h: 0.42,
            speedFactor: 1.45,
            color: _carColors[_rnd.nextInt(_carColors.length)]);
        break;
      case ObstacleKind.bin:
        o = Obstacle(kind: k, x: x, w: 0.13, h: 0.15);
        break;
      case ObstacleKind.cyclist:
        o = Obstacle(
            kind: k,
            x: x,
            w: 0.12,
            h: 0.30,
            speedFactor: 0.65,
            vx: (_rnd.nextBool() ? 1 : -1) * (0.18 + _rnd.nextDouble() * 0.15),
            color: _bikerColors[_rnd.nextInt(_bikerColors.length)]);
        break;
    }
    o.y = -o.h / 2 - 0.05;
    return o;
  }

  double _randX(double w) =>
      (-0.5 + w / 2) + _rnd.nextDouble() * (1.0 - w);

  void _spawn() {
    if (_rnd.nextDouble() < 0.25) {
      // Dua rintangan kecil dengan celah aman di antaranya
      const small = [ObstacleKind.cone, ObstacleKind.bin];
      final a = _make(small[_rnd.nextInt(small.length)], 0);
      final b = _make(small[_rnd.nextInt(small.length)], 0);
      final gapC = (_rnd.nextDouble() - 0.5) * 0.5;
      const gapHalf = 0.15;
      a.x = max(-0.5 + a.w / 2,
          gapC - gapHalf - a.w / 2 - _rnd.nextDouble() * 0.08);
      b.x = min(0.5 - b.w / 2,
          gapC + gapHalf + b.w / 2 + _rnd.nextDouble() * 0.08);
      obstacles.addAll([a, b]);
      return;
    }

    final roll = _rnd.nextDouble();
    ObstacleKind k;
    if (roll < 0.25) {
      k = ObstacleKind.cone;
    } else if (roll < 0.45) {
      k = ObstacleKind.barrier;
    } else if (roll < 0.65) {
      k = ObstacleKind.car;
    } else if (roll < 0.85) {
      k = ObstacleKind.bin;
    } else {
      k = ObstacleKind.cyclist;
    }
    final probe = _make(k, 0);
    probe.x = _randX(probe.w);
    obstacles.add(probe);
  }
}

// ════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════

class MiniGameScreen extends StatefulWidget {
  const MiniGameScreen({super.key});

  @override
  State<MiniGameScreen> createState() => _MiniGameScreenState();
}

class _MiniGameScreenState extends State<MiniGameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _prefHigh = 'minigame_highscore';
  static const _prefMode = 'minigame_control_mode';
  static const _prefInvert = 'minigame_invert_tilt';

  static const _ink = Color(0xFF292524);
  static const _amber = Color(0xFFF59E0B);

  final GameEngine engine = GameEngine();
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _sensorCheck;
  bool _sensorSeen = false;

  SharedPreferences? _prefs;
  ControlMode _mode = ControlMode.touch;
  bool _invertTilt = false;
  int _highScore = 0;
  bool _newRecord = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _ticker = createTicker(_onTick);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      if (!mounted) return;
      setState(() {
        _highScore = prefs.getInt(_prefHigh) ?? 0;
        final m = prefs.getInt(_prefMode) ?? 0;
        _mode = m == 1 ? ControlMode.tilt : ControlMode.touch;
        _invertTilt = prefs.getBool(_prefInvert) ?? false;
      });
    } catch (_) {}
  }

  // ─── Loop game ────────────────────────────────────────────────────
  void _onTick(Duration elapsed) {
    final dt =
        ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = elapsed;
    if (engine.status != GameStatus.playing) return;

    engine.update(dt);
    if (engine.status == GameStatus.over) _handleGameOver();
  }

  void _startTicker() {
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _startGame() {
    _newRecord = false;
    _notice = null;
    engine.tiltMode = _mode == ControlMode.tilt;
    engine.start();
    if (_mode == ControlMode.tilt) {
      _startSensor();
    } else {
      _stopSensor();
    }
    _startTicker();
    setState(() {});
  }

  void _pause() {
    if (engine.status != GameStatus.playing) return;
    engine.pause();
    _ticker.stop();
    _stopSensor();
    setState(() {});
  }

  void _resume() {
    if (engine.status != GameStatus.paused) return;
    engine.resume();
    if (_mode == ControlMode.tilt) _startSensor();
    _startTicker();
    setState(() {});
  }

  void _handleGameOver() {
    _ticker.stop();
    _stopSensor();
    HapticFeedback.mediumImpact();
    if (engine.score > _highScore) {
      _highScore = engine.score;
      _newRecord = true;
      _prefs?.setInt(_prefHigh, _highScore);
    }
    setState(() {});
  }

  /// Simpan skor jika melampaui rekor (dipakai saat keluar/dispose).
  void _commitScore() {
    if (engine.score > _highScore) {
      _highScore = engine.score;
      _prefs?.setInt(_prefHigh, _highScore);
    }
  }

  // ─── Sensor kemiringan ────────────────────────────────────────────
  void _startSensor() {
    _accelSub?.cancel();
    _sensorCheck?.cancel();
    _sensorSeen = false;

    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (ev) {
          _sensorSeen = true;
          // Android: miring ke kanan -> x negatif. Tombol "balik arah" tersedia.
          final raw = (_invertTilt ? ev.x : -ev.x) / 4.5;
          engine.setTilt(raw);
        },
        onError: (_) => _fallbackToTouch(),
        cancelOnError: false,
      );
    } catch (_) {
      _fallbackToTouch();
      return;
    }

    _sensorCheck = Timer(const Duration(milliseconds: 1500), () {
      if (!_sensorSeen && mounted) _fallbackToTouch();
    });
  }

  void _stopSensor() {
    _accelSub?.cancel();
    _accelSub = null;
    _sensorCheck?.cancel();
    _sensorCheck = null;
  }

  void _fallbackToTouch() {
    if (!mounted) return;
    _stopSensor();
    engine.tiltMode = false;
    setState(() {
      _mode = ControlMode.touch;
      _notice = 'Sensor tidak tersedia di perangkat ini. '
          'Kontrol dialihkan ke geser jari.';
    });
  }

  void _setMode(ControlMode m) {
    setState(() => _mode = m);
    _prefs?.setInt(_prefMode, m == ControlMode.tilt ? 1 : 0);
  }

  void _setInvert(bool v) {
    setState(() => _invertTilt = v);
    _prefs?.setBool(_prefInvert, v);
  }

  // ─── Keluar ───────────────────────────────────────────────────────
  Future<void> _confirmExit() async {
    if (engine.status == GameStatus.playing) _pause();
    if (engine.status == GameStatus.paused) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Keluar dari game?'),
          content: const Text('Permainan yang sedang berjalan akan diakhiri.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Keluar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    _commitScore();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commitScore();
    _stopSensor();
    _ticker.dispose();
    engine.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════
  //  UI
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD6D3D1),
      body: Column(
        children: [
          _buildHud(),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              engine.configure(size);
              final roadW = size.width * GameEngine.roadFrac;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  if (_mode == ControlMode.touch &&
                      engine.status == GameStatus.playing) {
                    engine.steerBy(d.delta.dx / roadW * 1.25);
                  }
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: _CityPainter(engine)),
                      ),
                    ),
                    if (_notice != null)
                      Positioned(
                        top: 10,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _amber),
                          ),
                          child: Text(_notice!,
                              style: const TextStyle(
                                  color: _ink, fontSize: 12.5)),
                        ),
                      ),
                    if (engine.status == GameStatus.ready) _buildReadyOverlay(),
                    if (engine.status == GameStatus.paused)
                      _buildPausedOverlay(),
                    if (engine.status == GameStatus.over) _buildOverOverlay(),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHud() {
    final canPause = engine.status == GameStatus.playing ||
        engine.status == GameStatus.paused;
    return Container(
      color: const Color(0xFFF5F5F4),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: _ink),
                tooltip: 'Keluar',
                onPressed: _confirmExit,
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: engine,
                  builder: (_, __) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _stat(Icons.directions_run_rounded, 'Skor',
                          '${engine.score}'),
                      _stat(Icons.emoji_events_rounded, 'Rekor',
                          '${max(_highScore, engine.score)}'),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  engine.status == GameStatus.paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  color: canPause ? _ink : Colors.black26,
                ),
                tooltip: engine.status == GameStatus.paused
                    ? 'Lanjutkan'
                    : 'Jeda',
                onPressed: !canPause
                    ? null
                    : (engine.status == GameStatus.paused ? _resume : _pause),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _amber, size: 22),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(color: Colors.black54, fontSize: 14)),
        Text(value,
            style: const TextStyle(
                color: _ink, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── Overlay ──────────────────────────────────────────────────────
  Widget _overlay({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.45),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _amber, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _ink, fontSize: 24, fontWeight: FontWeight.bold)),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 14)),
                ],
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _amber,
          foregroundColor: _ink,
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        child: Text(label, style: const TextStyle(color: Colors.black54)),
      ),
    );
  }

  Widget _modeSelector() {
    return Column(
      children: [
        const Text('Cara bermain',
            style: TextStyle(
                color: _ink, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('👆 Geser Jari'),
              selected: _mode == ControlMode.touch,
              selectedColor: _amber,
              onSelected: (_) => _setMode(ControlMode.touch),
            ),
            ChoiceChip(
              label: const Text('📱 Miringkan HP'),
              selected: _mode == ControlMode.tilt,
              selectedColor: _amber,
              onSelected: (_) => _setMode(ControlMode.tilt),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _mode == ControlMode.touch
              ? 'Geser jari ke kiri/kanan untuk berbelok.'
              : 'Miringkan HP ke kiri/kanan untuk berbelok.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
        if (_mode == ControlMode.tilt)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Balik arah miring',
                  style: TextStyle(color: Colors.black54, fontSize: 12.5)),
              Switch(
                value: _invertTilt,
                activeColor: _amber,
                onChanged: _setInvert,
              ),
            ],
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildReadyOverlay() {
    return _overlay(
      title: '🏙️ City Dash',
      subtitle: 'Lari terus dan hindari rintangan di jalanan kota!',
      children: [
        _modeSelector(),
        _primaryButton('Mulai Lari', Icons.play_arrow_rounded, _startGame),
        _secondaryButton('Keluar', _confirmExit),
      ],
    );
  }

  Widget _buildPausedOverlay() {
    return _overlay(
      title: '⏸ Jeda',
      subtitle: 'Skor saat ini: ${engine.score}',
      children: [
        _primaryButton('Lanjutkan', Icons.play_arrow_rounded, _resume),
        const SizedBox(height: 4),
        _secondaryButton('Ulangi dari awal', _startGame),
        _secondaryButton('Keluar', _confirmExit),
      ],
    );
  }

  Widget _buildOverOverlay() {
    return _overlay(
      title: '💥 Tabrakan!',
      subtitle: _newRecord
          ? '🎉 Rekor baru! Skor: ${engine.score}'
          : 'Skor: ${engine.score}   •   Rekor: $_highScore',
      children: [
        _modeSelector(),
        _primaryButton('Main Lagi', Icons.replay_rounded, _startGame),
        _secondaryButton('Keluar', _confirmExit),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PAINTER (tampilan kota, pandangan dari atas)
// ════════════════════════════════════════════════════════════════════

class _CityPainter extends CustomPainter {
  final GameEngine e;
  _CityPainter(this.e) : super(repaint: e);

  static const _sidewalk = Color(0xFFD6D3D1);
  static const _curb = Color(0xFFA8A29E);
  static const _asphalt = Color(0xFF57534E);
  static const _white = Color(0xFFF5F5F4);
  static const _roofs = [
    Color(0xFFB4533C),
    Color(0xFF8795A8),
    Color(0xFFD4A762),
    Color(0xFF7D8B73),
    Color(0xFFA39382),
    Color(0xFFC77D5A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final roadW = w * GameEngine.roadFrac;
    final roadL = (w - roadW) / 2;
    final roadR = roadL + roadW;
    final scroll = e.distance * roadW;
    final p = Paint();

    // Trotoar (dasar)
    p.color = _sidewalk;
    canvas.drawRect(Offset.zero & size, p);

    _drawBuildings(canvas, w, h, roadL, roadR, roadW, scroll);
    _drawTrees(canvas, h, roadL, roadR, roadW, scroll);

    // Jalan + bahu
    p.color = _curb;
    canvas.drawRect(Rect.fromLTRB(roadL - 5, 0, roadR + 5, h), p);
    p.color = _asphalt;
    canvas.drawRect(Rect.fromLTRB(roadL, 0, roadR, h), p);

    _drawRoadMarks(canvas, h, roadL, roadR, roadW, scroll);

    for (final o in e.obstacles) {
      _drawObstacle(canvas, o, roadL, roadW);
    }
    _drawRunner(canvas, roadL, roadW);
  }

  void _drawBuildings(Canvas c, double w, double h, double roadL,
      double roadR, double roadW, double scroll) {
    final sw = roadL * 0.4; // lebar trotoar
    final bw = roadL - sw; // lebar gedung
    if (bw <= 0) return;
    final period = roadW * 0.85;
    final first = (scroll / period).floor() - 1;
    final last = ((scroll + h) / period).ceil() + 1;
    final p = Paint();

    for (int i = first; i <= last; i++) {
      final bottom = h - (i * period - scroll);
      final bh = period * 0.88;
      for (int side = 0; side < 2; side++) {
        final x0 = side == 0 ? 0.0 : roadR + sw;
        final rect = Rect.fromLTWH(x0, bottom - bh, bw, bh);
        final idx = (((i * 5 + side * 3) % _roofs.length) + _roofs.length) %
            _roofs.length;

        p.color = _roofs[idx];
        c.drawRect(rect, p);
        p.color = Colors.black.withOpacity(0.14);
        c.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 3), p);
        c.drawRect(Rect.fromLTWH(rect.left, rect.bottom - 3, rect.width, 3), p);

        // Detail atap (unit AC / kotak atap)
        final k = ((i * 13 + side * 7) % 5) / 5.0;
        p.color = Colors.white.withOpacity(0.28);
        c.drawRect(
            Rect.fromLTWH(rect.left + bw * (0.12 + 0.3 * k),
                rect.top + bh * 0.22, bw * 0.28, bh * 0.2),
            p);
        c.drawRect(
            Rect.fromLTWH(rect.left + bw * (0.55 - 0.25 * k),
                rect.top + bh * 0.6, bw * 0.22, bh * 0.16),
            p);
      }
    }
  }

  void _drawTrees(Canvas c, double h, double roadL, double roadR,
      double roadW, double scroll) {
    final sw = roadL * 0.4;
    final period = roadW * 0.7;
    final first = (scroll / period).floor() - 1;
    final last = ((scroll + h) / period).ceil() + 1;
    final p = Paint();

    for (int i = first; i <= last; i++) {
      final y = h - (i * period - scroll);
      final cx = i.isEven ? roadL - sw / 2 : roadR + sw / 2;
      final r = sw * 0.38;
      p.color = Colors.black.withOpacity(0.15);
      c.drawCircle(Offset(cx + 2, y + 3), r, p);
      p.color = const Color(0xFF3F7D3A);
      c.drawCircle(Offset(cx, y), r, p);
      p.color = const Color(0xFF5B9A4F);
      c.drawCircle(Offset(cx - r * 0.25, y - r * 0.25), r * 0.55, p);
    }
  }

  void _drawRoadMarks(Canvas c, double h, double roadL, double roadR,
      double roadW, double scroll) {
    final p = Paint()..color = _white;

    // Garis tepi
    c.drawRect(Rect.fromLTWH(roadL + 4, 0, 3, h), p);
    c.drawRect(Rect.fromLTWH(roadR - 7, 0, 3, h), p);

    // Garis putus pembatas lajur
    final period = roadW * 0.34;
    final dash = roadW * 0.17;
    final first = (scroll / period).floor() - 1;
    final last = ((scroll + h) / period).ceil() + 1;
    for (final dx in [-roadW / 6, roadW / 6]) {
      final x = roadL + roadW / 2 + dx;
      for (int j = first; j <= last; j++) {
        final bottom = h - (j * period - scroll);
        c.drawRect(Rect.fromLTWH(x - 2, bottom - dash, 4, dash), p);
      }
    }

    // Zebra cross
    final cw = roadW * 9;
    final cFirst = (scroll / cw).floor() - 1;
    final cLast = ((scroll + h) / cw).ceil() + 1;
    final zh = roadW * 0.26;
    p.color = _white.withOpacity(0.85);
    for (int k = cFirst; k <= cLast; k++) {
      if (k <= 0) continue;
      final bottom = h - (k * cw - scroll);
      for (int s = 0; s < 7; s++) {
        final x = roadL + roadW * 0.07 + s * roadW * 0.13;
        c.drawRect(Rect.fromLTWH(x, bottom - zh, roadW * 0.07, zh), p);
      }
    }
  }

  // ─── Rintangan ────────────────────────────────────────────────────
  void _drawObstacle(Canvas c, Obstacle o, double roadL, double roadW) {
    final cx = roadL + (o.x + 0.5) * roadW;
    final cy = o.y * roadW;
    final w = o.w * roadW;
    final h = o.h * roadW;
    final p = Paint();

    // Bayangan
    p.color = Colors.black.withOpacity(0.18);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx + w * 0.08, cy + h * 0.12),
            width: w * 1.05,
            height: h),
        p);

    switch (o.kind) {
      case ObstacleKind.cone:
        p.color = const Color(0xFFC2410C);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(cx - w / 2, cy + h * 0.22, w, h * 0.28),
                const Radius.circular(3)),
            p);
        p.color = const Color(0xFFEA580C);
        c.drawPath(
            Path()
              ..moveTo(cx, cy - h / 2)
              ..lineTo(cx + w * 0.38, cy + h * 0.28)
              ..lineTo(cx - w * 0.38, cy + h * 0.28)
              ..close(),
            p);
        p.color = Colors.white;
        c.drawRect(
            Rect.fromLTWH(cx - w * 0.2, cy - h * 0.02, w * 0.4, h * 0.12), p);
        break;

      case ObstacleKind.barrier:
        final r = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
        final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
        p.color = const Color(0xFF52525B);
        c.drawRect(Rect.fromLTWH(r.left + w * 0.1, r.bottom, w * 0.06, h * 0.3), p);
        c.drawRect(Rect.fromLTWH(r.right - w * 0.16, r.bottom, w * 0.06, h * 0.3), p);
        p.color = Colors.white;
        c.drawRRect(rr, p);
        c.save();
        c.clipRRect(rr);
        p.color = const Color(0xFFDC2626);
        const n = 6;
        for (int s = 0; s < n; s += 2) {
          c.drawRect(Rect.fromLTWH(r.left + s * w / n, r.top, w / n, h), p);
        }
        c.restore();
        break;

      case ObstacleKind.car:
        p.color = const Color(0xFF18181B);
        for (final dx in [-w / 2 - 2, w / 2 - 2]) {
          c.drawRect(Rect.fromLTWH(cx + dx, cy - h * 0.34, 4, h * 0.2), p);
          c.drawRect(Rect.fromLTWH(cx + dx, cy + h * 0.14, 4, h * 0.2), p);
        }
        p.color = o.color;
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
                const Radius.circular(9)),
            p);
        p.color = Color.lerp(o.color, Colors.white, 0.3)!;
        c.drawRect(
            Rect.fromLTWH(cx - w * 0.34, cy - h * 0.2, w * 0.68, h * 0.22), p);
        p.color = const Color(0xFF1F2937).withOpacity(0.85);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(cx - w * 0.36, cy + h * 0.03, w * 0.72, h * 0.2),
                const Radius.circular(4)),
            p);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(cx - w * 0.3, cy - h * 0.38, w * 0.6, h * 0.14),
                const Radius.circular(4)),
            p);
        p.color = const Color(0xFFFEF08A);
        c.drawCircle(Offset(cx - w * 0.3, cy + h / 2 - 5), 3.5, p);
        c.drawCircle(Offset(cx + w * 0.3, cy + h / 2 - 5), 3.5, p);
        break;

      case ObstacleKind.bin:
        p.color = const Color(0xFF166534);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(cx, cy + h * 0.08),
                    width: w * 0.9,
                    height: h * 0.8),
                const Radius.circular(4)),
            p);
        p.color = Colors.white.withOpacity(0.2);
        for (int s = 1; s < 4; s++) {
          c.drawRect(
              Rect.fromLTWH(cx - w * 0.38 + s * w * 0.19, cy - h * 0.1, 2, h * 0.5),
              p);
        }
        p.color = const Color(0xFF14532D);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(cx, cy - h * 0.32),
                    width: w,
                    height: h * 0.22),
                const Radius.circular(4)),
            p);
        break;

      case ObstacleKind.cyclist:
        p.color = const Color(0xFF27272A);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(cx, cy), width: w * 0.28, height: h),
                const Radius.circular(5)),
            p);
        c.drawRect(Rect.fromLTWH(cx - w * 0.5, cy + h * 0.12, w, 3), p);
        p.color = o.color;
        c.drawOval(
            Rect.fromCenter(
                center: Offset(cx, cy - h * 0.02),
                width: w,
                height: h * 0.3),
            p);
        p.color = const Color(0xFF3F2A1D);
        c.drawCircle(Offset(cx, cy - h * 0.04), w * 0.27, p);
        break;
    }
  }

  // ─── Pelari (tampak dari atas) ────────────────────────────────────
  void _drawRunner(Canvas c, double roadL, double roadW) {
    final cx = roadL + (e.runnerX + 0.5) * roadW;
    final cy = e.runnerY * roadW;
    final w = GameEngine.runnerW * roadW;
    final h = GameEngine.runnerH * roadW;
    final swing = sin(e.time * 16) * h * 0.12;
    final p = Paint();

    p.color = Colors.black.withOpacity(0.2);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 3, cy + 4), width: w * 1.1, height: h * 0.95),
        p);

    // Kaki
    p.color = const Color(0xFF44403C);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - w * 0.3, cy + h * 0.1 + swing, w * 0.24, h * 0.36),
            const Radius.circular(3)),
        p);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + w * 0.06, cy + h * 0.1 - swing, w * 0.24, h * 0.36),
            const Radius.circular(3)),
        p);

    // Lengan
    p.color = const Color(0xFFF2C9A0);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - w * 0.6, cy - h * 0.14 - swing, w * 0.18, h * 0.3),
            const Radius.circular(3)),
        p);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + w * 0.42, cy - h * 0.14 + swing, w * 0.18, h * 0.3),
            const Radius.circular(3)),
        p);

    // Badan
    p.color = const Color(0xFF7C3AED);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - w * 0.4, cy - h * 0.2, w * 0.8, h * 0.42),
            const Radius.circular(6)),
        p);

    // Kepala (rambut, tampak atas)
    p.color = const Color(0xFF3F2A1D);
    c.drawCircle(Offset(cx, cy - h * 0.3), w * 0.3, p);
  }

  @override
  bool shouldRepaint(covariant _CityPainter oldDelegate) => true;
}
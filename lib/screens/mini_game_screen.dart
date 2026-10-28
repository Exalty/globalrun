import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/duo_theme.dart';

// ════════════════════════════════════════════════════════════════════
//  MODEL & ENGINE (logika game)
// ════════════════════════════════════════════════════════════════════

enum GameStatus { ready, playing, paused, over }

enum ControlMode { touch, tilt }

enum ObstacleKind {
  cone,
  barrier,
  car,
  bin,
  cyclist,
  crack, // Jalan retak: melambatkan lari sementara
  energyDrink, // Minuman berenergi: menambah kecepatan lari sementara
}

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
  bool triggered; // Untuk jalan retak agar efek perlambatan hanya terpicu 1 kali

  Obstacle({
    required this.kind,
    required this.x,
    required this.w,
    required this.h,
    this.y = -1,
    this.vx = 0,
    this.speedFactor = 1.0,
    this.color = const Color(0xFF9CA3AF),
    this.triggered = false,
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

  double slowTimer = 0.0; // Timer efek melambat akibat jalan retak
  double boostTimer = 0.0; // Timer efek menambah kecepatan minuman berenergi
  double speedMultiplier = 1.0; // Multiplier kecepatan dengan transisi halus (lerp)
  String? activeEffect; // "MELAMBAT" atau "BOOST"

  double _distSinceSpawn = 0;
  double _nextGap = 1.3;
  final List<Obstacle> obstacles = [];

  static const _carColors = [
    Color(0xFF1CB0F6), // Duolingo Blue
    Color(0xFFFFB800), // Duolingo Gold
    Color(0xFFFF4B4B), // Duolingo Red
    Color(0xFF58CC02), // Duolingo Green
    Color(0xFF38BDF8),
  ];
  static const _bikerColors = [
    Color(0xFFFF9600),
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
    slowTimer = 0.0;
    boostTimer = 0.0;
    speedMultiplier = 1.0;
    activeEffect = null;
    _distSinceSpawn = 0;
    _nextGap = 1.2;
    status = GameStatus.playing;
    notifyListeners();
  }

  void pause() {
    if (status != GameStatus.playing) return;
    status = GameStatus.paused;
    notifyListeners();
  }

  void resume() {
    if (status != GameStatus.paused) return;
    status = GameStatus.playing;
    notifyListeners();
  }

  void steerBy(double delta) {
    if (status != GameStatus.playing) return;
    runnerX = (runnerX + delta).clamp(-maxX, maxX);
    notifyListeners();
  }

  void setTilt(double rawTilt) {
    tiltTarget = rawTilt.clamp(-1.0, 1.0);
  }

  void update(double dt) {
    if (status != GameStatus.playing || dt <= 0) return;

    time += dt;

    // Hitung timer efek
    if (slowTimer > 0) {
      slowTimer = max(0.0, slowTimer - dt);
      if (slowTimer == 0 && activeEffect == 'MELAMBAT') {
        activeEffect = null;
      }
    }
    if (boostTimer > 0) {
      boostTimer = max(0.0, boostTimer - dt);
      if (boostTimer == 0 && activeEffect == 'BOOST') {
        activeEffect = null;
      }
    }

    // Transisi kecepatan yang halus & organik (lerp) tanpa perubahan mendadak / patah
    double targetMultiplier = 1.0;
    if (boostTimer > 0) {
      targetMultiplier = 1.45; // Speed boost halus
    } else if (slowTimer > 0) {
      targetMultiplier = 0.62; // Perlambatan halus
    }
    speedMultiplier += (targetMultiplier - speedMultiplier) * min(1.0, dt * 5.0);

    // Peningkatan kecepatan bertahap
    final currentBase = (baseSpeed + (time / 45.0) * 0.65).clamp(baseSpeed, maxSpeed);
    speed = currentBase * speedMultiplier;

    // Kendali tilt dengan smoothing
    if (tiltMode) {
      final steerSpeed = 2.4 * speed / baseSpeed;
      final targetX = (tiltTarget * maxX).clamp(-maxX, maxX);
      runnerX += (targetX - runnerX) * min(1.0, dt * steerSpeed * 4.0);
    }

    final dy = speed * dt;
    distance += dy;
    score = (distance * 10).floor();

    // Gerakkan rintangan ke bawah (menuju pemain)
    for (int i = obstacles.length - 1; i >= 0; i--) {
      final o = obstacles[i];
      o.y += dy * o.speedFactor;
      o.x += o.vx * dt;

      // Pantulkan pesepeda dari tepi jalan
      if (o.x < -0.5 + o.w / 2 || o.x > 0.5 - o.w / 2) {
        o.vx = -o.vx;
        o.x = o.x.clamp(-0.5 + o.w / 2, 0.5 - o.w / 2);
      }

      if (o.y - o.h / 2 > viewH + 0.3) {
        obstacles.removeAt(i);
      }
    }

    // Spawn rintangan baru
    _distSinceSpawn += dy;
    if (_distSinceSpawn >= _nextGap) {
      _distSinceSpawn = 0;
      _nextGap = max(0.95, 1.5 - (currentBase - baseSpeed) * 0.32) +
          _rnd.nextDouble() * 0.55;
      _spawn();
    }

    // Deteksi tabrakan
    final runnerBox = Rect.fromCenter(
      center: Offset(runnerX, runnerY),
      width: runnerW * 0.76,
      height: runnerH * 0.76,
    );

    for (int i = obstacles.length - 1; i >= 0; i--) {
      final o = obstacles[i];
      if (runnerBox.overlaps(o.hitbox)) {
        if (o.kind == ObstacleKind.crack) {
          // Jalan retak: melambatkan lari secara halus, tidak mematikan
          if (!o.triggered) {
            o.triggered = true;
            slowTimer = 2.5;
            boostTimer = 0.0;
            activeEffect = 'MELAMBAT';
            HapticFeedback.lightImpact();
            notifyListeners();
          }
        } else if (o.kind == ObstacleKind.energyDrink) {
          // Minuman berenergi: menambah kecepatan lari secara mulus, diambil & hilang
          // Animasi jarak kontinu tanpa teleportasi posisi lingkungan
          obstacles.removeAt(i);
          boostTimer = 3.5;
          slowTimer = 0.0;
          activeEffect = 'BOOST';
          HapticFeedback.mediumImpact();
          notifyListeners();
        } else {
          // Rintangan berbahaya: tabrakan fatal
          status = GameStatus.over;
          notifyListeners();
          return;
        }
      }
    }

    notifyListeners();
  }

  Obstacle _make(ObstacleKind k, double x) {
    late Obstacle o;
    switch (k) {
      case ObstacleKind.crack:
        o = Obstacle(kind: k, x: x, w: 0.24, h: 0.15);
        break;
      case ObstacleKind.energyDrink:
        o = Obstacle(kind: k, x: x, w: 0.12, h: 0.16);
        break;
      case ObstacleKind.cone:
        o = Obstacle(kind: k, x: x, w: 0.10, h: 0.12);
        break;
      case ObstacleKind.barrier:
        o = Obstacle(kind: k, x: x, w: 0.36, h: 0.13);
        break;
      case ObstacleKind.car:
        o = Obstacle(
            kind: k,
            x: x,
            w: 0.22,
            h: 0.44,
            speedFactor: 1.35,
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
    if (_rnd.nextDouble() < 0.22) {
      // Dua rintangan kecil / item dengan celah aman di antaranya
      const small = [
        ObstacleKind.cone,
        ObstacleKind.bin,
        ObstacleKind.crack,
        ObstacleKind.energyDrink,
      ];
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
    if (roll < 0.15) {
      k = ObstacleKind.energyDrink; // Minuman berenergi (~15%)
    } else if (roll < 0.32) {
      k = ObstacleKind.crack; // Jalan retak (~17%)
    } else if (roll < 0.48) {
      k = ObstacleKind.cone;
    } else if (roll < 0.64) {
      k = ObstacleKind.barrier;
    } else if (roll < 0.78) {
      k = ObstacleKind.car;
    } else if (roll < 0.90) {
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
//  SCREEN (DUOLINGO LIGHT STYLE)
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

  void _commitScore() {
    if (engine.score > _highScore) {
      _highScore = engine.score;
      _prefs?.setInt(_prefHigh, _highScore);
    }
  }

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
      _notice = 'Sensor miring tidak tersedia. Kendali dialihkan ke geser jari.';
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
  //  UI UTAMA
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (engine.status == GameStatus.playing) {
          _pause();
        }
      },
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'MINI GAME',
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
            _buildHud(palette),
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
                        child: ClipRect(
                          child: RepaintBoundary(
                            child: CustomPaint(painter: _CityPainter(engine)),
                          ),
                        ),
                      ),
                      if (_notice != null)
                        Positioned(
                          top: 12,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: palette.streakGold, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: palette.streakGoldShadow.withOpacity(0.3),
                                  offset: const Offset(0, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Text(
                              _notice!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Notifikasi Efek Kecepatan di Bagian Bawah Tengah Layar
                      Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: engine,
                            builder: (context, _) {
                              if (engine.status != GameStatus.playing) return const SizedBox.shrink();
                              if (engine.boostTimer > 0) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0xFF0369A1),
                                        offset: Offset(0, 3),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'KECEPATAN BERTAMBAH',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                );
                              } else if (engine.slowTimer > 0) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: palette.heartRed,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: palette.heartRedShadow,
                                        offset: const Offset(0, 3),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'JALAN RETAK (MELAMBAT)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      if (engine.status == GameStatus.ready) _buildReadyOverlay(palette),
                      if (engine.status == GameStatus.paused) _buildPausedOverlay(palette),
                      if (engine.status == GameStatus.over) _buildOverOverlay(palette),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// Top HUD Bar (Duolingo Style - Minimal, Bebas Tombol Keluar & Simbol Pause)
  Widget _buildHud(DuoColorPalette palette) {
    final canPause = engine.status == GameStatus.playing ||
        engine.status == GameStatus.paused;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.surfaceBorder, width: 2.5)),
        boxShadow: [
          BoxShadow(
            color: palette.surfaceShadow,
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
            children: [
              // Skor & Rekor
              Expanded(
                child: AnimatedBuilder(
                  animation: engine,
                  builder: (context, _) => Row(
                    children: [
                      DuoChip(
                        label: '${engine.score} M',
                        textColor: palette.primaryBlue,
                        borderColor: palette.primaryBlueShadow,
                        backgroundColor: palette.background,
                      ),
                      const SizedBox(width: 8),
                      DuoChip(
                        label: 'BEST ${max(_highScore, engine.score)}',
                        textColor: palette.streakGold,
                        borderColor: palette.streakGoldShadow,
                        backgroundColor: palette.background,
                      ),
                    ],
                  ),
                ),
              ),
              // Tombol Jeda (Simbol Pause / Play 3D)
              GestureDetector(
                onTap: !canPause
                    ? null
                    : (engine.status == GameStatus.paused ? _resume : _pause),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: canPause ? palette.surface : palette.surfaceBorder.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: canPause ? palette.surfaceBorder : Colors.transparent,
                      width: 2.0,
                    ),
                    boxShadow: canPause
                        ? [
                            BoxShadow(
                              color: palette.surfaceShadow,
                              offset: const Offset(0, 2),
                              blurRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    engine.status == GameStatus.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: canPause ? palette.primaryBlue : palette.textMuted,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  // ─── OVERLAYS ─────────────────────────────────────────────────────

  Widget _overlay({
    required String title,
    String? subtitle,
    required List<Widget> children,
    required DuoColorPalette palette,
  }) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.40),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.surfaceBorder, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: palette.surfaceShadow,
                  offset: const Offset(0, 6),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(
    String label,
    VoidCallback onTap, {
    Color? bgColor,
    Color? shadowColor,
    DuoColorPalette? palette,
  }) {
    final p = palette ?? DuoColors.of(context);
    return DuoButton(
      text: label,
      onPressed: onTap,
      backgroundColor: bgColor ?? p.questGreen,
      shadowColor: shadowColor ?? p.questGreenShadow,
      textColor: Colors.white,
      borderRadius: 14,
      height: 48,
    );
  }

  Widget _modeSelector(DuoColorPalette palette) {
    return Column(
      children: [
        Text(
          'KONTROL BERMAIN',
          style: TextStyle(
            color: palette.textMuted,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildModeChip(
              label: 'GESER JARI',
              isSelected: _mode == ControlMode.touch,
              onTap: () => _setMode(ControlMode.touch),
              palette: palette,
            ),
            const SizedBox(width: 10),
            _buildModeChip(
              label: 'SENSOR MIRING',
              isSelected: _mode == ControlMode.tilt,
              onTap: () => _setMode(ControlMode.tilt),
              palette: palette,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _mode == ControlMode.touch
              ? 'Geser jari ke kiri/kanan untuk berpindah lajur.'
              : 'Miringkan ponsel ke kiri/kanan untuk berbelok.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, fontSize: 11),
        ),
        if (_mode == ControlMode.tilt) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Balik Arah Sensor Miring',
                style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Switch(
                value: _invertTilt,
                activeColor: palette.primaryBlue,
                onChanged: _setInvert,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildModeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required DuoColorPalette palette,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.primaryBlue.withOpacity(palette.isDark ? 0.20 : 0.12)
              : palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? palette.primaryBlue : palette.surfaceBorder,
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? palette.primaryBlueShadow.withOpacity(0.4) : palette.surfaceShadow,
              offset: const Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? palette.primaryBlue : palette.textMuted,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildReadyOverlay(DuoColorPalette palette) {
    return _overlay(
      title: 'City Runner',
      subtitle: 'Lari terus dan hindari rintangan di jalanan kota.',
      palette: palette,
      children: [
        _modeSelector(palette),
        _primaryButton('Mulai Lari', _startGame),
      ],
    );
  }

  Widget _buildPausedOverlay(DuoColorPalette palette) {
    return _overlay(
      title: 'Permainan Dijeda',
      subtitle: 'Skor saat ini: ${engine.score} meter',
      palette: palette,
      children: [
        _primaryButton('Lanjutkan', _resume),
        const SizedBox(height: 8),
        DuoButton(
          text: 'Ulangi Dari Awal',
          onPressed: _startGame,
          backgroundColor: palette.primaryBlue,
          shadowColor: palette.primaryBlueShadow,
          textColor: Colors.white,
          borderRadius: 14,
          height: 48,
        ),
      ],
    );
  }

  Widget _buildOverOverlay(DuoColorPalette palette) {
    return _overlay(
      title: 'Permainan Berakhir',
      palette: palette,
      children: [
        // Kartu Skor Rapi
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.surfaceBorder, width: 1.5),
          ),
          child: Column(
            children: [
              if (_newRecord) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: palette.questGreen.withOpacity(palette.isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.questGreen, width: 1),
                  ),
                  child: Text(
                    'REKOR TERBAIK BARU',
                    style: TextStyle(
                      color: palette.questGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
              Text(
                '${engine.score}',
                style: TextStyle(
                  color: palette.primaryBlue,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'JARAK TEMPUH (METER)',
                style: TextStyle(color: palette.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Rekor Tertinggi: $_highScore m',
                style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        _modeSelector(palette),
        _primaryButton('Main Lagi', _startGame),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PAINTER (TAMPILAN JALAN KOTA DUOLINGO CERAH & VIBRANT)
// ════════════════════════════════════════════════════════════════════

class _CityPainter extends CustomPainter {
  final GameEngine e;
  _CityPainter(this.e) : super(repaint: e);

  // Palet Cerah Duolingo Light
  static const _sidewalk = Color(0xFFE2E8F0); // Trotoar abu-abu muda bersih
  static const _curb = Color(0xFFCBD5E1); // Tepi jalan
  static const _asphalt = Color(0xFF334155); // Aspal slate kontras tinggi
  static const _white = Colors.white;
  static const _roofs = [
    Color(0xFF1CB0F6), // Duolingo Blue
    Color(0xFFFFB800), // Duolingo Gold
    Color(0xFFFF4B4B), // Duolingo Red
    Color(0xFF58CC02), // Duolingo Green
    Color(0xFFA855F7), // Duolingo Purple
    Color(0xFF06B6D4), // Cyan
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final w = size.width;
    final h = size.height;
    final roadW = w * GameEngine.roadFrac;
    final roadL = (w - roadW) / 2;
    final roadR = roadL + roadW;
    final scroll = e.distance * roadW;
    final p = Paint();

    // Trotoar dasar
    p.color = _sidewalk;
    canvas.drawRect(Offset.zero & size, p);

    _drawBuildings(canvas, w, h, roadL, roadR, roadW, scroll);
    _drawTrees(canvas, h, roadL, roadR, roadW, scroll);

    // Jalan + bahu jalan
    p.color = _curb;
    canvas.drawRect(Rect.fromLTRB(roadL - 4, 0, roadR + 4, h), p);
    p.color = _asphalt;
    canvas.drawRect(Rect.fromLTRB(roadL, 0, roadR, h), p);

    _drawRoadMarks(canvas, h, roadL, roadR, roadW, scroll);

    for (final o in e.obstacles) {
      _drawObstacle(canvas, o, roadL, roadW);
    }
    _drawRunner(canvas, roadL, roadW);

    canvas.restore();
  }

  void _drawBuildings(Canvas c, double w, double h, double roadL,
      double roadR, double roadW, double scroll) {
    final sw = roadL * 0.42; // lebar trotoar
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

        // Dinding / Atap bangunan
        p.color = _roofs[idx];
        c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), p);

        // Garis tepi 3D bawah
        p.color = Colors.black.withOpacity(0.12);
        c.drawRect(Rect.fromLTWH(rect.left, rect.bottom - 4, rect.width, 4), p);

        // Detail dekoratif atap
        final k = ((i * 13 + side * 7) % 5) / 5.0;
        p.color = Colors.white.withOpacity(0.35);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + bw * (0.12 + 0.3 * k),
                rect.top + bh * 0.22, bw * 0.3, bh * 0.2),
            const Radius.circular(3),
          ),
          p,
        );
      }
    }
  }

  void _drawTrees(Canvas c, double h, double roadL, double roadR,
      double roadW, double scroll) {
    final sw = roadL * 0.42;
    final period = roadW * 0.7;
    final first = (scroll / period).floor() - 1;
    final last = ((scroll + h) / period).ceil() + 1;
    final p = Paint();

    for (int i = first; i <= last; i++) {
      final y = h - (i * period - scroll);
      final cx = i.isEven ? roadL - sw / 2 : roadR + sw / 2;
      final r = sw * 0.38;

      // Bayangan pohon
      p.color = Colors.black.withOpacity(0.12);
      c.drawCircle(Offset(cx + 2, y + 3), r, p);

      // Daun pohon Duolingo Green
      p.color = const Color(0xFF58CC02);
      c.drawCircle(Offset(cx, y), r, p);
      p.color = const Color(0xFF46A302);
      c.drawCircle(Offset(cx - r * 0.25, y - r * 0.25), r * 0.55, p);
    }
  }

  void _drawRoadMarks(Canvas c, double h, double roadL, double roadR,
      double roadW, double scroll) {
    final p = Paint()..color = _white;

    // Garis tepi jalan
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
    p.color = _white.withOpacity(0.9);
    for (int k = cFirst; k <= cLast; k++) {
      if (k <= 0) continue;
      final bottom = h - (k * cw - scroll);
      for (int s = 0; s < 7; s++) {
        final x = roadL + roadW * 0.07 + s * roadW * 0.13;
        c.drawRect(Rect.fromLTWH(x, bottom - zh, roadW * 0.07, zh), p);
      }
    }
  }

  // ─── RINTANGAN & ITEM (OBSTACLES & POWERUPS) ──────────────────────
  void _drawObstacle(Canvas c, Obstacle o, double roadL, double roadW) {
    final cx = roadL + (o.x + 0.5) * roadW;
    final cy = o.y * roadW;
    final w = o.w * roadW;
    final h = o.h * roadW;
    final p = Paint();

    // Bayangan objek (dikecualikan untuk jalan retak karena menyatu dengan aspal)
    if (o.kind != ObstacleKind.crack) {
      p.color = Colors.black.withOpacity(0.18);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(cx + w * 0.06, cy + h * 0.12),
              width: w * 1.05,
              height: h),
          p);
    }

    switch (o.kind) {
      case ObstacleKind.crack:
        // Jalan Retak (Melambatkan Lari)
        final crackColor = o.triggered ? const Color(0xFF1E293B) : const Color(0xFF0F172A);
        final crackPaint = Paint()
          ..color = crackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final edgePaint = Paint()
          ..color = const Color(0xFF64748B).withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round;

        final crackPath = Path()
          ..moveTo(cx - w * 0.45, cy - h * 0.20)
          ..lineTo(cx - w * 0.15, cy + h * 0.12)
          ..lineTo(cx + w * 0.10, cy - h * 0.22)
          ..lineTo(cx + w * 0.44, cy + h * 0.18);

        // Cabang retakan
        crackPath.moveTo(cx - w * 0.15, cy + h * 0.12);
        crackPath.lineTo(cx - w * 0.06, cy + h * 0.38);

        crackPath.moveTo(cx + w * 0.10, cy - h * 0.22);
        crackPath.lineTo(cx + w * 0.24, cy - h * 0.34);

        c.drawPath(crackPath, edgePaint);
        c.drawPath(crackPath, crackPaint);

        // Serpihan aspal kecil
        p.color = crackColor;
        c.drawCircle(Offset(cx - w * 0.26, cy + h * 0.24), 2.0, p);
        c.drawCircle(Offset(cx + w * 0.20, cy - h * 0.08), 2.2, p);
        break;

      case ObstacleKind.energyDrink:
        // Minuman Berenergi (Menambah Kecepatan)
        final bob = sin(e.time * 7 + cx) * 2.5;
        final drinkCy = cy + bob;

        // Lingkaran pendar energi lembut
        p.color = const Color(0xFF06B6D4).withOpacity(0.20);
        c.drawCircle(Offset(cx, drinkCy), w * 0.85, p);

        // Badan Kaleng Minuman Berenergi
        final canRect = Rect.fromCenter(
          center: Offset(cx, drinkCy),
          width: w * 0.72,
          height: h * 0.88,
        );
        p.color = const Color(0xFF0284C7);
        c.drawRRect(RRect.fromRectAndRadius(canRect, const Radius.circular(5)), p);

        // Tutup kaleng perak
        p.color = const Color(0xFFCBD5E1);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - w * 0.32, canRect.top - 2.5, w * 0.64, 4),
            const Radius.circular(2),
          ),
          p,
        );

        // Lambang Kilat Energi (Lightning Bolt Kuning)
        p.color = const Color(0xFFFFB800);
        final bolt = Path()
          ..moveTo(cx + 1, drinkCy - h * 0.26)
          ..lineTo(cx - w * 0.18, drinkCy)
          ..lineTo(cx, drinkCy)
          ..lineTo(cx - 1, drinkCy + h * 0.26)
          ..lineTo(cx + w * 0.18, drinkCy - 1)
          ..lineTo(cx, drinkCy - 1)
          ..close();
        c.drawPath(bolt, p);
        break;

      case ObstacleKind.cone:
        // Traffic Cone Orange Duolingo
        p.color = const Color(0xFFD97706);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(cx - w / 2, cy + h * 0.22, w, h * 0.28),
                const Radius.circular(3)),
            p);
        p.color = const Color(0xFFFF9600);
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
        // Road Barrier Merah-Putih
        final r = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
        final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
        p.color = const Color(0xFF64748B);
        c.drawRect(Rect.fromLTWH(r.left + w * 0.1, r.bottom, w * 0.06, h * 0.3), p);
        c.drawRect(Rect.fromLTWH(r.right - w * 0.16, r.bottom, w * 0.06, h * 0.3), p);
        p.color = Colors.white;
        c.drawRRect(rr, p);
        c.save();
        c.clipRRect(rr);
        p.color = const Color(0xFFFF4B4B); // Duolingo Red
        const n = 6;
        for (int s = 0; s < n; s += 2) {
          c.drawRect(Rect.fromLTWH(r.left + s * w / n, r.top, w / n, h), p);
        }
        c.restore();
        break;

      case ObstacleKind.car:
        // Mobil Kota
        p.color = const Color(0xFF1E293B);
        for (final dx in [-w / 2 - 2, w / 2 - 2]) {
          c.drawRect(Rect.fromLTWH(cx + dx, cy - h * 0.34, 4, h * 0.2), p);
          c.drawRect(Rect.fromLTWH(cx + dx, cy + h * 0.14, 4, h * 0.2), p);
        }
        p.color = o.color;
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
                const Radius.circular(10)),
            p);
        p.color = Color.lerp(o.color, Colors.white, 0.3)!;
        c.drawRect(
            Rect.fromLTWH(cx - w * 0.34, cy - h * 0.2, w * 0.68, h * 0.22), p);
        p.color = const Color(0xFF0F172A).withOpacity(0.85);
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
        p.color = const Color(0xFFFFE082); // Lampu depan
        c.drawCircle(Offset(cx - w * 0.3, cy + h / 2 - 5), 3.5, p);
        c.drawCircle(Offset(cx + w * 0.3, cy + h / 2 - 5), 3.5, p);
        break;

      case ObstacleKind.bin:
        // Tempat Sampah Hijau Duolingo
        p.color = const Color(0xFF58CC02);
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(cx, cy + h * 0.08),
                    width: w * 0.9,
                    height: h * 0.8),
                const Radius.circular(4)),
            p);
        p.color = Colors.white.withOpacity(0.3);
        for (int s = 1; s < 4; s++) {
          c.drawRect(
              Rect.fromLTWH(cx - w * 0.38 + s * w * 0.19, cy - h * 0.1, 2, h * 0.5),
              p);
        }
        p.color = const Color(0xFF46A302);
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
        // Pesepeda
        p.color = const Color(0xFF334155);
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
        p.color = const Color(0xFF0F172A);
        c.drawCircle(Offset(cx, cy - h * 0.04), w * 0.27, p);
        break;
    }
  }

  // ─── PELARI (HERO RUNNER DUOLINGO BIRU-EMAS) ──────────────────────
  void _drawRunner(Canvas c, double roadL, double roadW) {
    final cx = roadL + (e.runnerX + 0.5) * roadW;
    final cy = e.runnerY * roadW;
    final w = GameEngine.runnerW * roadW;
    final h = GameEngine.runnerH * roadW;
    final swing = sin(e.time * 16) * h * 0.12;
    final p = Paint();

    // Efek visual boost kecepatan di belakang pelari
    if (e.boostTimer > 0) {
      p.color = const Color(0xFF0284C7).withOpacity(0.55);
      p.strokeWidth = 2.2;
      p.style = PaintingStyle.stroke;
      for (int s = 0; s < 3; s++) {
        final streakX = cx - w * 0.30 + s * w * 0.30;
        c.drawLine(
          Offset(streakX, cy + h * 0.38),
          Offset(streakX, cy + h * 0.65 + sin(e.time * 22 + s) * 4),
          p,
        );
      }
      p.style = PaintingStyle.fill;
    }

    // Efek debu jika sedang melambat akibat jalan retak
    if (e.slowTimer > 0) {
      p.color = const Color(0xFF94A3B8).withOpacity(0.45);
      c.drawCircle(Offset(cx - w * 0.32, cy + h * 0.42), 3.0, p);
      c.drawCircle(Offset(cx + w * 0.32, cy + h * 0.42), 2.5, p);
    }

    // Bayangan pelari
    p.color = Colors.black.withOpacity(0.2);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(cx + 2, cy + 4), width: w * 1.1, height: h * 0.95),
        p);

    // Kaki & Sepatu
    p.color = const Color(0xFF1E293B);
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
    p.color = const Color(0xFFFCD34D); // Kulit cerah
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

    // Baju Lari Duolingo Primary Blue
    p.color = const Color(0xFF1CB0F6);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - w * 0.4, cy - h * 0.2, w * 0.8, h * 0.42),
            const Radius.circular(6)),
        p);

    // Garis aksen emas di dada
    p.color = const Color(0xFFFFB800);
    c.drawRect(Rect.fromLTWH(cx - w * 0.3, cy - h * 0.05, w * 0.6, 3), p);

    // Kepala & Topi Lari
    p.color = const Color(0xFF0F172A);
    c.drawCircle(Offset(cx, cy - h * 0.3), w * 0.3, p);
    p.color = const Color(0xFFFFB800); // Headband emas
    c.drawRect(Rect.fromLTWH(cx - w * 0.28, cy - h * 0.32, w * 0.56, 3), p);
  }

  @override
  bool shouldRepaint(covariant _CityPainter oldDelegate) => true;
}

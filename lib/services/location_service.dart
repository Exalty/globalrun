import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class TrackPoint {
  final LatLng position;
  final int elapsedMs; // waktu bergerak (tanpa pause)
  const TrackPoint(this.position, this.elapsedMs);
}

class LocationTrackingService extends ChangeNotifier {
  // ── MODE TES GPS ──────────────────────────────────────────────────────
  // true  = pengaturan GPS polos (tanpa foreground service, pakai chip GPS
  //         langsung). Dipakai untuk mencari penyebab fix tidak masuk.
  // false = pengaturan produksi (foreground service + background tracking).
  // SAMAKAN dengan nilai yang sedang kamu pakai di project.
  static const bool _testPlainGps = true;

  // Ambang filter GPS (sesuaikan bila perlu)
  static const double _maxAccuracyM = 25.0; // abaikan fix dengan akurasi > 25 m
  static const double _minMoveM = 2.0; // abaikan jitter saat diam
  static const double _maxSpeedMs = 12.0; // > 43 km/h = lompatan GPS / tidak wajar
  static const Duration _noFixTimeout = Duration(seconds: 20);

  static const Distance _distance = Distance();

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  Timer? _simulationTimer;
  Timer? _noFixTimer;

  /// Arah hadap HP (derajat, 0 = utara). Pakai ValueNotifier agar hanya
  /// marker yang rebuild, bukan seluruh layar.
  final ValueNotifier<double> heading = ValueNotifier<double>(0.0);
  bool _hasCompass = false;

  bool _isTracking = false;
  bool _isSimulating = false;
  bool _usedSimulation = false;
  bool _isPaused = false;
  String? _statusMessage;
  double? _gpsAccuracy;
  int _fixCount = 0;

  final List<LatLng> _routePoints = [];
  final List<TrackPoint> _track = [];
  double _totalDistanceMeters = 0.0;
  double _currentSpeedKmh = 0.0;
  LatLng? _currentLocation;
  TrackPoint? _lastAccepted;
  bool _skipNextDistance = false;

  DateTime? _startTime;
  DateTime? _stopTime;
  DateTime? _pauseStart;
  Duration _pausedTotal = Duration.zero;

  // ── Kontrol simulasi (demo) ───────────────────────────────────────────
  static const double _simRadiusM = 145.0; // radius lintasan melingkar simulasi
  final Random _rand = Random();
  int _simSpeed = 1; // pengali waktu: 1x, 5x, 10x, 30x
  int _simPaceSecPerKm = 360; // pace simulasi (6:00 /km = 10 km/h)
  Duration _simBonus = Duration.zero; // waktu tambahan akibat percepatan/skip
  double _simAngle = 0.0;
  LatLng? _simPos;

  bool get isTracking => _isTracking;
  bool get isSimulating => _isSimulating;
  bool get usedSimulation => _usedSimulation;
  bool get isPaused => _isPaused;
  bool get hasFix => _currentLocation != null;
  String? get statusMessage => _statusMessage;
  double? get gpsAccuracy => _gpsAccuracy;
  int get fixCount => _fixCount;
  DateTime? get startTime => _startTime;
  int get simSpeed => _simSpeed;
  int get simPaceSecPerKm => _simPaceSecPerKm;

  UnmodifiableListView<LatLng> get routePoints => UnmodifiableListView(_routePoints);
  UnmodifiableListView<TrackPoint> get trackPoints => UnmodifiableListView(_track);
  double get totalDistanceKm => _totalDistanceMeters / 1000.0;
  double get currentSpeedKmh => _currentSpeedKmh;
  LatLng get currentLocation =>
      _currentLocation ?? const LatLng(-6.2088, 106.8456); // default Monas

  /// Waktu bergerak: otomatis berhenti saat pause / stop, dan akurat
  /// walau app di background (berbasis DateTime, bukan hitungan Timer).
  /// _simBonus hanya terisi saat simulasi dipercepat / dilompati.
  Duration get elapsed {
    if (_startTime == null) return Duration.zero;
    final end = _pauseStart ?? _stopTime ?? DateTime.now();
    final d = end.difference(_startTime!) - _pausedTotal + _simBonus;
    return d.isNegative ? Duration.zero : d;
  }

  // ───────────────────────── START / STOP ─────────────────────────

  Future<void> startTracking({bool simulationMode = false}) async {
    if (_isTracking) return;
    _isTracking = true;
    _stopTime = null;
    _statusMessage = null;
    _fixCount = 0;
    _startCompass();

    if (simulationMode) {
      _markStarted();
      _startSimulation();
      notifyListeners();
      return;
    }

    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      debugPrint('GPS service enabled = $serviceOn');
      if (!serviceOn) {
        _onUnavailable('GPS perangkat mati. Aktifkan layanan lokasi.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      debugPrint('GPS permission = $permission');
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _onUnavailable('Izin lokasi ditolak. Aktifkan di pengaturan aplikasi.');
        return;
      }

      // Posisi terakhir hanya untuk menampilkan peta, TIDAK dihitung sebagai jarak.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && _currentLocation == null) {
          _currentLocation = LatLng(last.latitude, last.longitude);
        }
      } catch (_) {}

      _markStarted();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: _buildSettings(),
      ).listen(
        _onPosition,
        onError: (err) {
          debugPrint('GPS STREAM ERROR: $err');
          _onUnavailable('Error GPS: $err');
        },
      );

      // Watchdog: kalau 20 detik tidak ada fix, tampilkan peringatan di chip.
      _noFixTimer?.cancel();
      _noFixTimer = Timer(_noFixTimeout, () {
        if (_isTracking && !_isSimulating && _fixCount == 0) {
          debugPrint('GPS: belum ada fix setelah ${_noFixTimeout.inSeconds} detik');
          _statusMessage =
              'Belum ada sinyal GPS. Keluar ke area terbuka & cek izin lokasi.';
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('GPS start gagal: $e');
      _onUnavailable('Gagal memulai GPS: $e');
      return;
    }
    notifyListeners();
  }

  void _markStarted() {
    _startTime ??= DateTime.now();
  }

  /// Tidak lagi otomatis jatuh ke simulasi, supaya error GPS terlihat jelas
  /// di chip. Simulasi hanya lewat tombol "Simulasi Test".
  void _onUnavailable(String message) {
    _statusMessage = message;
    debugPrint('Location unavailable: $message');
    notifyListeners();
  }

  /// Dipakai tombol "Simulasi Test".
  void enableSimulation() {
    if (_isSimulating) return;
    _positionStream?.cancel();
    _positionStream = null;
    _noFixTimer?.cancel();
    _statusMessage = null;
    _isTracking = true;
    _markStarted();
    _startSimulation();
    notifyListeners();
  }

  LocationSettings _buildSettings() {
    if (_testPlainGps) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          forceLocationManager: true, // chip GPS langsung, bukan Google Play Services
        );
      }
      return const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      );
    }

    // ── Pengaturan produksi ──
    const distanceFilter = 3;
    if (kIsWeb) {
      return const LocationSettings(
          accuracy: LocationAccuracy.best, distanceFilter: distanceFilter);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: distanceFilter,
          intervalDuration: const Duration(seconds: 1),
          // Foreground service: tracking tetap jalan saat layar mati / app di background
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Global Virtual Race',
            notificationText: 'Pelacakan lari sedang aktif',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          distanceFilter: distanceFilter,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      default:
        return const LocationSettings(
            accuracy: LocationAccuracy.best, distanceFilter: distanceFilter);
    }
  }

  // ───────────────────────── GPS ─────────────────────────

  void _onPosition(Position pos) {
    debugPrint(
        'FIX ${pos.latitude},${pos.longitude} acc=${pos.accuracy} sim=$_isSimulating');
    if (_isSimulating) return;

    _fixCount++;
    _noFixTimer?.cancel();
    _statusMessage = null; // fix masuk -> hapus pesan error/peringatan

    final p = LatLng(pos.latitude, pos.longitude);
    _currentLocation = p; // untuk tampilan peta
    _gpsAccuracy = pos.accuracy;

    // Tanpa kompas: pakai arah gerak GPS saat bergerak
    if (!_hasCompass && pos.speed > 0.3 && pos.heading >= 0) {
      _setHeading(pos.heading, alpha: 0.5);
    }

    // Fix kurang akurat tidak dimasukkan ke rute/jarak
    if (pos.accuracy > _maxAccuracyM) {
      notifyListeners();
      return;
    }
    _addTrackPoint(p, max(0.0, pos.speed) * 3.6);
  }

  /// [atMs] : cap waktu titik (ms). Dipakai simulasi yang dipercepat.
  /// [notify]: false untuk batch (notifikasi dikirim sekali di akhir).
  void _addTrackPoint(
    LatLng p,
    double speedKmh, {
    bool validate = true,
    int? atMs,
    bool notify = true,
  }) {
    void done() {
      if (notify) notifyListeners();
    }

    if (_isPaused) {
      done();
      return;
    }
    final nowMs = atMs ?? elapsed.inMilliseconds;
    final last = _lastAccepted;

    if (last != null && validate && !_skipNextDistance) {
      final d = _distance.as(LengthUnit.Meter, last.position, p);
      final dt = (nowMs - last.elapsedMs) / 1000.0;
      if (d < _minMoveM) {
        _currentSpeedKmh = 0.0; // diam / jitter
        done();
        return;
      }
      if (dt > 0 && d / dt > _maxSpeedMs) {
        done(); // lompatan GPS, buang
        return;
      }
      _totalDistanceMeters += d;
    } else if (last != null && !validate) {
      _totalDistanceMeters += _distance.as(LengthUnit.Meter, last.position, p);
    }
    _skipNextDistance = false; // setelah resume: titik pertama jadi jangkar baru

    final point = TrackPoint(p, nowMs);
    _lastAccepted = point;
    _track.add(point);
    _routePoints.add(p);
    // Haluskan kecepatan agar angka tidak meloncat-loncat
    final clamped = speedKmh.clamp(0.0, 45.0).toDouble();
    _currentSpeedKmh =
        _currentSpeedKmh == 0 ? clamped : _currentSpeedKmh * 0.6 + clamped * 0.4;
    done();
  }

  // ───────────────────────── KOMPAS ─────────────────────────

  void _startCompass() {
    _compassStream?.cancel();
    final events = FlutterCompass.events;
    if (events == null) {
      _hasCompass = false;
      return;
    }
    _compassStream = events.listen(
      (e) {
        final h = e.heading;
        if (h == null) return;
        _hasCompass = true;
        _setHeading(h);
      },
      onError: (_) => _hasCompass = false,
    );
  }

  /// Low-pass filter melingkar (tangani lompatan 359° -> 1°).
  void _setHeading(double target, {double alpha = 0.25}) {
    final t = (target % 360 + 360) % 360;
    final diff = ((t - heading.value + 540) % 360) - 180;
    if (diff.abs() < 1.5) return; // abaikan getar kecil
    heading.value = ((heading.value + diff * alpha) % 360 + 360) % 360;
  }

  // ───────────────────────── PAUSE / RESUME ─────────────────────────

  void pause() {
    if (!_isTracking || _isPaused) return;
    _isPaused = true;
    _pauseStart = DateTime.now();
    _currentSpeedKmh = 0.0;
    notifyListeners();
  }

  void resume() {
    if (!_isPaused) return;
    if (_pauseStart != null) {
      _pausedTotal += DateTime.now().difference(_pauseStart!);
    }
    _pauseStart = null;
    _isPaused = false;
    _skipNextDistance = true; // jarak selama pause tidak dihitung
    notifyListeners();
  }

  // ───────────────────────── SIMULASI (demo) ─────────────────────────

  /// Pengali waktu simulasi: 1 = real time, 10 = 10x lebih cepat.
  void setSimulationSpeed(int factor) {
    _simSpeed = factor.clamp(1, 60).toInt();
    notifyListeners();
  }

  /// Pace simulasi dalam detik per KM (contoh 360 = 6:00 /km).
  void setSimulationPace(int secPerKm) {
    _simPaceSecPerKm = secPerKm.clamp(180, 900).toInt();
    notifyListeners();
  }

  void _startSimulation() {
    _isSimulating = true;
    _usedSimulation = true;
    _simulationTimer?.cancel();

    _simPos = _currentLocation ?? const LatLng(-6.2185, 106.8026);
    _currentLocation = _simPos;
    _simAngle = 0.0;
    if (_routePoints.isEmpty) {
      _addTrackPoint(_simPos!, 0, validate: false);
    }

    _simulationTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _simTick());
  }

  /// Satu tick real = [_simSpeed] detik waktu simulasi.
  void _simTick() {
    if (!_isSimulating || _isPaused) return;
    final baseMs = elapsed.inMilliseconds;
    for (var k = 0; k < _simSpeed; k++) {
      _simAdvance(1, atMs: baseMs + k * 1000, notify: false);
    }
    // Majukan jam lari agar sinkron dengan jarak yang sudah ditempuh
    if (_simSpeed > 1) _simBonus += Duration(seconds: _simSpeed - 1);
    notifyListeners();
  }

  /// Menggerakkan pelari simulasi sejauh [seconds] detik pada pace saat ini.
  void _simAdvance(int seconds, {required int atMs, bool notify = true}) {
    final cur = _simPos ?? _currentLocation ?? const LatLng(-6.2185, 106.8026);
    final speedMs = 1000.0 / _simPaceSecPerKm;
    final stepDeg = speedMs * seconds / 111320.0; // meter -> derajat
    _simAngle += speedMs * seconds / _simRadiusM; // lintasan melingkar

    final next = LatLng(
      cur.latitude + stepDeg * cos(_simAngle) + (_rand.nextDouble() - 0.5) * 0.000004,
      cur.longitude + stepDeg * sin(_simAngle) + (_rand.nextDouble() - 0.5) * 0.000004,
    );
    if (!_hasCompass) {
      _setHeading(_distance.bearing(cur, next), alpha: 0.5);
    }
    _simPos = next;
    _currentLocation = next;
    _gpsAccuracy = 5.0;

    final kmh = (3600.0 / _simPaceSecPerKm) * (0.97 + _rand.nextDouble() * 0.06);
    _addTrackPoint(next, kmh, validate: false, atMs: atMs, notify: notify);
  }

  /// Lompat langsung sampai jarak [targetKm] (hanya saat simulasi aktif).
  /// Rute, jarak, dan waktu ikut terisi seolah lari sungguhan pada pace
  /// simulasi. Mengembalikan jumlah detik simulasi yang dilompati.
  int skipSimulationTo(double targetKm) {
    if (!_isSimulating || _isPaused) return 0;
    final targetM = targetKm * 1000.0;
    if (_totalDistanceMeters >= targetM) return 0;

    const stepSec = 5; // satu titik per 5 detik agar data tidak terlalu besar
    final baseMs = elapsed.inMilliseconds;
    var skipped = 0;
    while (_totalDistanceMeters < targetM && skipped < 24 * 3600) {
      skipped += stepSec;
      _simAdvance(stepSec, atMs: baseMs + skipped * 1000, notify: false);
    }
    _simBonus += Duration(seconds: skipped);
    notifyListeners();
    return skipped;
  }

  // ───────────────────────── RESET / DISPOSE ─────────────────────────

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _compassStream?.cancel();
    _compassStream = null;
    _simulationTimer?.cancel();
    _noFixTimer?.cancel();
    if (_isPaused && _pauseStart != null) {
      _pausedTotal += DateTime.now().difference(_pauseStart!);
      _pauseStart = null;
    }
    _stopTime = DateTime.now();
    _isTracking = false;
    _isSimulating = false;
    _isPaused = false;
    notifyListeners();
  }

  void resetTrack() {
    _routePoints.clear();
    _track.clear();
    _totalDistanceMeters = 0.0;
    _currentSpeedKmh = 0.0;
    _lastAccepted = null;
    _skipNextDistance = false;
    _startTime = null;
    _stopTime = null;
    _pauseStart = null;
    _pausedTotal = Duration.zero;
    _isPaused = false;
    _usedSimulation = false;
    _statusMessage = null;
    _fixCount = 0;
    _simBonus = Duration.zero;
    _simSpeed = 1;
    _simAngle = 0.0;
    _simPos = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    _simulationTimer?.cancel();
    _noFixTimer?.cancel();
    heading.dispose();
    super.dispose();
  }
}
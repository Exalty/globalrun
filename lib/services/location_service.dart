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
  // ── MODE TES ──────────────────────────────────────────────────────────
  // true  = pengaturan GPS polos (tanpa foreground service, pakai chip GPS
  //         langsung). Dipakai untuk mencari penyebab fix tidak masuk.
  // false = pengaturan produksi (foreground service + background tracking).
  // Setelah GPS terbukti jalan, ubah ke false.
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

  bool get isTracking => _isTracking;
  bool get isSimulating => _isSimulating;
  bool get usedSimulation => _usedSimulation;
  bool get isPaused => _isPaused;
  bool get hasFix => _currentLocation != null;
  String? get statusMessage => _statusMessage;
  double? get gpsAccuracy => _gpsAccuracy;
  int get fixCount => _fixCount;
  DateTime? get startTime => _startTime;

  UnmodifiableListView<LatLng> get routePoints => UnmodifiableListView(_routePoints);
  UnmodifiableListView<TrackPoint> get trackPoints => UnmodifiableListView(_track);
  double get totalDistanceKm => _totalDistanceMeters / 1000.0;
  double get currentSpeedKmh => _currentSpeedKmh;
  LatLng get currentLocation =>
      _currentLocation ?? const LatLng(-6.2088, 106.8456); // default Monas

  /// Waktu bergerak: otomatis berhenti saat pause / stop, dan akurat
  /// walau app di background (berbasis DateTime, bukan hitungan Timer).
  Duration get elapsed {
    if (_startTime == null) return Duration.zero;
    final end = _pauseStart ?? _stopTime ?? DateTime.now();
    final d = end.difference(_startTime!) - _pausedTotal;
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
  /// di chip. Simulasi hanya lewat tombol "Simulasi Test" (debug).
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

  void _addTrackPoint(LatLng p, double speedKmh, {bool validate = true}) {
    if (_isPaused) {
      notifyListeners();
      return;
    }
    final nowMs = elapsed.inMilliseconds;
    final last = _lastAccepted;

    if (last != null && validate && !_skipNextDistance) {
      final d = _distance.as(LengthUnit.Meter, last.position, p);
      final dt = (nowMs - last.elapsedMs) / 1000.0;
      if (d < _minMoveM) {
        _currentSpeedKmh = 0.0; // diam / jitter
        notifyListeners();
        return;
      }
      if (dt > 0 && d / dt > _maxSpeedMs) {
        notifyListeners(); // lompatan GPS, buang
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
    notifyListeners();
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

  // ───────────────────────── SIMULASI (debug) ─────────────────────────

  void _startSimulation() {
    _isSimulating = true;
    _usedSimulation = true;
    _simulationTimer?.cancel();

    LatLng current = _currentLocation ?? const LatLng(-6.2185, 106.8026);
    _currentLocation = current;
    if (_routePoints.isEmpty) {
      _addTrackPoint(current, 0, validate: false);
    }

    double angle = 0.0;
    final rand = Random();
    const stepDeg = 0.000026; // ≈ 2.9 m per detik ≈ 10.4 km/h

    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      angle += 0.02;
      final next = LatLng(
        current.latitude + stepDeg * cos(angle) + (rand.nextDouble() - 0.5) * 0.000004,
        current.longitude + stepDeg * sin(angle) + (rand.nextDouble() - 0.5) * 0.000004,
      );
      if (!_hasCompass) {
        _setHeading(_distance.bearing(current, next), alpha: 0.5);
      }
      current = next;
      _currentLocation = next;
      _gpsAccuracy = 5.0;
      _addTrackPoint(next, 9.0 + rand.nextDouble() * 3.0, validate: false);
    });
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
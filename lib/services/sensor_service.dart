import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MotionSensorService extends ChangeNotifier {
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;

  int _stepCount = 0;
  double _currentMagnitude = 0.0;
  String _motionState = 'Diam (Stationary)';
  bool _isListening = false;
  bool _isSimulating = false;
  bool _isPaused = false;
  Timer? _simulationTimer;

  // Kontrol simulasi (demo): pengali kecepatan waktu
  int _simSpeed = 1;
  double _extraStepFrac = 0.0;

  // Peak detection state
  double _lastMagnitude = 0.0;
  DateTime _lastStepTime = DateTime.now();

  int get stepCount => _stepCount;
  double get currentMagnitude => _currentMagnitude;
  String get motionState => _motionState;
  bool get isListening => _isListening;
  bool get isSimulating => _isSimulating;
  bool get isPaused => _isPaused;
  int get simSpeed => _simSpeed;

  void startTracking({bool simulationMode = false}) {
    if (_isListening) return;
    _isListening = true;

    if (simulationMode) {
      _startSimulation();
      notifyListeners();
      return;
    }

    try {
      _accelSubscription = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          final magnitude =
              sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          _processSensorReading(magnitude);
        },
        onError: (err) {
          debugPrint('Sensor error: $err');
          // Langkah palsu hanya boleh di debug build
          if (kDebugMode) _startSimulation();
        },
      );
    } catch (e) {
      if (kDebugMode) _startSimulation();
    }

    notifyListeners();
  }

  /// Dipakai tombol "Simulasi Test" (startTracking() return jika sudah listening).
  void enableSimulation() {
    if (_isSimulating) return;
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _isListening = true;
    _startSimulation();
    notifyListeners();
  }

  /// Pengali waktu simulasi (harus sama dengan LocationTrackingService).
  void setSimulationSpeed(int factor) {
    _simSpeed = factor.clamp(1, 60).toInt();
    notifyListeners();
  }

  /// Menambah langkah sekaligus (dipakai saat "Lompat ke Finish").
  void addSimulatedSteps(int count) {
    if (count <= 0) return;
    _stepCount += count;
    notifyListeners();
  }

  /// Smart Cadence Fallback:
  /// Jika akselerometer perangkat tidak berfungsi/terkunci saat berlari,
  /// sinkronisasikan langkah secara wajar berdasarkan jarak perpindahan GPS.
  void syncWithGpsDistance(double totalDistanceMeters) {
    if (totalDistanceMeters < 30 || _isPaused) return;
    // Rata-rata pelari menempuh 1 meter dalam ~1.35 langkah (panjang langkah ~0.74m)
    final expectedSteps = (totalDistanceMeters * 1.35).round();
    if (_stepCount < (expectedSteps * 0.4).round()) {
      _stepCount = expectedSteps;
      if (_motionState == 'Santai / Diam') {
        _motionState = 'Berlari (GPS Cadence)';
      }
      notifyListeners();
    }
  }

  void pause() {
    _isPaused = true;
    notifyListeners();
  }

  void resume() {
    _isPaused = false;
    notifyListeners();
  }

  void _processSensorReading(double magnitude) {
    _currentMagnitude = magnitude;

    if (magnitude < 1.2) {
      _motionState = 'Santai / Diam';
    } else if (magnitude < 3.5) {
      _motionState = 'Berjalan / Bersepeda Santai';
    } else if (magnitude < 8.0) {
      _motionState = 'Berlari (Running)';
    } else {
      _motionState = 'Sprint Cepat!';
    }

    // Deteksi langkah: peak di atas threshold + cooldown. Tidak dihitung saat pause.
    if (!_isPaused) {
      final now = DateTime.now();
      const threshold = 2.4;
      if (magnitude > threshold && _lastMagnitude <= threshold) {
        if (now.difference(_lastStepTime).inMilliseconds > 260) {
          _stepCount++;
          _lastStepTime = now;
        }
      }
    }
    _lastMagnitude = magnitude;
    notifyListeners();
  }

  void _startSimulation() {
    _isSimulating = true;
    _simulationTimer?.cancel();
    final rand = Random();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      // Saat waktu simulasi dipercepat, langkah ikut bertambah proporsional
      if (_simSpeed > 1 && !_isPaused) {
        _extraStepFrac += (_simSpeed - 1) * 0.5;
        final whole = _extraStepFrac.floor();
        if (whole > 0) {
          _stepCount += whole;
          _extraStepFrac -= whole;
        }
      }
      _processSensorReading(1.8 + rand.nextDouble() * 3.5);
    });
  }

  void stopTracking() {
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _simulationTimer?.cancel();
    _isListening = false;
    _isSimulating = false;
    _isPaused = false;
    notifyListeners();
  }

  void resetSteps() {
    _stepCount = 0;
    _currentMagnitude = 0.0;
    _lastMagnitude = 0.0;
    _motionState = 'Diam (Stationary)';
    _simSpeed = 1;
    _extraStepFrac = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }
}
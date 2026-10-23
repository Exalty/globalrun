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

  // Peak detection state
  double _lastMagnitude = 0.0;
  DateTime _lastStepTime = DateTime.now();

  int get stepCount => _stepCount;
  double get currentMagnitude => _currentMagnitude;
  String get motionState => _motionState;
  bool get isListening => _isListening;
  bool get isSimulating => _isSimulating;
  bool get isPaused => _isPaused;

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
    notifyListeners();
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }
}
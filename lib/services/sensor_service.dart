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
  Timer? _simulationTimer;

  // Peak detection state
  double _lastMagnitude = 0.0;
  DateTime _lastStepTime = DateTime.now();

  int get stepCount => _stepCount;
  double get currentMagnitude => _currentMagnitude;
  String get motionState => _motionState;
  bool get isListening => _isListening;
  bool get isSimulating => _isSimulating;

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
          final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          _processSensorReading(magnitude);
        },
        onError: (err) {
          // If real sensor fails (e.g. desktop environment), fallback to smooth mock/simulation automatically
          debugPrint('Sensor not available or platform error: $err. Switching to simulated tracking.');
          _startSimulation();
        },
      );
    } catch (e) {
      _startSimulation();
    }

    notifyListeners();
  }

  void _processSensorReading(double magnitude) {
    _currentMagnitude = magnitude;

    // Categorize motion
    if (magnitude < 1.2) {
      _motionState = 'Santai / Diam';
    } else if (magnitude < 3.5) {
      _motionState = 'Berjalan / Bersepeda Santai';
    } else if (magnitude < 8.0) {
      _motionState = 'Berlari (Running)';
    } else {
      _motionState = 'Sprint Cepat!';
    }

    // Step detection logic: peak crossing above threshold with cooldown
    final now = DateTime.now();
    const threshold = 2.4;
    if (magnitude > threshold && _lastMagnitude <= threshold) {
      if (now.difference(_lastStepTime).inMilliseconds > 260) {
        _stepCount++;
        _lastStepTime = now;
      }
    }
    _lastMagnitude = magnitude;
    notifyListeners();
  }

  void _startSimulation() {
    _isSimulating = true;
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      final rand = Random();
      // Generate realistic running acceleration magnitude
      final mag = 1.8 + rand.nextDouble() * 3.5;
      _processSensorReading(mag);
    });
  }

  void stopTracking() {
    _accelSubscription?.cancel();
    _simulationTimer?.cancel();
    _isListening = false;
    _isSimulating = false;
    notifyListeners();
  }

  void resetSteps() {
    _stepCount = 0;
    _currentMagnitude = 0.0;
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

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationTrackingService extends ChangeNotifier {
  StreamSubscription<Position>? _positionStream;
  Timer? _simulationTimer;

  bool _isTracking = false;
  bool _isSimulating = false;
  final List<LatLng> _routePoints = [];
  double _totalDistanceMeters = 0.0;
  double _currentSpeedKmh = 0.0;
  LatLng? _currentLocation;

  bool get isTracking => _isTracking;
  bool get isSimulating => _isSimulating;
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  double get totalDistanceKm => _totalDistanceMeters / 1000.0;
  double get currentSpeedKmh => _currentSpeedKmh;
  LatLng get currentLocation => _currentLocation ?? const LatLng(-6.2088, 106.8456); // Default Jakarta Monas

  Future<void> startTracking({bool simulationMode = false}) async {
    if (_isTracking) return;
    _isTracking = true;

    if (simulationMode) {
      _startSimulation();
      notifyListeners();
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _startSimulation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          _startSimulation();
          return;
        }
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3, // meters
        ),
      ).listen(
        (Position pos) {
          _updatePosition(LatLng(pos.latitude, pos.longitude), pos.speed * 3.6);
        },
        onError: (err) {
          debugPrint('Geolocator error: $err. Switching to simulated GPS.');
          _startSimulation();
        },
      );
    } catch (e) {
      _startSimulation();
    }

    notifyListeners();
  }

  void _updatePosition(LatLng newPos, double speedKmh) {
    if (_currentLocation != null) {
      final dist = const Distance().as(LengthUnit.Meter, _currentLocation!, newPos);
      if (dist > 1.0) {
        _totalDistanceMeters += dist;
      }
    }
    _currentLocation = newPos;
    _routePoints.add(newPos);
    _currentSpeedKmh = speedKmh >= 0 ? speedKmh : 0.0;
    notifyListeners();
  }

  void _startSimulation() {
    _isSimulating = true;
    _simulationTimer?.cancel();
    
    // Start at Jakarta GBK Senayan or current location
    LatLng current = _currentLocation ?? const LatLng(-6.2185, 106.8026);
    _currentLocation = current;
    _routePoints.add(current);

    double angle = 0.0;
    final rand = Random();

    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Simulate GPS movement around a running loop / track
      angle += 0.05;
      final latDelta = 0.00012 * cos(angle) + (rand.nextDouble() - 0.5) * 0.00003;
      final lngDelta = 0.00012 * sin(angle) + (rand.nextDouble() - 0.5) * 0.00003;
      final nextPos = LatLng(current.latitude + latDelta, current.longitude + lngDelta);
      
      final simulatedSpeed = 8.5 + rand.nextDouble() * 3.5; // ~9-12 km/h running pace
      _updatePosition(nextPos, simulatedSpeed);
      current = nextPos;
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _simulationTimer?.cancel();
    _isTracking = false;
    _isSimulating = false;
    notifyListeners();
  }

  void resetTrack() {
    _routePoints.clear();
    _totalDistanceMeters = 0.0;
    _currentSpeedKmh = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }
}

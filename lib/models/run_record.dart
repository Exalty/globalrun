import 'package:latlong2/latlong.dart';

/// Satu titik rute. [elapsedMs] = waktu bergerak (tanpa durasi pause).
class RunPoint {
  final double lat;
  final double lng;
  final int elapsedMs;
  const RunPoint(this.lat, this.lng, this.elapsedMs);

  LatLng get latLng => LatLng(lat, lng);

  List<num> toJson() => [
        double.parse(lat.toStringAsFixed(6)),
        double.parse(lng.toStringAsFixed(6)),
        elapsedMs,
      ];

  factory RunPoint.fromJson(List<dynamic> j) => RunPoint(
        (j[0] as num).toDouble(),
        (j[1] as num).toDouble(),
        (j[2] as num).toInt(),
      );
}

class RunSplit {
  final int km;
  final int seconds;
  const RunSplit(this.km, this.seconds);
}

class RunFormat {
  static String duration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// secPerKm -> "mm:ss"
  static String pace(int secPerKm) {
    if (secPerKm <= 0 || secPerKm > 3599) return '--:--';
    final m = (secPerKm ~/ 60).toString().padLeft(2, '0');
    final s = (secPerKm % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String paceFromSpeed(double kmh) =>
      kmh < 0.5 ? '--:--' : pace((3600 / kmh).round());

  static String date(DateTime d) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} ${p(d.hour)}:${p(d.minute)}';
  }
}

class RunRecord {
  final String id;
  final String eventId;
  final String eventTitle;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceKm;
  final double targetKm;
  final int steps;
  final bool completed; // target tercapai
  final bool isSimulated;
  final int? blockIndex;
  final String? blockHash;
  final String? polygonTxHash;
  final String? polygonscanUrl;
  final List<RunPoint> points;

  const RunRecord({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceKm,
    required this.targetKm,
    required this.steps,
    required this.completed,
    required this.isSimulated,
    required this.points,
    this.blockIndex,
    this.blockHash,
    this.polygonTxHash,
    this.polygonscanUrl,
  });

  double get avgSpeedKmh =>
      durationSeconds > 0 ? distanceKm / (durationSeconds / 3600.0) : 0.0;

  int get avgPaceSecPerKm =>
      distanceKm > 0.01 ? (durationSeconds / distanceKm).round() : 0;

  List<LatLng> get latLngs => points.map((p) => p.latLng).toList();

  RunRecord withBlock(int index, String hash) => RunRecord(
        id: id,
        eventId: eventId,
        eventTitle: eventTitle,
        startedAt: startedAt,
        durationSeconds: durationSeconds,
        distanceKm: distanceKm,
        targetKm: targetKm,
        steps: steps,
        completed: completed,
        isSimulated: isSimulated,
        points: points,
        blockIndex: index,
        blockHash: hash,
        polygonTxHash: polygonTxHash,
        polygonscanUrl: polygonscanUrl,
      );

  
  RunRecord withPolygon({required String txHash, required String scanUrl}) => RunRecord(
        id: id,
        eventId: eventId,
        eventTitle: eventTitle,
        startedAt: startedAt,
        durationSeconds: durationSeconds,
        distanceKm: distanceKm,
        targetKm: targetKm,
        steps: steps,
        completed: completed,
        isSimulated: isSimulated,
        points: points,
        blockIndex: blockIndex,
        blockHash: blockHash,
        polygonTxHash: txHash,
        polygonscanUrl: scanUrl,
      );

  /// Waktu per kilometer penuh (interpolasi antar titik rute).
  List<RunSplit> computeSplits() {
    final res = <RunSplit>[];
    if (points.length < 2) return res;
    const dist = Distance();
    double cum = 0;
    int nextKm = 1;
    int lastSplitMs = 0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final seg = dist.as(LengthUnit.Meter, a.latLng, b.latLng);
      while (seg > 0 && cum + seg >= nextKm * 1000) {
        final frac = (nextKm * 1000 - cum) / seg;
        final ms = (a.elapsedMs + (b.elapsedMs - a.elapsedMs) * frac).round();
        res.add(RunSplit(nextKm, ((ms - lastSplitMs) / 1000).round()));
        lastSplitMs = ms;
        nextKm++;
      }
      cum += seg;
    }
    return res;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'startedAt': startedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'distanceKm': distanceKm,
        'targetKm': targetKm,
        'steps': steps,
        'completed': completed,
        'isSimulated': isSimulated,
        'blockIndex': blockIndex,
        'blockHash': blockHash,
        'polygonTxHash': polygonTxHash,
        'polygonscanUrl': polygonscanUrl,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory RunRecord.fromJson(Map<String, dynamic> j) => RunRecord(
        id: j['id'] as String,
        eventId: j['eventId'] as String,
        eventTitle: j['eventTitle'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        durationSeconds: (j['durationSeconds'] as num).toInt(),
        distanceKm: (j['distanceKm'] as num).toDouble(),
        targetKm: (j['targetKm'] as num).toDouble(),
        steps: (j['steps'] as num).toInt(),
        completed: j['completed'] as bool,
        isSimulated: (j['isSimulated'] as bool?) ?? false,
        blockIndex: (j['blockIndex'] as num?)?.toInt(),
        blockHash: j['blockHash'] as String?,
        polygonTxHash: j['polygonTxHash'] as String?,
        polygonscanUrl: j['polygonscanUrl'] as String?,
        points: (j['points'] as List)
            .map((e) => RunPoint.fromJson(e as List))
            .toList(),
      );
}
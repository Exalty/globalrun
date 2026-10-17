class RaceEvent {
  final String id;
  final String title;
  final String description;
  final String type; // 'run' or 'cycling'
  final double distanceKm;
  final DateTime startTimeUtc; // UTC time for global sync
  final double feeUsd; // Base currency in USD
  final String bannerUrl;

  RaceEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.distanceKm,
    required this.startTimeUtc,
    required this.feeUsd,
    required this.bannerUrl,
  });

  static List<RaceEvent> sampleEvents() {
    final now = DateTime.now().toUtc();
    return [
      RaceEvent(
        id: 'ev-1',
        title: 'Tokyo Sunrise 10K Virtual Marathon',
        description: 'Race through dawn anywhere around the globe with runners in Japan, Indonesia, and Europe.',
        type: 'run',
        distanceKm: 10.0,
        startTimeUtc: now.add(const Duration(hours: 4)),
        feeUsd: 15.0,
        bannerUrl: 'Tokyo Virtual 10K',
      ),
      RaceEvent(
        id: 'ev-2',
        title: 'Tour de Alps Virtual Century 50K',
        description: 'Virtual cycling challenge simulation. Push your cadence and climb the virtual altitude.',
        type: 'cycling',
        distanceKm: 50.0,
        startTimeUtc: now.add(const Duration(days: 1, hours: 2)),
        feeUsd: 25.0,
        bannerUrl: 'Tour de Alps 50K',
      ),
      RaceEvent(
        id: 'ev-3',
        title: 'Global Equator 5K Fun Run',
        description: 'Sprint or jog with international participants. Instant verifiable blockchain medal at the finish!',
        type: 'run',
        distanceKm: 5.0,
        startTimeUtc: now.add(const Duration(minutes: 45)),
        feeUsd: 8.0,
        bannerUrl: 'Equator Sprint 5K',
      ),
      RaceEvent(
        id: 'ev-4',
        title: 'London Night Cadence 20K Ride',
        description: 'Fast-paced evening bicycle ride. Track your cadence, motion, and speed live.',
        type: 'cycling',
        distanceKm: 20.0,
        startTimeUtc: now.add(const Duration(days: 2)),
        feeUsd: 18.0,
        bannerUrl: 'London Night Cadence',
      ),
    ];
  }
}

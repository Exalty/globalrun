class RaceEvent {
  final String id;
  final String title;
  final String description;
  final String type; // 'run' or 'cycling'
  final double distanceKm;
  final DateTime startTimeUtc; // UTC time for global sync
  final double feeUsd; // Base currency in USD
  final String bannerUrl;
  final String? officialUrl;
  final String? location;
  final bool isLiveExternal;

  RaceEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.distanceKm,
    required this.startTimeUtc,
    required this.feeUsd,
    required this.bannerUrl,
    this.officialUrl,
    this.location,
    this.isLiveExternal = false,
  });

  factory RaceEvent.fromJson(Map<String, dynamic> json) {
    // Parse distance safely
    double dist = 5.0;
    if (json['distance_km'] != null) {
      if (json['distance_km'] is num) {
        dist = (json['distance_km'] as num).toDouble();
      } else {
        dist = double.tryParse(json['distance_km'].toString()) ?? 5.0;
      }
    }

    // Parse fee safely
    double fee = 10.0;
    if (json['fee_usd'] != null) {
      if (json['fee_usd'] is num) {
        fee = (json['fee_usd'] as num).toDouble();
      } else {
        fee = double.tryParse(json['fee_usd'].toString()) ?? 10.0;
      }
    }

    // Parse startTime safely
    DateTime startTime = DateTime.now().toUtc().add(const Duration(hours: 4));
    if (json['start_time_utc'] != null) {
      final parsed = DateTime.tryParse(json['start_time_utc'].toString());
      if (parsed != null) {
        startTime = parsed.toUtc();
      }
    }

    return RaceEvent(
      id: json['id']?.toString() ?? 'ev-${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'Race Event',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString().toLowerCase() == 'cycling' ? 'cycling' : 'run',
      distanceKm: dist,
      startTimeUtc: startTime,
      feeUsd: fee,
      bannerUrl: json['banner_url']?.toString() ?? json['title']?.toString() ?? 'Global Race',
      officialUrl: json['official_url']?.toString(),
      location: json['location']?.toString() ?? 'Global Venue 🌐',
      isLiveExternal: json['is_live_external'] == true,
    );
  }

  static List<RaceEvent> sampleEvents() {
    final now = DateTime.now().toUtc();
    return [
      RaceEvent(
        id: 'ev-1',
        title: 'Tokyo Marathon 2026',
        description: 'World Marathon Major resmi di Tokyo, Jepang. Berlari melintasi Shinjuku, Ginza, dan Tokyo Station dengan partisipasi atlet dunia.',
        type: 'run',
        distanceKm: 42.2,
        startTimeUtc: now.add(const Duration(hours: 4)),
        feeUsd: 25.0,
        bannerUrl: 'Tokyo Marathon 2026',
        officialUrl: 'https://www.marathon.tokyo/en/',
        location: 'Tokyo, Japan 🇯🇵',
        isLiveExternal: true,
      ),
      RaceEvent(
        id: 'ev-2',
        title: 'Maybank Marathon Bali 2026',
        description: 'World Athletics Elite Label Road Race di Gianyar Bali. Rute eksotis pesisir pantai dan pedesaan Bali.',
        type: 'run',
        distanceKm: 21.1,
        startTimeUtc: now.add(const Duration(days: 1, hours: 2)),
        feeUsd: 18.0,
        bannerUrl: 'Maybank Marathon Bali 2026',
        officialUrl: 'https://www.maybankmarathon.com/',
        location: 'Gianyar, Bali, Indonesia 🇮🇩',
        isLiveExternal: true,
      ),
      RaceEvent(
        id: 'ev-3',
        title: 'Borobudur Virtual 10K 2026',
        description: 'Lomba lari kultural di sekitar Candi Borobudur Magelang. Rasakan kearifan lokal Jawa Tengah dengan pencatatan sensor anti-cheat.',
        type: 'run',
        distanceKm: 10.0,
        startTimeUtc: now.add(const Duration(minutes: 45)),
        feeUsd: 10.0,
        bannerUrl: 'Borobudur Virtual 10K',
        officialUrl: 'https://borobudurmarathon.com/',
        location: 'Magelang, Jawa Tengah, Indonesia 🇮🇩',
        isLiveExternal: true,
      ),
      RaceEvent(
        id: 'ev-4',
        title: 'Tour de Alps Virtual Century 50K',
        description: 'Virtual cycling challenge simulasi tanjakan Pegunungan Alpen. Uji irama kayuhan (cadence), elevasi, dan daya tahan virtual.',
        type: 'cycling',
        distanceKm: 50.0,
        startTimeUtc: now.add(const Duration(days: 2)),
        feeUsd: 20.0,
        bannerUrl: 'Tour de Alps 50K',
        officialUrl: 'https://www.letour.fr/en/',
        location: 'Alps, France / Switzerland 🏔️',
        isLiveExternal: true,
      ),
    ];
  }
}

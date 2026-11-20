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
      location: json['location']?.toString() ?? 'Global Venue',
      isLiveExternal: json['is_live_external'] == true,
    );
  }

  factory RaceEvent.fromRunSignup(Map<String, dynamic> json) {
    final r = json['race'] as Map<String, dynamic>? ?? json;
    final name = _cleanHtml(r['name']?.toString() ?? 'Virtual Global Race');
    final desc = _cleanHtml(r['description']?.toString() ?? '');

    final text = '$name $desc'.toLowerCase();
    String type = 'run';
    double dist = 5.0;

    if (text.contains('cycling') || text.contains('bike') || text.contains('ride') || text.contains('tour de')) {
      type = 'cycling';
      dist = text.contains('century') ? 50.0 : 30.0;
    } else if (text.contains('half marathon') || text.contains('half-marathon') || text.contains('21k') || text.contains('21.1')) {
      dist = 21.1;
    } else if (text.contains('marathon') || text.contains('42k') || text.contains('42.2')) {
      dist = 42.2;
    } else if (text.contains('10k') || text.contains('10 mile') || text.contains('10-k')) {
      dist = 10.0;
    } else if (text.contains('5k') || text.contains('5-k')) {
      dist = 5.0;
    } else if (text.contains('1 mile') || text.contains('fun run')) {
      dist = 3.0;
    }

    DateTime startUtc = DateTime.now().toUtc().add(const Duration(days: 2));
    final nextDate = r['next_date']?.toString();
    final lastDate = r['last_date']?.toString();
    final dateStr = (nextDate != null && nextDate.isNotEmpty) ? nextDate : lastDate;

    if (dateStr != null && dateStr.isNotEmpty) {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final month = int.tryParse(parts[0]) ?? 1;
        final day = int.tryParse(parts[1]) ?? 1;
        final year = int.tryParse(parts[2]) ?? DateTime.now().year;
        startUtc = DateTime.utc(year, month, day, 7, 0, 0);
      }
    }

    String loc = 'Global Venue';
    final addr = r['address'];
    if (addr is Map<String, dynamic>) {
      final city = addr['city']?.toString();
      final state = addr['state']?.toString();
      final country = addr['country_code']?.toString() ?? 'US';
      final parts = [city, state, country].where((s) => s != null && s.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        loc = parts.join(', ');
      }
    }

    final double fee = dist >= 42.0 ? 25.0 : dist >= 21.0 ? 18.0 : dist >= 10.0 ? 12.0 : 8.0;
    final String raceId = r['race_id']?.toString() ?? 'rs-${DateTime.now().millisecondsSinceEpoch}';

    return RaceEvent(
      id: 'rs-$raceId',
      title: name,
      description: desc.isNotEmpty ? (desc.length > 200 ? '${desc.substring(0, 200)}...' : desc) : 'Lomba resmi terdaftar di platform global RunSignup.',
      type: type,
      distanceKm: dist,
      startTimeUtc: startUtc,
      feeUsd: fee,
      bannerUrl: name,
      officialUrl: r['url']?.toString() ?? 'https://runsignup.com',
      location: loc,
      isLiveExternal: true,
    );
  }

  static String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type,
        'distance_km': distanceKm,
        'start_time_utc': startTimeUtc.toIso8601String(),
        'fee_usd': feeUsd,
        'banner_url': bannerUrl,
        'official_url': officialUrl,
        'location': location,
        'is_live_external': isLiveExternal,
      };

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
        location: 'Tokyo, Japan',
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
        location: 'Gianyar, Bali, Indonesia',
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
        location: 'Magelang, Jawa Tengah, Indonesia',
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
        location: 'Alps, France / Switzerland',
        isLiveExternal: true,
      ),
    ];
  }
}

class RaceParticipantEntry {
  final int rank;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final int durationSeconds;
  final double avgSpeedKmh;
  final int steps;
  final bool isAntiCheatVerified;
  final bool isCurrentUser;
  final String? blockHash;

  const RaceParticipantEntry({
    required this.rank,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.durationSeconds,
    required this.avgSpeedKmh,
    required this.steps,
    this.isAntiCheatVerified = true,
    this.isCurrentUser = false,
    this.blockHash,
  });

  String get paceFormatted {
    if (avgSpeedKmh <= 0) return '-';
    final paceDecimal = 60.0 / avgSpeedKmh;
    final mins = paceDecimal.floor();
    final secs = ((paceDecimal - mins) * 60).round();
    return "$mins'${secs.toString().padLeft(2, '0')}\"/km";
  }

  String get durationFormatted {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) {
      return '${h}j ${m}m ${s}d';
    }
    return '${m}m ${s}d';
  }
}

class MyRaceStanding {
  final String eventId;
  final String eventTitle;
  final double distanceKm;
  final String eventType; // run / cycling
  final int myRank;
  final int totalParticipants;
  final int myDurationSeconds;
  final double myAvgSpeedKmh;
  final int mySteps;
  final String? blockHash;
  final String? polygonscanUrl;
  final DateTime completedAt;

  const MyRaceStanding({
    required this.eventId,
    required this.eventTitle,
    required this.distanceKm,
    this.eventType = 'run',
    required this.myRank,
    required this.totalParticipants,
    required this.myDurationSeconds,
    required this.myAvgSpeedKmh,
    required this.mySteps,
    this.blockHash,
    this.polygonscanUrl,
    required this.completedAt,
  });

  String get paceFormatted {
    if (myAvgSpeedKmh <= 0) return '-';
    final paceDecimal = 60.0 / myAvgSpeedKmh;
    final mins = paceDecimal.floor();
    final secs = ((paceDecimal - mins) * 60).round();
    return "$mins'${secs.toString().padLeft(2, '0')}\"/km";
  }

  String get durationFormatted {
    final h = myDurationSeconds ~/ 3600;
    final m = (myDurationSeconds % 3600) ~/ 60;
    final s = myDurationSeconds % 60;
    if (h > 0) {
      return '${h}j ${m}m ${s}d';
    }
    return '${m}m ${s}d';
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:runcompete/models/race_event.dart';

void main() {
  group('RaceEvent Retention & Chronological Sorting Tests', () {
    test('Excludes events older than 3 days and retains events within 3 days', () {
      final now = DateTime.now().toUtc();
      final cutoff = now.subtract(const Duration(days: 3));

      final oldEvent = RaceEvent(
        id: 'old-1',
        title: 'Old Race 4 Days Ago',
        description: 'Should be excluded',
        type: 'run',
        distanceKm: 5.0,
        startTimeUtc: now.subtract(const Duration(days: 4)),
        feeUsd: 10.0,
        bannerUrl: 'test',
      );

      final recentEvent = RaceEvent(
        id: 'recent-1',
        title: 'Recent Race 2 Days Ago',
        description: 'Should be retained',
        type: 'run',
        distanceKm: 10.0,
        startTimeUtc: now.subtract(const Duration(days: 2)),
        feeUsd: 10.0,
        bannerUrl: 'test',
      );

      final upcomingEvent = RaceEvent(
        id: 'up-1',
        title: 'Upcoming Race Tomorrow',
        description: 'Should be retained',
        type: 'run',
        distanceKm: 21.1,
        startTimeUtc: now.add(const Duration(days: 1)),
        feeUsd: 15.0,
        bannerUrl: 'test',
      );

      final allEvents = [oldEvent, recentEvent, upcomingEvent];

      final filtered = allEvents.where((e) => !e.startTimeUtc.isBefore(cutoff)).toList();

      expect(filtered.length, equals(2));
      expect(filtered.any((e) => e.id == 'old-1'), isFalse);
      expect(filtered.any((e) => e.id == 'recent-1'), isTrue);
      expect(filtered.any((e) => e.id == 'up-1'), isTrue);
    });

    test('Sorts nearest upcoming races to the top, followed by recently ended races', () {
      final now = DateTime.now().toUtc();

      final raceIn45Mins = RaceEvent(
        id: 'e-45m',
        title: 'Race In 45 Mins',
        description: '',
        type: 'run',
        distanceKm: 5.0,
        startTimeUtc: now.add(const Duration(minutes: 45)),
        feeUsd: 10.0,
        bannerUrl: 'test',
      );

      final raceIn4Hours = RaceEvent(
        id: 'e-4h',
        title: 'Race In 4 Hours',
        description: '',
        type: 'run',
        distanceKm: 42.2,
        startTimeUtc: now.add(const Duration(hours: 4)),
        feeUsd: 25.0,
        bannerUrl: 'test',
      );

      final raceIn2Days = RaceEvent(
        id: 'e-2d',
        title: 'Race In 2 Days',
        description: '',
        type: 'run',
        distanceKm: 10.0,
        startTimeUtc: now.add(const Duration(days: 2)),
        feeUsd: 12.0,
        bannerUrl: 'test',
      );

      final raceYesterday = RaceEvent(
        id: 'e-yesterday',
        title: 'Race Yesterday (Recent)',
        description: '',
        type: 'run',
        distanceKm: 5.0,
        startTimeUtc: now.subtract(const Duration(days: 1)),
        feeUsd: 10.0,
        bannerUrl: 'test',
      );

      final list = [raceIn2Days, raceYesterday, raceIn4Hours, raceIn45Mins];

      list.sort((a, b) {
        final aIsPast = a.startTimeUtc.isBefore(now);
        final bIsPast = b.startTimeUtc.isBefore(now);
        if (!aIsPast && bIsPast) return -1;
        if (aIsPast && !bIsPast) return 1;
        if (!aIsPast && !bIsPast) {
          return a.startTimeUtc.compareTo(b.startTimeUtc);
        }
        return b.startTimeUtc.compareTo(a.startTimeUtc);
      });

      expect(list[0].id, equals('e-45m')); // 45 menit lagi paling atas
      expect(list[1].id, equals('e-4h'));  // 4 jam lagi kedua
      expect(list[2].id, equals('e-2d'));  // 2 hari lagi ketiga
      expect(list[3].id, equals('e-yesterday')); // Yang baru selesai di bawah
    });
  });
}

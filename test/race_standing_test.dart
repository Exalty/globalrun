import 'package:flutter_test/flutter_test.dart';
import 'package:runcompete/models/race_standing.dart';

void main() {
  group('RaceParticipantEntry Tests', () {
    test('Pace formatting returns correct mm\'ss"/km', () {
      const entry = RaceParticipantEntry(
        rank: 1,
        userId: 'u1',
        userName: 'Atlet A',
        durationSeconds: 1800, // 30 mins
        avgSpeedKmh: 10.0, // 6:00 min/km
        steps: 4500,
      );

      expect(entry.paceFormatted, "6'00\"/km");
      expect(entry.durationFormatted, '30m 0d');
    });

    test('Pace formatting handles 0 kmh safely without division by zero', () {
      const entry = RaceParticipantEntry(
        rank: 2,
        userId: 'u2',
        userName: 'Atlet B',
        durationSeconds: 0,
        avgSpeedKmh: 0.0,
        steps: 0,
      );

      expect(entry.paceFormatted, '-');
      expect(entry.durationFormatted, '0m 0d');
    });

    test('Duration formatting shows hours when >= 3600 seconds', () {
      const entry = RaceParticipantEntry(
        rank: 3,
        userId: 'u3',
        userName: 'Marathoner',
        durationSeconds: 7325, // 2h 2m 5s
        avgSpeedKmh: 12.0,
        steps: 12000,
      );

      expect(entry.durationFormatted, '2j 2m 5d');
    });
  });

  group('MyRaceStanding Tests', () {
    test('Calculates metrics and formats correctly', () {
      final standing = MyRaceStanding(
        eventId: 'ev-1',
        eventTitle: 'Tokyo Marathon 2026',
        distanceKm: 42.2,
        myRank: 1,
        totalParticipants: 10,
        myDurationSeconds: 10800, // 3 hours
        myAvgSpeedKmh: 14.07,
        mySteps: 35000,
        completedAt: DateTime.now(),
      );

      expect(standing.durationFormatted, '3j 0m 0d');
      expect(standing.paceFormatted, isNot('-'));
      expect(standing.myRank, 1);
    });
  });
}

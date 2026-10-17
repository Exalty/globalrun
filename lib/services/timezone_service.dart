import 'package:intl/intl.dart';

class TimezoneModel {
  final String label;
  final String code; // e.g., WIB, WITA, WIT, UTC, GMT, JST, EST
  final int offsetHours;
  final String flag;

  const TimezoneModel({
    required this.label,
    required this.code,
    required this.offsetHours,
    required this.flag,
  });
}

class TimezoneService {
  static const List<TimezoneModel> supportedZones = [
    TimezoneModel(label: 'Indonesia Barat (WIB)', code: 'WIB', offsetHours: 7, flag: '🇮🇩'),
    TimezoneModel(label: 'Indonesia Tengah (WITA)', code: 'WITA', offsetHours: 8, flag: '🇮🇩'),
    TimezoneModel(label: 'Indonesia Timur (WIT)', code: 'WIT', offsetHours: 9, flag: '🇮🇩'),
    TimezoneModel(label: 'London / UTC (GMT)', code: 'GMT', offsetHours: 0, flag: '🇬🇧'),
    TimezoneModel(label: 'Tokyo (JST)', code: 'JST', offsetHours: 9, flag: '🇯🇵'),
    TimezoneModel(label: 'New York (EDT/EST)', code: 'EST', offsetHours: -4, flag: '🇺🇸'),
    TimezoneModel(label: 'Sydney (AEST)', code: 'AEST', offsetHours: 10, flag: '🇦🇺'),
    TimezoneModel(label: 'Dubai (GST)', code: 'GST', offsetHours: 4, flag: '🇦🇪'),
  ];

  static String formatForZone(DateTime utcTime, TimezoneModel zone) {
    final converted = utcTime.toUtc().add(Duration(hours: zone.offsetHours));
    final formatter = DateFormat('EEE, d MMM yyyy • HH:mm');
    return '${formatter.format(converted)} ${zone.code}';
  }

  static String getRelativeCountdown(DateTime utcTime) {
    final now = DateTime.now().toUtc();
    final diff = utcTime.difference(now);

    if (diff.isNegative) {
      final abs = diff.abs();
      if (abs.inMinutes < 60) return 'Dimulai ${abs.inMinutes} mnt lalu';
      if (abs.inHours < 24) return 'Dimulai ${abs.inHours} jam lalu';
      return 'Event Sedang Berlangsung / Selesai';
    }

    if (diff.inDays > 0) {
      return 'Dalam ${diff.inDays} hari ${diff.inHours % 24} jam';
    } else if (diff.inHours > 0) {
      return 'Dalam ${diff.inHours} jam ${diff.inMinutes % 60} mnt';
    } else {
      return 'Dalam ${diff.inMinutes} menit!';
    }
  }
}

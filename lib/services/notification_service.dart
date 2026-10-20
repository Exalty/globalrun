import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final List<AppNotification> _notifications = [];
  bool _isInitialized = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  static const String _prefsKey = 'saved_app_notifications';

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Android Initialization
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Initialization Settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      // Request notification permission on Android 13+
      await _requestAndroidPermissions();

      // Load saved notifications from storage
      await _loadFromPrefs();

      // Seed default initial notifications if first time
      if (_notifications.isEmpty) {
        _seedDefaultNotifications();
        await _saveToPrefs();
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationService init error (graceful fallback): $e');
      _isInitialized = true;
    }
  }

  Future<void> _requestAndroidPermissions() async {
    try {
      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  void _seedDefaultNotifications() {
    _notifications.addAll([
      AppNotification(
        id: 'notif_welcome',
        title: '🏁 Selamat Datang di Global Virtual Race!',
        body: 'Siapkan sepatu lari & GPS Anda. Ikuti Tokyo Virtual Marathon 10K dan raih medali NFT tercatat di Polygon!',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: 'system',
        isRead: false,
      ),
      AppNotification(
        id: 'notif_race_remind',
        title: '⏰ Pengingat: Tokyo Virtual 10K',
        body: 'Flag-off dibuka dalam hitungan jam. Pastikan baterai dan koneksi GPS perangkat Anda dalam kondisi prima!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        type: 'race_reminder',
        isRead: false,
      ),
      AppNotification(
        id: 'notif_ai_coach',
        title: '🤖 AI Coach: Tips Pacing & Hidrasi',
        body: 'Gunakan cadence 160-170 SPM di awal 3 KM pertama untuk menjaga efisiensi energi sebelum tanjakan.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        type: 'ai_coach',
        isRead: false,
      ),
    ]);
  }

  Future<void> showNotification({
    required String title,
    required String body,
    required String type,
    String? payload,
  }) async {
    final newNotif = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
      isRead: false,
      actionPayload: payload,
    );

    _notifications.insert(0, newNotif);
    await _saveToPrefs();
    notifyListeners();

    // Trigger local push notification on device status bar
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'race_channel_high',
        'Global Virtual Race Alerts',
        channelDescription: 'Pemberitahuan jadwal race, flag-off live, dan medali NFT anti-cheat.',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Global Virtual Race Alert',
        playSound: true,
        enableVibration: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      final int notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _localNotifications.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload ?? type,
      );
    } catch (e) {
      debugPrint('Error displaying device push notification: $e');
    }
  }

  Future<void> sendSampleNotification(String sampleType) async {
    switch (sampleType) {
      case 'flag_off':
        await showNotification(
          title: '🚨 FLAG-OFF: Tokyo Virtual 10K Dimulai!',
          body: 'Garis start resmi dibuka! Buka modul pelacak dan mulai lari untuk mencatat waktu terbaikmu.',
          type: 'flag_off',
          payload: 'open_race:1',
        );
        break;
      case 'achievement':
        await showNotification(
          title: '🎉 Finish Terverifikasi & Medali NFT Siap!',
          body: 'Algoritma anti-cheat telah memvalidasi rekaman lari 10 KM Anda. Sertifikat & NFT telah di-mint!',
          type: 'achievement',
          payload: 'open_nft',
        );
        break;
      case 'ai_coach':
        await showNotification(
          title: '🤖 AI Coach: Peringatan Hidrasi & Pace',
          body: 'Pace Anda stabil di 5\'15"/km. Waktunya minum sedikit air dan relakskan bahu Anda.',
          type: 'ai_coach',
        );
        break;
      case 'race_reminder':
      default:
        await showNotification(
          title: '⏰ Pengingat Race: 15 Menit Menuju Start',
          body: 'Lakukan pemanasan dinamis 10 menit. Flag-off Jakarta Night Run 5K segera dimulai!',
          type: 'race_reminder',
          payload: 'open_race:2',
        );
        break;
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      await _saveToPrefs();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n.isRead = true;
    }
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList(_prefsKey);
      if (savedList != null && savedList.isNotEmpty) {
        _notifications.clear();
        for (var str in savedList) {
          _notifications.add(AppNotification.fromJson(str));
        }
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = _notifications.map((n) => n.toJson()).toList();
      await prefs.setStringList(_prefsKey, stringList);
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }
}

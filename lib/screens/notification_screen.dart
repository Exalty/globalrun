import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_notification.dart';
import '../models/race_event.dart';
import '../services/notification_service.dart';
import '../services/blockchain_service.dart';
import '../services/ai_coach_service.dart';
import '../services/event_service.dart';
import '../services/timezone_service.dart';
import '../services/currency_service.dart';
import '../theme/duo_theme.dart';
import 'active_race_screen.dart';
import 'ai_coach_screen.dart';
import 'blockchain_certificate_screen.dart';

class NotificationScreen extends StatefulWidget {
  final BlockchainService? blockchainService;
  final AiCoachService? aiCoachService;

  const NotificationScreen({
    super.key,
    this.blockchainService,
    this.aiCoachService,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  String _selectedFilter = 'all'; // 'all', 'race', 'ai_coach', 'achievement'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final events = context.read<EventService>().events;
        _notificationService.syncWithLiveEvents(events);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    final eventService = context.watch<EventService>();

    return AnimatedBuilder(
      animation: _notificationService,
      builder: (context, _) {
        final allNotifs = _notificationService.notifications;
        final filteredNotifs = allNotifs.where((n) {
          if (_selectedFilter == 'all') return true;
          if (_selectedFilter == 'race') {
            return n.type == 'race_reminder' || n.type == 'flag_off';
          }
          if (_selectedFilter == 'ai_coach') {
            return n.type == 'ai_coach';
          }
          if (_selectedFilter == 'achievement') {
            return n.type == 'achievement';
          }
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            backgroundColor: palette.surface,
            elevation: 0,
            shape: Border(bottom: BorderSide(color: palette.surfaceBorder, width: 2)),
            title: Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: palette.primaryBlue, size: 24),
                const SizedBox(width: 10),
                Text(
                  'NOTIFIKASI LOMBA',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    fontSize: 16,
                    color: palette.textPrimary,
                  ),
                ),
                if (_notificationService.unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: DuoColors.heartRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_notificationService.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (allNotifs.isNotEmpty)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: palette.textSecondary),
                  color: palette.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: palette.surfaceBorder, width: 1.5),
                  ),
                  onSelected: (val) {
                    if (val == 'mark_all_read') {
                      _notificationService.markAllAsRead();
                      _showToast('Semua notifikasi ditandai sudah dibaca', palette);
                    } else if (val == 'clear_all') {
                      _showClearConfirmation(palette);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'mark_all_read',
                      child: Row(
                        children: [
                          Icon(Icons.done_all_rounded, color: palette.primaryBlue, size: 18),
                          const SizedBox(width: 8),
                          Text('Tandai Semua Dibaca', style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep_rounded, color: DuoColors.heartRed, size: 18),
                          SizedBox(width: 8),
                          Text('Hapus Semua', style: TextStyle(color: DuoColors.heartRed, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Panel Uji Coba Simulasi Notifikasi Push (Live Event Integrated)
              _buildSimulationCard(palette, eventService),
              const SizedBox(height: 16),

              // Filter Chips Duolingo Style
              _buildFilterChips(palette),
              const SizedBox(height: 16),

              // Daftar Notifikasi
              if (filteredNotifs.isEmpty)
                _buildEmptyState(palette)
              else
                ...filteredNotifs.map((notif) => _buildNotificationCard(notif, eventService, palette)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimulationCard(DuoColorPalette palette, EventService eventService) {
    final liveEvent = eventService.events.isNotEmpty ? eventService.events.first : null;
    final eventName = liveEvent?.title ?? 'Tokyo Marathon 2026';

    return DuoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: palette.primaryBlue.withOpacity(palette.isDark ? 0.20 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.primaryBlue, width: 1.5),
                ),
                child: Icon(Icons.touch_app_rounded, color: palette.primaryBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UJI COBA NOTIFIKASI LIVE EVENT',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Terkoneksi ke: $eventName',
                      style: TextStyle(color: palette.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _build3DActionButton(
                icon: Icons.sports_score_rounded,
                label: 'FLAG-OFF MULAI',
                bgColor: DuoColors.streakGold,
                shadowColor: DuoColors.streakGoldShadow,
                textColor: Colors.black,
                onTap: () {
                  _notificationService.sendSampleNotification('flag_off', event: liveEvent);
                  _showToast('Notifikasi Flag-off terkirim untuk $eventName', palette);
                },
              ),
              _build3DActionButton(
                icon: Icons.military_tech_rounded,
                label: 'FINIS & MEDALI NFT',
                bgColor: palette.neonCyan,
                shadowColor: palette.neonCyanShadow,
                textColor: Colors.black,
                onTap: () {
                  _notificationService.sendSampleNotification('achievement', event: liveEvent);
                  _showToast('Notifikasi Medali NFT terkirim', palette);
                },
              ),
              _build3DActionButton(
                icon: Icons.psychology_rounded,
                label: 'AI COACH ADVICE',
                bgColor: DuoColors.questGreen,
                shadowColor: DuoColors.questGreenShadow,
                textColor: Colors.white,
                onTap: () {
                  _notificationService.sendSampleNotification('ai_coach', event: liveEvent);
                  _showToast('Notifikasi AI Coach terkirim', palette);
                },
              ),
              _build3DActionButton(
                icon: Icons.alarm_rounded,
                label: 'PENGINGAT 15 MENIT',
                bgColor: palette.primaryBlue,
                shadowColor: palette.primaryBlueShadow,
                textColor: Colors.white,
                onTap: () {
                  _notificationService.sendSampleNotification('race_reminder', event: liveEvent);
                  _showToast('Pengingat jadwal live terkirim', palette);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _build3DActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color shadowColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(DuoColorPalette palette) {
    final filters = [
      {'key': 'all', 'label': 'SEMUA', 'icon': Icons.notifications_rounded},
      {'key': 'race', 'label': 'RACE & FLAG-OFF', 'icon': Icons.directions_run_rounded},
      {'key': 'ai_coach', 'label': 'AI COACH', 'icon': Icons.psychology_rounded},
      {'key': 'achievement', 'label': 'MEDALI NFT', 'icon': Icons.military_tech_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DuoChip(
              icon: Icon(
                f['icon'] as IconData,
                color: isSelected ? palette.primaryBlue : palette.textSecondary,
                size: 14,
              ),
              label: f['label'] as String,
              backgroundColor: isSelected ? palette.primaryBlue.withOpacity(palette.isDark ? 0.22 : 0.14) : palette.surface,
              borderColor: isSelected ? palette.primaryBlue : palette.surfaceBorder,
              textColor: isSelected ? palette.primaryBlue : palette.textSecondary,
              onTap: () {
                setState(() {
                  _selectedFilter = f['key'] as String;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationCard(
    AppNotification notif,
    EventService eventService,
    DuoColorPalette palette,
  ) {
    Color iconColor;
    Color iconShadow;
    IconData iconData;
    String badgeText;

    switch (notif.type) {
      case 'flag_off':
        iconColor = DuoColors.streakGold;
        iconShadow = DuoColors.streakGoldShadow;
        iconData = Icons.sports_score_rounded;
        badgeText = 'FLAG-OFF';
        break;
      case 'achievement':
        iconColor = palette.neonCyan;
        iconShadow = palette.neonCyanShadow;
        iconData = Icons.military_tech_rounded;
        badgeText = 'MEDALI NFT';
        break;
      case 'ai_coach':
        iconColor = DuoColors.questGreen;
        iconShadow = DuoColors.questGreenShadow;
        iconData = Icons.psychology_rounded;
        badgeText = 'AI COACH';
        break;
      case 'race_reminder':
        iconColor = palette.primaryBlue;
        iconShadow = palette.primaryBlueShadow;
        iconData = Icons.alarm_rounded;
        badgeText = 'JADWAL LIVE';
        break;
      default:
        iconColor = palette.primaryBlue;
        iconShadow = palette.primaryBlueShadow;
        iconData = Icons.info_outline_rounded;
        badgeText = 'SISTEM';
        break;
    }

    final formattedTime = DateFormat('dd MMM, HH:mm').format(notif.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DuoCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _handleNotificationTap(notif, eventService, palette),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3D Avatar/Icon container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(palette.isDark ? 0.20 : 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: iconShadow.withOpacity(0.4),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: iconColor.withOpacity(0.5), width: 1),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            formattedTime,
                            style: TextStyle(color: palette.textMuted, fontSize: 11),
                          ),
                          if (!notif.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: palette.primaryBlue,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.primaryBlueShadow,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif.title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: notif.isRead ? FontWeight.w700 : FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Menghubungkan klik notifikasi ke detail yang sesuai
  void _handleNotificationTap(
    AppNotification notif,
    EventService eventService,
    DuoColorPalette palette,
  ) {
    _notificationService.markAsRead(notif.id);

    final payload = notif.actionPayload ?? '';

    // 1. Notifikasi Medali NFT / Pencapaian
    if (notif.type == 'achievement' || payload == 'open_nft') {
      final bcService = widget.blockchainService ?? BlockchainService();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlockchainCertificateScreen(
            blockchainService: bcService,
          ),
        ),
      );
      return;
    }

    // 2. Notifikasi AI Coach / Tips Lari
    if (notif.type == 'ai_coach' || payload.contains('ai_coach')) {
      final coachService = widget.aiCoachService ?? AiCoachService();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiCoachScreen(
            coachService: coachService,
          ),
        ),
      );
      return;
    }

    // 3. Notifikasi Race / Jadwal / Flag-off
    if (notif.type == 'race_reminder' || notif.type == 'flag_off' || payload.startsWith('open_race:')) {
      String? targetEventId;
      if (payload.startsWith('open_race:')) {
        targetEventId = payload.replaceFirst('open_race:', '').trim();
      }

      RaceEvent? matchedEvent;
      if (targetEventId != null && targetEventId.isNotEmpty) {
        matchedEvent = eventService.events.cast<RaceEvent?>().firstWhere(
              (e) => e?.id == targetEventId,
              orElse: () => null,
            );
      }

      // Cari kecocokan judul jika belum ditemukan via ID
      matchedEvent ??= eventService.events.cast<RaceEvent?>().firstWhere(
            (e) =>
                e != null &&
                (notif.title.toLowerCase().contains(e.title.toLowerCase()) ||
                    notif.body.toLowerCase().contains(e.title.toLowerCase())),
            orElse: () => eventService.events.isNotEmpty ? eventService.events.first : null,
          );

      if (matchedEvent != null) {
        _showRaceDetailModal(matchedEvent, notif, palette);
        return;
      }
    }

    // 4. Notifikasi Sistem / Pengumuman Umum
    _showGeneralNotificationModal(notif, palette);
  }

  /// Menampilkan modal detail lomba interaktif saat notifikasi race ditekan
  void _showRaceDetailModal(
    RaceEvent event,
    AppNotification notif,
    DuoColorPalette palette,
  ) {
    final currencyService = context.read<CurrencyService>();
    final timezoneService = context.read<TimezoneService>();
    final selectedTimezone = timezoneService.selectedTimezone;
    final selectedCurrency = currencyService.selectedCurrency;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: palette.surfaceBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Notifikasi Banner Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: palette.primaryBlue.withOpacity(palette.isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.primaryBlue.withOpacity(0.4), width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notifications_active_rounded, color: palette.primaryBlue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif.title,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              notif.body,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Header Info: Type & Distance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (event.type == 'run' ? palette.primaryBlue : DuoColors.streakGold)
                            .withOpacity(palette.isDark ? 0.20 : 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: event.type == 'run' ? palette.primaryBlue : DuoColors.streakGold,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            event.type == 'run' ? Icons.directions_run_rounded : Icons.directions_bike_rounded,
                            size: 15,
                            color: event.type == 'run' ? palette.primaryBlue : DuoColors.streakGold,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            event.type == 'run' ? 'MARATHON RUN' : 'CYCLING RACE',
                            style: TextStyle(
                              color: event.type == 'run' ? palette.primaryBlue : DuoColors.streakGold,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.surfaceBorder),
                      ),
                      child: Text(
                        '${event.distanceKm} KM',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Judul Lomba
                Text(
                  event.title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),

                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: DuoColors.streakGold, size: 16),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Kotak Deskripsi Lomba
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.surfaceBorder, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notes_rounded, size: 15, color: palette.primaryBlue),
                          const SizedBox(width: 6),
                          Text(
                            'DESKRIPSI LOMBA',
                            style: TextStyle(
                              color: palette.textMuted,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.description.isNotEmpty
                            ? event.description
                            : 'Tidak ada deskripsi rinci untuk event ini.',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Info Jadwal & Biaya
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.surfaceBorder, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('JADWAL START (${selectedTimezone.code})',
                              style: TextStyle(color: palette.textMuted, fontWeight: FontWeight.w900, fontSize: 10)),
                          const SizedBox(height: 4),
                          Text(
                            timezoneService.formatForZone(event.startTimeUtc, selectedTimezone),
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('BIAYA ($selectedCurrency)',
                              style: TextStyle(color: palette.textMuted, fontWeight: FontWeight.w900, fontSize: 10)),
                          const SizedBox(height: 4),
                          Text(
                            currencyService.formatCurrency(event.feeUsd, selectedCurrency),
                            style: const TextStyle(color: DuoColors.questGreen, fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tombol Aksi Langsung
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActiveRaceScreen(
                            event: event,
                            blockchainService: widget.blockchainService ?? BlockchainService(),
                            aiCoachService: widget.aiCoachService ?? AiCoachService(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text('Mulai Race Virtual Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Konsultasi ke Rani AI Coach
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AiCoachScreen(
                            coachService: widget.aiCoachService ?? AiCoachService(),
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.psychology_rounded, size: 18, color: palette.primaryBlue),
                    label: const Text('Konsultasi Strategi ke Rani (AI Coach)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primaryBlue,
                      side: BorderSide(color: palette.primaryBlue, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ),

                if (event.officialUrl != null && event.officialUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(event.officialUrl!);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Tidak dapat membuka link: ${event.officialUrl}')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.public_rounded, size: 18),
                      label: const Text('Buka Website Resmi Lomba'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DuoColors.streakGold,
                        side: const BorderSide(color: DuoColors.streakGold, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Menampilkan modal rincian notifikasi umum/sistem
  void _showGeneralNotificationModal(
    AppNotification notif,
    DuoColorPalette palette,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final formattedDate = DateFormat('dd MMMM yyyy, HH:mm').format(notif.timestamp);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: palette.surfaceBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.primaryBlue.withOpacity(palette.isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.primaryBlue, width: 1.5),
                      ),
                      child: Text(
                        'PEMBERITAHUAN SISTEM',
                        style: TextStyle(
                          color: palette.primaryBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(color: palette.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  notif.title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.surfaceBorder, width: 1.5),
                  ),
                  child: Text(
                    notif.body,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(DuoColorPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.notifications_none_rounded, color: palette.textMuted, size: 64),
          const SizedBox(height: 12),
          Text(
            'BELUM ADA NOTIFIKASI',
            style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Notifikasi event race & AI Coach akan muncul di sini.',
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(DuoColorPalette palette) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.surfaceBorder, width: 2),
        ),
        title: Text(
          'Hapus Semua Notifikasi?',
          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Semua riwayat notifikasi akan dihapus dari perangkat.',
          style: TextStyle(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: palette.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _notificationService.clearAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DuoColors.heartRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showToast(String message, DuoColorPalette palette) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: palette.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.surfaceBorder, width: 1.5),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

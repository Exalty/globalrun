import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../services/blockchain_service.dart';
import '../services/event_service.dart';
import '../theme/duo_theme.dart';
import 'blockchain_certificate_screen.dart';

class NotificationScreen extends StatefulWidget {
  final BlockchainService? blockchainService;

  const NotificationScreen({
    super.key,
    this.blockchainService,
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
                ...filteredNotifs.map((notif) => _buildNotificationCard(notif, palette)),
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
                label: '🏁 FLAG-OFF MULAI',
                bgColor: DuoColors.streakGold,
                shadowColor: DuoColors.streakGoldShadow,
                textColor: Colors.black,
                onTap: () {
                  _notificationService.sendSampleNotification('flag_off', event: liveEvent);
                  _showToast('Notifikasi Flag-off terkirim untuk $eventName', palette);
                },
              ),
              _build3DActionButton(
                label: '🏆 FINIS & MEDALI NFT',
                bgColor: palette.neonCyan,
                shadowColor: palette.neonCyanShadow,
                textColor: Colors.black,
                onTap: () {
                  _notificationService.sendSampleNotification('achievement', event: liveEvent);
                  _showToast('Notifikasi Medali NFT terkirim', palette);
                },
              ),
              _build3DActionButton(
                label: '🤖 AI COACH ADVICE',
                bgColor: DuoColors.questGreen,
                shadowColor: DuoColors.questGreenShadow,
                textColor: Colors.white,
                onTap: () {
                  _notificationService.sendSampleNotification('ai_coach', event: liveEvent);
                  _showToast('Notifikasi AI Coach terkirim', palette);
                },
              ),
              _build3DActionButton(
                label: '⏰ PENGINGAT 15 MENIT',
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
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
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

  Widget _buildNotificationCard(AppNotification notif, DuoColorPalette palette) {
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
        onTap: () {
          _notificationService.markAsRead(notif.id);
          if (notif.actionPayload == 'open_nft' && widget.blockchainService != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlockchainCertificateScreen(
                  blockchainService: widget.blockchainService!,
                ),
              ),
            );
          }
        },
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

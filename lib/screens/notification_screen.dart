import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../services/blockchain_service.dart';
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
  Widget build(BuildContext context) {
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
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
            title: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Colors.cyanAccent),
                const SizedBox(width: 10),
                const Text('Pusat Notifikasi Mobile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                if (_notificationService.unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_notificationService.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (allNotifs.isNotEmpty)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                  color: const Color(0xFF1E293B),
                  onSelected: (val) {
                    if (val == 'mark_all_read') {
                      _notificationService.markAllAsRead();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Semua notifikasi ditandai sudah dibaca'),
                          backgroundColor: Colors.cyan,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else if (val == 'clear_all') {
                      _showClearConfirmation();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'mark_all_read',
                      child: Row(
                        children: [
                          Icon(Icons.done_all_rounded, color: Colors.cyanAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Tandai Semua Dibaca', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Hapus Semua', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
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
              // Panel Simulasi Notifikasi Push (Interactive Concept Demonstration)
              _buildSimulationCard(),
              const SizedBox(height: 16),

              // Filter Chips
              _buildFilterChips(),
              const SizedBox(height: 16),

              // Daftar Notifikasi
              if (filteredNotifs.isEmpty)
                _buildEmptyState()
              else
                ...filteredNotifs.map((notif) => _buildNotificationCard(notif)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimulationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.touch_app_rounded, color: Colors.cyanAccent, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uji Coba Push Notifikasi Mobile',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Ketuk untuk memicu notifikasi bar HP sesuai skenario SRS',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(
                label: '🏁 Flag-Off Mulai',
                color: Colors.amberAccent,
                onTap: () {
                  _notificationService.sendSampleNotification('flag_off');
                  _showToast('Notifikasi Flag-Off dikirim ke status bar HP');
                },
              ),
              _buildActionButton(
                label: '🏆 Finis & Medali NFT',
                color: Colors.purpleAccent,
                onTap: () {
                  _notificationService.sendSampleNotification('achievement');
                  _showToast('Notifikasi Finish NFT dikirim ke status bar HP');
                },
              ),
              _buildActionButton(
                label: '🤖 AI Coach Advice',
                color: Colors.greenAccent,
                onTap: () {
                  _notificationService.sendSampleNotification('ai_coach');
                  _showToast('Notifikasi AI Coach dikirim ke status bar HP');
                },
              ),
              _buildActionButton(
                label: '⏰ Pengingat 15 Menit',
                color: Colors.cyanAccent,
                onTap: () {
                  _notificationService.sendSampleNotification('race_reminder');
                  _showToast('Notifikasi Jadwal dikirim ke status bar HP');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'Semua'},
      {'key': 'race', 'label': '🏃 Race & Flag-Off'},
      {'key': 'ai_coach', 'label': '🤖 AI Coach'},
      {'key': 'achievement', 'label': '🏆 Medali NFT'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedFilter = f['key']!;
                  });
                }
              },
              backgroundColor: const Color(0xFF1E293B),
              selectedColor: Colors.cyanAccent,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? Colors.cyanAccent : Colors.white12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notif) {
    Color iconColor;
    IconData iconData;
    String badgeText;

    switch (notif.type) {
      case 'flag_off':
        iconColor = Colors.amberAccent;
        iconData = Icons.sports_score_rounded;
        badgeText = 'FLAG-OFF';
        break;
      case 'achievement':
        iconColor = Colors.purpleAccent;
        iconData = Icons.military_tech_rounded;
        badgeText = 'MEDALI NFT';
        break;
      case 'ai_coach':
        iconColor = Colors.greenAccent;
        iconData = Icons.psychology_rounded;
        badgeText = 'AI COACH';
        break;
      case 'race_reminder':
        iconColor = Colors.cyanAccent;
        iconData = Icons.alarm_rounded;
        badgeText = 'JADWAL';
        break;
      default:
        iconColor = Colors.blueAccent;
        iconData = Icons.info_outline_rounded;
        badgeText = 'SISTEM';
        break;
    }

    final formattedTime = DateFormat('dd MMM, HH:mm').format(notif.timestamp);

    return InkWell(
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? const Color(0xFF1E293B) : const Color(0xFF192A45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notif.isRead ? Colors.white10 : Colors.cyanAccent.withOpacity(0.4),
            width: notif.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: iconColor, size: 24),
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
                          color: iconColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            formattedTime,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                          if (!notif.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.cyanAccent,
                                shape: BoxShape.circle,
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
                      color: Colors.white,
                      fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.notifications_none_rounded, color: Colors.white24, size: 64),
          const SizedBox(height: 12),
          const Text(
            'Belum Ada Notifikasi',
            style: TextStyle(color: Colors.white60, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Notifikasi event race & AI Coach akan muncul di sini.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Semua Notifikasi?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Semua riwayat notifikasi akan dihapus dari perangkat.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _notificationService.clearAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

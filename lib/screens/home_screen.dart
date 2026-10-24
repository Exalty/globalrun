import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/race_event.dart';
import '../models/run_record.dart';
import '../services/timezone_service.dart';
import '../services/currency_service.dart';
import '../services/blockchain_service.dart';
import '../services/ai_coach_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/event_service.dart';
import '../services/run_history_service.dart';
import '../services/payment_service.dart';
import 'active_race_screen.dart';
import 'blockchain_certificate_screen.dart';
import 'notification_screen.dart';
import 'run_summary_screen.dart';
import 'topup_screen.dart';
import '../theme/duo_theme.dart';

class HomeScreen extends StatefulWidget {
  final BlockchainService blockchainService;
  final AiCoachService aiCoachService;

  const HomeScreen({
    super.key,
    required this.blockchainService,
    required this.aiCoachService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NotificationService _notificationService = NotificationService();

  // Pencarian dan Filter Kategori
  String _searchQuery = '';
  String _selectedCategory = 'all'; // 'all', 'run', 'cycling'
  final TextEditingController _searchController = TextEditingController();

  // Partisi List Event (10 event per partisi)
  int _currentPartition = 0;
  static const int _eventsPerPage = 10;

  // Saldo Dompet Atlet & Pengaturan Sembunyikan Saldo
  double _userWalletUsd = 250.0;
  bool _isBalanceHidden = false;
  static const String _prefHideBalance = 'pref_hide_home_balance';

  // Lari yang sudah pernah diikuti per event (eventId -> RunRecord terbaru),
  // baik yang selesai maupun yang dihentikan di tengah.
  Map<String, RunRecord> _completedRuns = {};

  // Diatur terpusat di RunHistoryService.oneAttemptPerRace
  // (true = 1 race hanya sekali, false = boleh mengulang saat testing)
  static const bool _oneAttemptPerRace = RunHistoryService.oneAttemptPerRace;

  Future<void> _loadCompletedRuns() async {
    try {
      final map = await RunHistoryService().attemptsByEvent();
      if (mounted) setState(() => _completedRuns = map);
    } catch (_) {}
  }

  Future<void> _loadWalletAndPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = await AuthService().getUserProfile();
      if (mounted) {
        setState(() {
          _userWalletUsd = (profile['wallet'] as num?)?.toDouble() ?? 250.0;
          _isBalanceHidden = prefs.getBool(_prefHideBalance) ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleBalanceVisibility() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isBalanceHidden = !_isBalanceHidden;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefHideBalance, _isBalanceHidden);
    } catch (_) {}
  }

  List<RaceEvent> _getFilteredEvents(List<RaceEvent> allEvents) {
    return allEvents.where((e) {
      final query = _searchQuery.toLowerCase();
      final matchesQuery = e.title.toLowerCase().contains(query) ||
          e.description.toLowerCase().contains(query) ||
          (e.location?.toLowerCase().contains(query) ?? false);
      final matchesCategory = _selectedCategory == 'all' || e.type == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadWalletAndPrefs();
    _loadCompletedRuns();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final eventService = context.read<EventService>();
        eventService.fetchEvents().then((_) {
          if (mounted) {
            _notificationService.syncWithLiveEvents(eventService.events);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────── PEMBAYARAN ENTRY (SIMULASI) ─────────────────────────

  void _openRace(RaceEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveRaceScreen(
          event: event,
          blockchainService: widget.blockchainService,
          aiCoachService: widget.aiCoachService,
        ),
      ),
    ).then((_) {
      _loadCompletedRuns();
      _loadWalletAndPrefs();
    });
  }

  Widget _payRow(String label, String value, DuoColorPalette palette,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: palette.textMuted, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? palette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// Gratis / sudah dibayar -> langsung race. Selain itu: konfirmasi,
  /// potong saldo, lalu mulai. Saldo kurang -> tawarkan Top Up.
  Future<void> _startRaceWithPayment(RaceEvent event) async {
    final palette = DuoColors.of(context);
    final currency = context.read<CurrencyService>();
    final code = currency.selectedCurrency;
    final payment = PaymentService();
    final eventId = event.id.toString();
    final fee = event.feeUsd.toDouble();

    if (fee <= 0 || await payment.isPaid(eventId)) {
      if (mounted) _openRace(event);
      return;
    }

    final balance = await AuthService().getWalletUsd();
    if (!mounted) return;
    final enough = balance >= fee;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.surfaceBorder, width: 2),
        ),
        title: Text(
          'Konfirmasi Pembayaran',
          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            _payRow('Biaya pendaftaran', currency.formatCurrency(fee, code), palette,
                valueColor: DuoColors.questGreen),
            _payRow('Saldo kamu', currency.formatCurrency(balance, code), palette),
            if (enough)
              _payRow('Sisa saldo', currency.formatCurrency(balance - fee, code), palette)
            else ...[
              const SizedBox(height: 8),
              const Text(
                'Saldo tidak cukup. Top up dulu untuk mendaftar race ini.',
                style: TextStyle(
                  color: DuoColors.heartRed,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Pembayaran bersifat simulasi.',
              style: TextStyle(color: palette.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: TextStyle(color: palette.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, enough ? 'pay' : 'topup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: enough ? palette.primaryBlue : DuoColors.streakGold,
              foregroundColor: enough ? Colors.white : Colors.black,
            ),
            child: Text(
              enough ? 'Bayar & Mulai' : 'Top Up Saldo',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;

    if (choice == 'topup') {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const TopUpScreen()),
      );
      await _loadWalletAndPrefs();
      return;
    }

    final result = await payment.payEntryFee(
      eventId: eventId,
      eventTitle: event.title,
      feeUsd: fee,
    );
    if (!mounted) return;
    await _loadWalletAndPrefs(); // chip saldo di atas langsung terbarui
    if (!mounted) return;

    if (result == PayResult.insufficient) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saldo tidak cukup. Silakan top up terlebih dahulu.'),
          backgroundColor: DuoColors.heartRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (result == PayResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pembayaran ${currency.formatCurrency(fee, code)} berhasil!'),
          backgroundColor: DuoColors.questGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _openRace(event);
  }

  void _showEventDetailModal(RaceEvent event) {
    final palette = DuoColors.of(context);
    final currencyService = context.read<CurrencyService>();
    final timezoneService = context.read<TimezoneService>();
    final selectedTimezone = timezoneService.selectedTimezone;
    final selectedCurrency = currencyService.selectedCurrency;

    // Jika sudah pernah menyelesaikan race ini, simpan hasilnya di sini
    final RunRecord? doneRun =
        _oneAttemptPerRace ? _completedRuns[event.id.toString()] : null;

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
                // Drag Handle
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

                // Header: Type Tag & Distance
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

                // Title
                Text(
                  event.title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),

                // Location
                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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

                // Description Box (Prominently displayed)
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

                // Timezone conversion & Countdown Box
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
                          Icon(Icons.schedule_rounded, size: 15, color: palette.primaryBlue),
                          const SizedBox(width: 6),
                          Text(
                            'JADWAL START (${selectedTimezone.code})',
                            style: TextStyle(
                              color: palette.textMuted,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timezoneService.formatForZone(event.startTimeUtc, selectedTimezone),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 13, color: DuoColors.streakGold),
                          const SizedBox(width: 4),
                          Text(
                            'Hitung mundur: ${TimezoneService.getRelativeCountdown(event.startTimeUtc)}',
                            style: const TextStyle(
                              color: DuoColors.streakGold,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Fee Box
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
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_rounded, size: 15, color: DuoColors.questGreen),
                              const SizedBox(width: 6),
                              Text(
                                'BIAYA PENDAFTARAN',
                                style: TextStyle(
                                  color: palette.textMuted,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mata uang: $selectedCurrency',
                            style: TextStyle(color: palette.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                      Text(
                        currencyService.formatCurrency(event.feeUsd, selectedCurrency),
                        style: const TextStyle(
                          color: DuoColors.questGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                if (event.officialUrl != null && event.officialUrl!.isNotEmpty) ...[
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
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _notificationService.showNotification(
                        title: 'Pengingat Disetel: ${event.title}',
                        body: 'Notifikasi akan dikirim 15 menit sebelum flag-off (${timezoneService.formatForZone(event.startTimeUtc, selectedTimezone)}).',
                        type: 'race_reminder',
                        payload: 'open_race:${event.id}',
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Pengingat mobile untuk ${event.title} telah aktif!'),
                          backgroundColor: palette.primaryBlue,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.alarm_add_rounded, size: 18),
                    label: const Text('Setel Pengingat Mobile (15 Menit Sebelum Start)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primaryBlue,
                      side: BorderSide(color: palette.primaryBlue, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Sudah selesai -> tampilkan hasil. Belum -> tombol mulai race.
                if (doneRun != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: DuoColors.questGreen.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DuoColors.questGreen, width: 1.5),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: DuoColors.questGreen, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kamu sudah mengikuti race ini. Race hanya bisa diikuti sekali.',
                            style: TextStyle(
                              color: DuoColors.questGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RunSummaryScreen(
                              record: doneRun,
                              blockchainService: widget.blockchainService,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.emoji_events_rounded, size: 22),
                      label: const Text('Lihat Hasil Lari Saya'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DuoColors.questGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startRaceWithPayment(event);
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
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    // Consume providers — rebuild otomatis saat currency/timezone/event berubah
    final currencyService = context.watch<CurrencyService>();
    final timezoneService = context.watch<TimezoneService>();
    final eventService = context.watch<EventService>();
    final selectedTimezone = timezoneService.selectedTimezone;
    final selectedCurrency = currencyService.selectedCurrency;
    final filteredEvents = _getFilteredEvents(eventService.events);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.directions_run_rounded, color: DuoColors.primaryBlue, size: 28),
            const SizedBox(width: 8),
            Text(
              'GLOBAL RUN',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 18, color: palette.textPrimary),
            ),
          ],
        ),
        backgroundColor: palette.surface,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: palette.surfaceBorder, width: 2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.military_tech_rounded, color: Colors.cyanAccent),
            tooltip: 'Blockchain Medals NFT',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlockchainCertificateScreen(
                    blockchainService: widget.blockchainService,
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _notificationService,
            builder: (context, _) {
              final unread = _notificationService.unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_rounded, color: palette.textPrimary),
                    tooltip: 'Notifikasi Mobile',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationScreen(
                            blockchainService: widget.blockchainService,
                            aiCoachService: widget.aiCoachService,
                          ),
                        ),
                      );
                    },
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: DuoColors.heartRed,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            eventService.fetchEvents(forceRefresh: true),
            _loadWalletAndPrefs(),
            _loadCompletedRuns(),
          ]);
        },
        color: palette.primaryBlue,
        backgroundColor: palette.surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Duolingo Top Gamification Chips Bar (Clean Material Icons)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    DuoChip(
                      icon: const Icon(Icons.local_fire_department_rounded, color: DuoColors.streakGold, size: 16),
                      label: '5 HARI',
                      borderColor: DuoColors.streakGoldShadow,
                      backgroundColor: palette.surface,
                      textColor: DuoColors.streakGold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Builder(
                            builder: (context) {
                              final rate = currencyService.currencies[selectedCurrency] ?? currencyService.currencies['USD']!;
                              final balanceFormatted = currencyService.formatCurrency(_userWalletUsd, selectedCurrency);
                              final balanceDisplay = _isBalanceHidden ? '${rate.symbol} ••••••' : balanceFormatted;
                              return DuoChip(
                                icon: const Icon(Icons.account_balance_wallet_rounded, color: DuoColors.primaryBlue, size: 16),
                                label: balanceDisplay,
                                trailing: Icon(
                                  _isBalanceHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: DuoColors.primaryBlue.withOpacity(0.75),
                                  size: 14,
                                ),
                                borderColor: DuoColors.primaryBlueShadow,
                                backgroundColor: palette.surface,
                                textColor: DuoColors.primaryBlue,
                                onTap: _toggleBalanceVisibility,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DuoChip(
                      icon: Icon(Icons.public_rounded, color: palette.textPrimary, size: 16),
                      label: selectedTimezone.code,
                      borderColor: palette.surfaceBorder,
                      backgroundColor: palette.surface,
                      textColor: palette.textPrimary,
                    ),
                  ],
                ),
              ),

              // Quick Global Converters Card (Timezone & Currency)
              DuoCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.public_rounded, color: palette.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sinkronisasi Global Lintas Negara',
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        // Tombol refresh kurs dari API
                        if (currencyService.isLoading || timezoneService.isLoading)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: palette.primaryBlue,
                            ),
                          )
                        else
                          InkWell(
                            onTap: () async {
                              await currencyService.fetchRatesFromApi();
                              await timezoneService.fetchTimezonesFromApi();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          currencyService.hasApiData ? Icons.check_circle : Icons.warning_rounded,
                                          color: currencyService.hasApiData ? Colors.greenAccent : Colors.orangeAccent,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            currencyService.hasApiData
                                                ? 'Kurs & zona waktu berhasil diperbarui dari API!'
                                                : 'Gagal memperbarui. Menggunakan data fallback.',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF1E293B),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: currencyService.hasApiData ? Colors.greenAccent : Colors.orangeAccent,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // API status badge
                    if (currencyService.hasApiData && currencyService.lastUpdated != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Data API real-time • ${currencyService.getRateLabel(selectedCurrency)}',
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 10),
                            ),
                          ],
                        ),
                      )
                    else if (currencyService.lastError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.orangeAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Mode offline (fallback rates)',
                              style: TextStyle(color: Colors.orangeAccent, fontSize: 10),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // Timezone Selector
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Zona Waktu:', style: TextStyle(color: palette.textMuted, fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: palette.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: palette.surfaceBorder, width: 1.5),
                                ),
                                child: DropdownButton<TimezoneModel>(
                                  isExpanded: true,
                                  value: selectedTimezone,
                                  dropdownColor: palette.surface,
                                  underline: const SizedBox(),
                                  style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                  items: timezoneService.supportedZones.map((z) {
                                    return DropdownMenuItem(
                                      value: z,
                                      child: Text('${z.code} (${z.offsetHours >= 0 ? "+" : ""}${z.offsetHours})', overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) timezoneService.setSelectedTimezone(val);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Currency Selector
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mata Uang:', style: TextStyle(color: palette.textMuted, fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: palette.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: palette.surfaceBorder, width: 1.5),
                                ),
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: selectedCurrency,
                                  dropdownColor: palette.surface,
                                  underline: const SizedBox(),
                                  style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                  items: currencyService.currencies.keys.map((c) {
                                    return DropdownMenuItem(
                                      value: c,
                                      child: Text('$c (${currencyService.currencies[c]!.symbol})'),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) currencyService.setSelectedCurrency(val);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Fasilitas Pencarian Lomba (Search Bar - Duo 3D)
              DuoCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPartition = 0;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari lomba (misal: Tokyo, 5K, Fun Run)...',
                    hintStyle: const TextStyle(color: DuoColors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: DuoColors.primaryBlue),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: DuoColors.textMuted, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _currentPartition = 0;
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Fasilitas Pemilihan Kategori (Filter Chips)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'Semua',
                      icon: Icons.grid_view_rounded,
                      categoryKey: 'all',
                      palette: palette,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Lari',
                      icon: Icons.directions_run_rounded,
                      categoryKey: 'run',
                      palette: palette,
                      activeColor: DuoColors.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Sepeda',
                      icon: Icons.directions_bike_rounded,
                      categoryKey: 'cycling',
                      palette: palette,
                      activeColor: DuoColors.streakGold,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Jadwal Kompetisi Mendatang',
                            style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (filteredEvents.length > _eventsPerPage) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.primaryBlue.withOpacity(palette.isDark ? 0.22 : 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: palette.primaryBlue.withOpacity(0.4), width: 1),
                              ),
                              child: Text(
                                'Partisi ${_currentPartition + 1}/${((filteredEvents.length - 1) ~/ _eventsPerPage) + 1}',
                                style: TextStyle(
                                  color: palette.primaryBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: eventService.isLiveFromBackend ? DuoColors.questGreen : DuoColors.streakGold,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            eventService.isLiveFromBackend
                                ? 'LIVE DATA (RunSignup & PostgreSQL)'
                                : (eventService.isLoading ? 'Menghubungkan ke API...' : 'MODE OFFLINE / CACHED'),
                            style: TextStyle(
                              color: eventService.isLiveFromBackend ? DuoColors.questGreen : palette.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: eventService.isLoading
                        ? null
                        : () => eventService.fetchEvents(forceRefresh: true),
                    icon: eventService.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.refresh_rounded, color: palette.primaryBlue),
                    tooltip: 'Sinkronkan Live Data',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Race Events List with Partitioning
              Builder(
                builder: (context) {
                  if (filteredEvents.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.surfaceBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: palette.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'Kompetisi Tidak Ditemukan',
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tidak ada lomba yang sesuai dengan kata kunci "$_searchQuery"',
                            style: TextStyle(color: palette.textSecondary, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final totalPartitions = ((filteredEvents.length - 1) ~/ _eventsPerPage) + 1;
                  final safePartition = _currentPartition.clamp(0, totalPartitions - 1);
                  final startIndex = safePartition * _eventsPerPage;
                  final displayedEvents = filteredEvents.skip(startIndex).take(_eventsPerPage).toList();

                  return Column(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedEvents.length,
                        itemBuilder: (context, index) {
                          final ev = displayedEvents[index];
                          final convertedFee = currencyService.formatCurrency(ev.feeUsd, selectedCurrency);
                          final raceTimeStr = timezoneService.formatForZone(ev.startTimeUtc, selectedTimezone);
                          final isDone = _oneAttemptPerRace &&
                              _completedRuns.containsKey(ev.id.toString());

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: DuoCard(
                              padding: const EdgeInsets.all(16),
                              onTap: () async {
                                // Muat ulang status selesai agar tidak basi
                                await _loadCompletedRuns();
                                if (mounted) _showEventDetailModal(ev);
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            ev.type == 'run' ? Icons.directions_run_rounded : Icons.directions_bike_rounded,
                                            color: ev.type == 'run' ? palette.primaryBlue : DuoColors.streakGold,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: palette.primaryBlue.withOpacity(palette.isDark ? 0.20 : 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: palette.primaryBlue.withOpacity(0.4), width: 1),
                                            ),
                                            child: Text(
                                              '${ev.distanceKm} KM ${ev.type == 'run' ? 'RUN' : 'RIDE'}',
                                              style: TextStyle(color: palette.primaryBlue, fontSize: 10, fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Flexible(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (ev.officialUrl != null && ev.officialUrl!.isNotEmpty) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                margin: const EdgeInsets.only(right: 6),
                                                decoration: BoxDecoration(
                                                  color: DuoColors.questGreen.withOpacity(0.18),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: DuoColors.questGreen, width: 1),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.fiber_manual_record, size: 7, color: DuoColors.questGreen),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      'LIVE',
                                                      style: TextStyle(color: DuoColors.questGreen, fontSize: 9, fontWeight: FontWeight.w900),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: palette.background,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: palette.surfaceBorder),
                                              ),
                                              child: Text(
                                                TimezoneService.getRelativeCountdown(ev.startTimeUtc),
                                                style: const TextStyle(color: DuoColors.streakGold, fontSize: 10, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ev.title,
                                          style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (isDone)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: DuoColors.questGreen.withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: DuoColors.questGreen),
                                          ),
                                          child: const Text(
                                            'SUDAH IKUT',
                                            style: TextStyle(
                                              color: DuoColors.questGreen,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (ev.location != null && ev.location!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_rounded, color: DuoColors.streakGold, size: 14),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            ev.location!,
                                            style: TextStyle(color: palette.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Start (${selectedTimezone.code})', style: TextStyle(color: palette.textMuted, fontSize: 11)),
                                          Text(raceTimeStr, style: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('Biaya ($selectedCurrency)', style: TextStyle(color: palette.textMuted, fontSize: 11)),
                                          Text(convertedFee, style: const TextStyle(color: DuoColors.questGreen, fontWeight: FontWeight.bold, fontSize: 15)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Partition Selector Controls
                      _buildPartitionSelector(
                        currentPartition: safePartition,
                        totalPartitions: totalPartitions,
                        totalEvents: filteredEvents.length,
                        palette: palette,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartitionSelector({
    required int currentPartition,
    required int totalPartitions,
    required int totalEvents,
    required DuoColorPalette palette,
  }) {
    if (totalPartitions <= 1) return const SizedBox.shrink();

    final startEventNum = currentPartition * _eventsPerPage + 1;
    final endEventNum = math.min((currentPartition + 1) * _eventsPerPage, totalEvents);

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.surfaceBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: palette.surfaceShadow,
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_motion_rounded, size: 16, color: palette.primaryBlue),
                  const SizedBox(width: 6),
                  Text(
                    'PARTISI ${currentPartition + 1} DARI $totalPartitions',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'Menampilkan $startEventNum-$endEventNum dari $totalEvents Event',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Tombol Partisi Sebelumnya
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: currentPartition > 0
                      ? () => setState(() => _currentPartition--)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: currentPartition > 0
                          ? palette.background
                          : palette.surfaceBorder.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: currentPartition > 0 ? palette.surfaceBorder : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: currentPartition > 0 ? palette.textPrimary : palette.textMuted.withOpacity(0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PREV',
                          style: TextStyle(
                            color: currentPartition > 0 ? palette.textPrimary : palette.textMuted.withOpacity(0.4),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Indikator Chip Tiap Partisi (P1, P2, ...)
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(totalPartitions, (index) {
                      final isCurrent = index == currentPartition;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => setState(() => _currentPartition = index),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? palette.primaryBlue
                                  : palette.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCurrent ? palette.primaryBlue : palette.surfaceBorder,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              'P${index + 1}',
                              style: TextStyle(
                                color: isCurrent ? Colors.white : palette.textMuted,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Tombol Partisi Selanjutnya
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: currentPartition < totalPartitions - 1
                      ? () => setState(() => _currentPartition++)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: currentPartition < totalPartitions - 1
                          ? palette.primaryBlue
                          : palette.surfaceBorder.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'NEXT',
                          style: TextStyle(
                            color: currentPartition < totalPartitions - 1 ? Colors.white : palette.textMuted.withOpacity(0.4),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: currentPartition < totalPartitions - 1 ? Colors.white : palette.textMuted.withOpacity(0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required String categoryKey,
    required DuoColorPalette palette,
    Color activeColor = DuoColors.primaryBlue,
  }) {
    final isSelected = _selectedCategory == categoryKey;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = categoryKey;
          _currentPartition = 0;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(palette.isDark ? 0.20 : 0.14)
              : palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : palette.surfaceBorder,
            width: 2,
          ),
          boxShadow: isSelected
              ? []
              : [
                  BoxShadow(
                    color: palette.surfaceShadow,
                    offset: const Offset(0, 2),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : palette.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: isSelected ? activeColor : palette.textMuted,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
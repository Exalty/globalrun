import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/race_event.dart';
import '../services/timezone_service.dart';
import '../services/currency_service.dart';
import '../services/blockchain_service.dart';
import '../services/ai_coach_service.dart';
import '../services/notification_service.dart';
import 'active_race_screen.dart';
import 'blockchain_certificate_screen.dart';
import 'mini_game_screen.dart';
import 'ai_coach_screen.dart';
import 'notification_screen.dart';
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

  final List<RaceEvent> events = RaceEvent.sampleEvents();

  // Pencarian dan Filter Kategori
  String _searchQuery = '';
  String _selectedCategory = 'all'; // 'all', 'run', 'cycling'
  final TextEditingController _searchController = TextEditingController();

  List<RaceEvent> get _filteredEvents {
    return events.where((e) {
      final matchesQuery = e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'all' || e.type == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEventDetailModal(RaceEvent event) {
    final palette = DuoColors.of(context);
    final currencyService = context.read<CurrencyService>();
    final timezoneService = context.read<TimezoneService>();
    final selectedTimezone = timezoneService.selectedTimezone;
    final selectedCurrency = currencyService.selectedCurrency;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: event.type == 'run' ? Colors.cyan.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.type == 'run' ? '🏃 MARATHON RUN' : '🚴 CYCLING RACE',
                      style: TextStyle(
                        color: event.type == 'run' ? Colors.cyanAccent : Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '${event.distanceKm} KM',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.title,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Divider(color: Colors.white24, height: 24),

              // Timezone conversion synchronized info
              Row(
                children: [
                  const Icon(Icons.access_time_filled_rounded, color: Colors.cyanAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Jadwal Start (${selectedTimezone.code}):',
                    style: TextStyle(color: palette.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                timezoneService.formatForZone(event.startTimeUtc, selectedTimezone),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                'Countdown: ${TimezoneService.getRelativeCountdown(event.startTimeUtc)}',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
              ),

              const SizedBox(height: 16),
              // Currency fee conversion
              Row(
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Biaya Pendaftaran ($selectedCurrency):',
                    style: TextStyle(color: palette.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                currencyService.formatCurrency(event.feeUsd, selectedCurrency),
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 22),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _notificationService.showNotification(
                      title: '⏰ Pengingat Disetel: ${event.title}',
                      body: 'Notifikasi akan dikirim 15 menit sebelum flag-off race (${timezoneService.formatForZone(event.startTimeUtc, selectedTimezone)}).',
                      type: 'race_reminder',
                      payload: 'open_race:${event.id}',
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Pengingat mobile untuk ${event.title} telah aktif!'),
                        backgroundColor: Colors.cyan,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.alarm_add_rounded, size: 18),
                  label: const Text('Setel Pengingat Mobile (15 Menit Sebelum Start)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
                          blockchainService: widget.blockchainService,
                          aiCoachService: widget.aiCoachService,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text('Mulai Race Virtual Sekarang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    // Consume providers — rebuild otomatis saat currency/timezone berubah
    final currencyService = context.watch<CurrencyService>();
    final timezoneService = context.watch<TimezoneService>();
    final selectedTimezone = timezoneService.selectedTimezone;
    final selectedCurrency = currencyService.selectedCurrency;

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
            icon: const Icon(Icons.videogame_asset_rounded, color: Colors.amberAccent),
            tooltip: 'Endless Runner Mini-Game',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MiniGameScreen()),
              );
            },
          ),
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
                    icon: const Icon(Icons.notifications_rounded, color: Colors.white),
                    tooltip: 'Notifikasi Mobile',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationScreen(
                            blockchainService: widget.blockchainService,
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
                          color: Colors.redAccent,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Duolingo Top Gamification Chips Bar
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  DuoChip(
                    icon: const Text('🔥', style: TextStyle(fontSize: 14)),
                    label: '5 HARI',
                    borderColor: DuoColors.streakGoldShadow,
                    backgroundColor: palette.surface,
                    textColor: DuoColors.streakGold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DuoChip(
                      icon: const Text('💎', style: TextStyle(fontSize: 14)),
                      label: selectedCurrency,
                      borderColor: DuoColors.primaryBlueShadow,
                      backgroundColor: palette.surface,
                      textColor: DuoColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DuoChip(
                    icon: Text(selectedTimezone.flag, style: const TextStyle(fontSize: 14)),
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
                      const Icon(Icons.public_rounded, color: Colors.cyanAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sinkronisasi Global Lintas Negara',
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      // Tombol refresh kurs dari API
                      if (currencyService.isLoading || timezoneService.isLoading)
                        const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.cyanAccent,
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
                            width: 6, height: 6,
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
                            width: 6, height: 6,
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
                            const Text('Zona Waktu:', style: TextStyle(color: Colors.white60, fontSize: 12)),
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
                                    child: Text('${z.flag} ${z.code}', overflow: TextOverflow.ellipsis),
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
                            const Text('Mata Uang:', style: TextStyle(color: Colors.white60, fontSize: 12)),
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

            // Feature Quick Actions (AI Coach & Mini Game - Duo 3D)
            Row(
              children: [
                Expanded(
                  child: DuoCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AiCoachScreen(
                            coachService: widget.aiCoachService,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.smart_toy_rounded, color: DuoColors.primaryBlue, size: 28),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI COACH', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
                            const Text('Nutrisi & Taktik', style: TextStyle(color: DuoColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DuoCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MiniGameScreen()),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.sports_esports_rounded, color: DuoColors.streakGold, size: 28),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MINI GAME', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
                            const Text('Endless Runner', style: TextStyle(color: DuoColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Fasilitas Pencarian Lomba (Search Bar - Duo 3D)
            DuoCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
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
                            setState(() => _searchQuery = '');
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
            Text(
              'Jadwal Kompetisi Mendatang',
              style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Race Events List
            _filteredEvents.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: Colors.white38),
                        const SizedBox(height: 12),
                        const Text(
                          'Kompetisi Tidak Ditemukan',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tidak ada lomba yang sesuai dengan kata kunci "$_searchQuery"',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, index) {
                      final ev = _filteredEvents[index];
                      final convertedFee = currencyService.formatCurrency(ev.feeUsd, selectedCurrency);
                      final raceTimeStr = timezoneService.formatForZone(ev.startTimeUtc, selectedTimezone);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DuoCard(
                          padding: const EdgeInsets.all(16),
                          onTap: () => _showEventDetailModal(ev),
                          child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            ev.type == 'run' ? Icons.directions_run_rounded : Icons.directions_bike_rounded,
                                            color: ev.type == 'run' ? Colors.cyanAccent : Colors.orangeAccent,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            ev.type == 'run' ? 'Running' : 'Cycling',
                                            style: TextStyle(
                                              color: ev.type == 'run' ? Colors.cyanAccent : Colors.orangeAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          TimezoneService.getRelativeCountdown(ev.startTimeUtc),
                                          style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    ev.title,
                                    style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ev.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: palette.textSecondary, fontSize: 13),
                                  ),
                                  const Divider(color: Colors.white12, height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Start (${selectedTimezone.code})', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                          Text(raceTimeStr, style: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('Biaya ($selectedCurrency)', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                          Text(convertedFee, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
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
          ],
        ),
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
        setState(() => _selectedCategory = categoryKey);
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

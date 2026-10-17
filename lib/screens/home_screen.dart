import 'package:flutter/material.dart';

import '../models/race_event.dart';
import '../services/timezone_service.dart';
import '../services/currency_service.dart';
import '../services/blockchain_service.dart';
import '../services/ai_coach_service.dart';
import 'active_race_screen.dart';
import 'blockchain_certificate_screen.dart';
import 'mini_game_screen.dart';
import 'ai_coach_screen.dart';

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
  TimezoneModel selectedTimezone = TimezoneService.supportedZones[0]; // WIB default
  String selectedCurrency = 'IDR'; // IDR default

  final List<RaceEvent> events = RaceEvent.sampleEvents();

  void _showEventDetailModal(RaceEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
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
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                TimezoneService.formatForZone(event.startTimeUtc, selectedTimezone),
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
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyService.formatCurrency(event.feeUsd, selectedCurrency),
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 22),
              ),

              const SizedBox(height: 24),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.directions_run_rounded, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('Global Virtual Race', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Global Converters Card (Timezone & Currency)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.public_rounded, color: Colors.cyanAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Sinkronisasi Global Lintas Negara',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
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
                                color: const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<TimezoneModel>(
                                isExpanded: true,
                                value: selectedTimezone,
                                dropdownColor: const Color(0xFF1E293B),
                                underline: const SizedBox(),
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                items: TimezoneService.supportedZones.map((z) {
                                  return DropdownMenuItem(
                                    value: z,
                                    child: Text('${z.flag} ${z.code}', overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => selectedTimezone = val);
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
                                color: const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedCurrency,
                                dropdownColor: const Color(0xFF1E293B),
                                underline: const SizedBox(),
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                items: CurrencyService.currencies.keys.map((c) {
                                  return DropdownMenuItem(
                                    value: c,
                                    child: Text('$c (${CurrencyService.currencies[c]!.symbol})'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => selectedCurrency = val);
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

            // Feature Quick Actions (AI Coach & Mini Game)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
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
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.smart_toy_rounded, color: Colors.cyanAccent, size: 28),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AI Coach', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text('Nutrisi & Taktik', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MiniGameScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.sports_esports_rounded, color: Colors.amberAccent, size: 28),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mini-Game', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text('Endless Runner', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              'Jadwal Kompetisi Mendatang',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Race Events List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final ev = events[index];
                final convertedFee = CurrencyService.formatCurrency(ev.feeUsd, selectedCurrency);
                final raceTimeStr = TimezoneService.formatForZone(ev.startTimeUtc, selectedTimezone);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showEventDetailModal(ev),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
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
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ev.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                            const Divider(color: Colors.white12, height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Start (${selectedTimezone.code})', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                    Text(raceTimeStr, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
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
}

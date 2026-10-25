import 'package:flutter/material.dart';
import '../models/run_record.dart';
import '../services/blockchain_service.dart';
import '../services/run_history_service.dart';
import 'run_summary_screen.dart';

/// Daftar riwayat lari. Dibuka dari kotak Statistik Kompetisi di ProfileScreen:
/// Navigator.push(context, MaterialPageRoute(builder: (_) => RunHistoryScreen(blockchainService: ...)));
class RunHistoryScreen extends StatefulWidget {
  /// Opsional. Jika null, dipakai BlockchainService() (singleton).
  final BlockchainService? blockchainService;

  const RunHistoryScreen({super.key, this.blockchainService});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  late Future<List<RunRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = RunHistoryService().loadAll();
  }

  void _reload() => setState(() => _future = RunHistoryService().loadAll());

  @override
  Widget build(BuildContext context) {
    final bc = widget.blockchainService ?? BlockchainService();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Riwayat Lari', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<RunRecord>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final runs = snap.data ?? [];
          if (runs.isEmpty) {
            return const Center(
              child: Text('Belum ada riwayat lari.', style: TextStyle(color: Colors.white54)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: runs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = runs[i];
              return Dismissible(
                key: ValueKey(r.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                      color: Colors.redAccent, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await RunHistoryService().delete(r.id);
                  _reload();
                },
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RunSummaryScreen(record: r, blockchainService: bc),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          r.completed ? Icons.emoji_events_rounded : Icons.directions_run_rounded,
                          color: r.completed ? Colors.amber : Colors.cyanAccent,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.eventTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(RunFormat.date(r.startedAt),
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${r.distanceKm.toStringAsFixed(2)} km',
                                style: const TextStyle(
                                    color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                            Text(
                              '${RunFormat.duration(r.durationSeconds)} • ${RunFormat.pace(r.avgPaceSecPerKm)}/km',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
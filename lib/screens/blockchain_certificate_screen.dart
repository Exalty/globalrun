import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/blockchain_record.dart';
import '../services/blockchain_service.dart';

class BlockchainCertificateScreen extends StatefulWidget {
  final BlockchainService blockchainService;
  final Block? highlightBlock;

  const BlockchainCertificateScreen({
    super.key,
    required this.blockchainService,
    this.highlightBlock,
  });

  @override
  State<BlockchainCertificateScreen> createState() => _BlockchainCertificateScreenState();
}

class _BlockchainCertificateScreenState extends State<BlockchainCertificateScreen> {
  late bool isLedgerValid;

  @override
  void initState() {
    super.initState();
    isLedgerValid = widget.blockchainService.verifyLedgerIntegrity();
  }

  void _showBlockDetail(Block block) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Colors.cyanAccent, size: 28),
                  const SizedBox(width: 10),
                  Text('Blok #${block.index} Verified NFT Certificate',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Participant', block.participantName),
              _buildInfoRow('Event', block.raceTitle),
              _buildInfoRow('Distance', '${block.distanceKm.toStringAsFixed(2)} km'),
              _buildInfoRow('Steps Count', '${block.stepsCount} langkah (Pedometer verified)'),
              _buildInfoRow('Duration', '${(block.durationSeconds / 60).toStringAsFixed(1)} menit'),
              _buildInfoRow('Avg Speed', '${block.avgSpeedKmh.toStringAsFixed(1)} km/h'),
              const Divider(color: Colors.white24, height: 20),
              const Text('Cryptographic SHA-256 Hash:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              SelectableText(
                block.hash,
                style: const TextStyle(color: Colors.cyanAccent, fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Text('Previous Block Hash:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              SelectableText(
                block.previousHash,
                style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: block.hash));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hash medali berhasil disalin ke clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Salin Hash Sertifikat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chain = widget.blockchainService.chain;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Blockchain Ledger & Medals', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                isLedgerValid = widget.blockchainService.verifyLedgerIntegrity();
              });
            },
            tooltip: 'Validasi Ulang Ledger',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ledger Integrity Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isLedgerValid
                      ? [const Color(0xFF065F46), const Color(0xFF047857)]
                      : [const Color(0xFF7F1D1D), const Color(0xFF991B1B)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isLedgerValid ? Colors.green : Colors.red).withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isLedgerValid ? Icons.security_rounded : Icons.gpp_bad_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLedgerValid ? 'Proof-of-Athletics Valid' : 'Ledger Tampered!',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLedgerValid
                              ? 'Seluruh sertifikat & medali aman terenkripsi SHA-256 tanpa kecurangan data GPS/Sensor.'
                              : 'Integritas rantai hash rusak atau mengalami modifikasi tidak sah.',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Koleksi Medali Digital (NFT)',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${chain.length} Blok',
                  style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Certificates / Blocks List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chain.length,
              separatorBuilder: (context, i) => Center(
                child: Container(
                  height: 24,
                  width: 2,
                  color: Colors.cyanAccent.withOpacity(0.4),
                ),
              ),
              itemBuilder: (context, index) {
                final block = chain[chain.length - 1 - index]; // latest first
                final isGenesis = block.index == 0;

                return GestureDetector(
                  onTap: () => _showBlockDetail(block),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isGenesis ? Colors.white24 : Colors.cyanAccent.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isGenesis
                                  ? [Colors.blueGrey, Colors.grey]
                                  : [Colors.amber.shade600, Colors.deepOrangeAccent],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isGenesis ? Colors.blueGrey : Colors.amber).withOpacity(0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            isGenesis ? Icons.hub_rounded : Icons.military_tech_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isGenesis ? 'Genesis Block #0' : 'Digital Medal #${block.index}',
                                    style: TextStyle(
                                      color: isGenesis ? Colors.white70 : Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    block.timestamp.split('T').first,
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                block.raceTitle,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Peserta: ${block.participantName} • ${block.distanceKm.toStringAsFixed(1)} KM • ${block.stepsCount} langkah',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Hash: ${block.hash.substring(0, 16)}...',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          ),
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
}

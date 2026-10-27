import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/blockchain_record.dart';
import '../services/blockchain_service.dart';
import '../theme/duo_theme.dart';

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
  bool _loaded = false;
  bool isLedgerValid = true;
  int? _invalidIndex;

  @override
  void initState() {
    super.initState();
    // Muat ulang ledger terisolasi untuk akun yang sedang login
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await widget.blockchainService.reloadForUser();
    } catch (e) {
      debugPrint('Error loading ledger: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loaded = true;
          _revalidate();
        });
      }
    }
  }


  Future<void> _confirmClearLedger() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = DuoColors.of(ctx);
        return AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: p.surfaceBorder, width: 2),
          ),
          title: Text('Kosongkan Medali?', style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w900)),
          content: Text(
            'Seluruh koleksi medali lokal akun ini akan dikosongkan.',
            style: TextStyle(color: p.textSecondary, fontSize: 13),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: p.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DuoColors.heartRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kosongkan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
    );
    if (ok == true) {
      await widget.blockchainService.clearLedger();
      if (mounted) {
        setState(_revalidate);
      }
    }
  }

  void _revalidate() {
    _invalidIndex = widget.blockchainService.findInvalidBlockIndex();
    isLedgerValid = _invalidIndex == null;
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'GOLD':
        return Colors.amber;
      case 'SILVER':
        return const Color(0xFFB0BEC5);
      case 'BRONZE':
        return const Color(0xFFD7845A);
      default:
        return Colors.blueGrey;
    }
  }

  void _showBlockDetail(Block block) {
    final palette = DuoColors.of(context);
    final tierColor = _tierColor(block.tier);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: palette.surfaceBorder, width: 2),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_rounded, color: palette.primaryBlue, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        block.isGenesis
                            ? 'Genesis Block #0'
                            : 'Blok #${block.index} Verified NFT Certificate',
                        style: TextStyle(
                            color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!block.isGenesis) ...[
                  _buildInfoRow(palette, 'Token ID', block.tokenId),
                  _buildInfoRow(palette, 'Tier Medali', block.tier, valueColor: tierColor),
                ],
                _buildInfoRow(palette, 'Participant', block.participantName),
                _buildInfoRow(palette, 'Event', block.raceTitle),
                _buildInfoRow(palette, 'Distance', '${block.distanceKm.toStringAsFixed(2)} km'),
                _buildInfoRow(palette, 'Steps Count', '${block.stepsCount} langkah (Pedometer verified)'),
                _buildInfoRow(palette, 'Duration', '${(block.durationSeconds / 60).toStringAsFixed(1)} menit'),
                _buildInfoRow(palette, 'Avg Speed', '${block.avgSpeedKmh.toStringAsFixed(1)} km/h'),
                _buildInfoRow(palette, 'Minted At', block.timestamp.replaceFirst('T', ' ').split('.').first),
                Divider(color: palette.surfaceBorder, height: 24),
                Text('Cryptographic SHA-256 Hash:',
                    style: TextStyle(color: palette.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SelectableText(
                  block.hash,
                  style: TextStyle(
                      color: palette.primaryBlue, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Previous Block Hash:',
                    style: TextStyle(color: palette.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SelectableText(
                  block.previousHash,
                  style: TextStyle(
                      color: palette.textSecondary, fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 20),
                DuoButton(
                  text: 'SALIN HASH SERTIFIKAT',
                  height: 48,
                  backgroundColor: palette.primaryBlue,
                  shadowColor: palette.primaryBlueShadow,
                  textColor: Colors.white,
                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: block.hash));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hash medali berhasil disalin ke clipboard!')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(DuoColorPalette palette, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);

    if (!_loaded) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          iconTheme: IconThemeData(color: palette.textPrimary),
          backgroundColor: palette.surface,
          title: Text('SERTIFIKAT & MEDALI',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 18,
                  color: palette.textPrimary)),
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }

    final chain = widget.blockchainService.chain;
    final medalCount = widget.blockchainService.medalCount;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          'SERTIFIKAT & MEDALI',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 18,
            color: palette.textPrimary,
          ),
        ),
        backgroundColor: palette.surface,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: palette.surfaceBorder, width: 2)),
        actions: [
          if (medalCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _confirmClearLedger,
              tooltip: 'Kosongkan Medali',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(_revalidate),
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
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLedgerValid
                              ? 'Seluruh sertifikat & medali aman terenkripsi SHA-256 tanpa kecurangan data GPS/Sensor.'
                              : 'Integritas rantai hash rusak mulai dari Blok #$_invalidIndex. Data telah dimodifikasi secara tidak sah.',
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
                Text(
                  'Koleksi Medali Digital (NFT)',
                  style: TextStyle(
                      color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$medalCount Medali Koleksi',
                  style: const TextStyle(
                      color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (medalCount == 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.surfaceBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: palette.surfaceShadow, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.military_tech_outlined, color: palette.textMuted, size: 44),
                    const SizedBox(height: 10),
                    Text(
                      'Belum ada medali. Selesaikan sebuah race untuk mencetak medali NFT pertamamu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textSecondary, fontSize: 13, fontWeight: FontWeight.bold, height: 1.4),
                    ),
                  ],
                ),
              ),

            // Certificates / Blocks List
            if (medalCount > 0)
              ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: medalCount,
              separatorBuilder: (context, i) => Center(
                child: Container(
                  height: 24,
                  width: 2,
                  color: Colors.cyanAccent.withOpacity(0.4),
                ),
              ),
              itemBuilder: (context, index) {
                final earned = chain.where((b) => !b.isGenesis).toList();
                final block = earned[earned.length - 1 - index]; // latest first
                final isGenesis = block.isGenesis;
                final isHighlighted = widget.highlightBlock != null &&
                    widget.highlightBlock!.index == block.index;
                final tierColor = _tierColor(block.tier);
                final isBroken = _invalidIndex != null && block.index >= _invalidIndex!;

                return GestureDetector(
                  onTap: () => _showBlockDetail(block),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isBroken
                            ? Colors.redAccent
                            : isHighlighted
                                ? Colors.amber
                                : (isGenesis
                                    ? Colors.white24
                                    : Colors.cyanAccent.withOpacity(0.5)),
                        width: isHighlighted ? 2.5 : 1.5,
                      ),
                      boxShadow: isHighlighted
                          ? [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.35),
                                blurRadius: 16,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
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
                                  : [tierColor, tierColor.withOpacity(0.55)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: tierColor.withOpacity(0.4),
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
                                  Flexible(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            isGenesis
                                                ? 'Genesis Block #0'
                                                : '${block.tokenId} • ${block.tier}',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isGenesis ? Colors.white70 : tierColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (isHighlighted) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('BARU',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    block.timestamp.split('T').first,
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                block.raceTitle,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Peserta: ${block.participantName} • ${block.distanceKm.toStringAsFixed(1)} KM • ${block.stepsCount} langkah',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Hash: ${block.hash.substring(0, 16)}...',
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontFamily: 'monospace'),
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
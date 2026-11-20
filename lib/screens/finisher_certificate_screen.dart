import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/blockchain_record.dart';
import '../services/blockchain_service.dart';
import '../theme/duo_theme.dart';
import 'certificate_scanner_screen.dart';

class FinisherCertificateScreen extends StatefulWidget {
  final Block block;
  final BlockchainService? blockchainService;

  const FinisherCertificateScreen({
    super.key,
    required this.block,
    this.blockchainService,
  });

  @override
  State<FinisherCertificateScreen> createState() => _FinisherCertificateScreenState();
}

class _FinisherCertificateScreenState extends State<FinisherCertificateScreen> {
  final GlobalKey _certificateKey = GlobalKey();
  bool _isSaving = false;
  String? _savedFilePath;

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}j ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}d';
    }
    return '${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}d';
  }

  String _formatPace(double distanceKm, int durationSeconds) {
    if (distanceKm <= 0 || durationSeconds <= 0) return "-'--\"/km";
    final secPerKm = (durationSeconds / distanceKm).round();
    final minutes = secPerKm ~/ 60;
    final seconds = secPerKm % 60;
    return '${minutes.toString().padLeft(2, '0')}\'${seconds.toString().padLeft(2, '0')}"/km';
  }

  String _getVerificationPayload() {
    final b = widget.block;
    if (b.polygonscanUrl != null && b.polygonscanUrl!.isNotEmpty) {
      return b.polygonscanUrl!;
    }
    return 'https://amoy.polygonscan.com/verify?token=${b.tokenId}&hash=${b.hash}&runner=${Uri.encodeComponent(b.participantName)}&race=${Uri.encodeComponent(b.raceTitle)}&time=${b.durationSeconds}&dist=${b.distanceKm}';
  }

  Future<void> _saveCertificateToStorage() async {
    final palette = DuoColors.of(context);
    setState(() => _isSaving = true);

    try {
      final boundary = _certificateKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('RenderRepaintBoundary tidak ditemukan');
      }

      // Render high-res image (3.0 pixel ratio untuk kualitas cetak tajam)
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Gagal mengubah render menjadi byte PNG');
      }
      final pngBytes = byteData.buffer.asUint8List();

      Directory? targetDir;
      try {
        if (Platform.isAndroid) {
          // Coba simpan ke folder Download publik Android
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            targetDir = downloadDir;
          }
        }
      } catch (_) {}

      // Fallback ke Application Documents Directory
      targetDir ??= await getApplicationDocumentsDirectory();

      final fileName = 'GlobalRun_Sertifikat_${widget.block.tokenId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${targetDir.path}/$fileName');
      await file.writeAsBytes(pngBytes, flush: true);

      if (!mounted) return;
      setState(() {
        _savedFilePath = file.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: palette.questGreen,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Piagam berhasil disimpan ke:\n${file.path}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: palette.heartRed,
          content: Text('Gagal menyimpan sertifikat: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    final block = widget.block;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('DOKUMEN PIAGAM RESMI'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Pindai Sertifikat Fisik',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CertificateScannerScreen(
                    blockchainService: widget.blockchainService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // Kontainer Piagam Cetak Resmi (Dibungkus RepaintBoundary)
            RepaintBoundary(
              key: _certificateKey,
              child: _buildDiplomaCard(block),
            ),
            const SizedBox(height: 24),

            // Indikator jika baru saja disimpan
            if (_savedFilePath != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.questGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.questGreen, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.image_rounded, color: palette.questGreen, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FILE SERTIFIKAT TERSIMPAN',
                            style: TextStyle(
                              color: palette.questGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _savedFilePath!,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Tombol Aksi 1: Simpan ke HP
            DuoButton(
              text: _isSaving ? 'MENYIMPAN PIAGAM...' : '💾 SIMPAN SERTIFIKAT KE HP',
              height: 52,
              backgroundColor: palette.questGreen,
              shadowColor: palette.questGreenShadow,
              textColor: Colors.white,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded, color: Colors.white, size: 22),
              onPressed: _isSaving ? null : _saveCertificateToStorage,
            ),
            const SizedBox(height: 12),

            // Tombol Aksi 2: Buka di Polygonscan (jika sudah on-chain)
            if (block.polygonscanUrl != null && block.polygonscanUrl!.isNotEmpty) ...[
              DuoButton(
                text: '↗️ BUKA DI POLYGONSCAN',
                height: 48,
                backgroundColor: palette.streakGold,
                shadowColor: palette.streakGoldShadow,
                textColor: Colors.white,
                icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 20),
                onPressed: () async {
                  final uri = Uri.parse(block.polygonscanUrl!);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(height: 12),
            ],

            // Tombol Aksi 3: Pindai Sertifikat Fisik
            DuoButton(
              text: '📷 PINDAI SERTIFIKAT FISIK LAIN',
              height: 48,
              backgroundColor: palette.secondaryButton,
              shadowColor: palette.secondaryButtonShadow,
              textColor: palette.textPrimary,
              icon: Icon(Icons.camera_alt_rounded, color: palette.textPrimary, size: 18),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CertificateScannerScreen(
                      blockchainService: widget.blockchainService,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Desain Dokumen Piagam Resmi (Official Diploma Layout)
  /// Menggunakan latar putih/parchment krem agar presisi saat dicetak ke kertas fisik.
  Widget _buildDiplomaCard(Block block) {
    const goldPrimary = Color(0xFFD97706);
    const goldLight = Color(0xFFFDE68A);
    const deepNavy = Color(0xFF0F172A);
    const parchmentBg = Color(0xFFFCFBF7);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: parchmentBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Container(
        // Bingkai Ganda Emas Khas Piagam Resmi
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: goldPrimary, width: 3.5),
        ),
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: goldLight, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo / Emblem Kejuaraan
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: goldPrimary, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'GLOBAL VIRTUAL RACE',
                    style: TextStyle(
                      color: deepNavy.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.emoji_events_rounded, color: goldPrimary, size: 28),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'CERTIFICATE OF ATHLETIC ACHIEVEMENT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: deepNavy,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 80,
                height: 2.5,
                decoration: BoxDecoration(
                  color: goldPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Teks Penghargaan
              const Text(
                'Diberikan dengan penuh kehormatan kepada:',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),

              // Nama Atlet
              Text(
                block.participantName.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: deepNavy,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // Penjelasan Selesai Lomba
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Atas keberhasilan menyelesaikan nomor perlombaan atletik resmi:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF475569),
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Judul Lomba & Kategori Jarak
              Text(
                '${block.raceTitle.toUpperCase()} • ${block.distanceKm.toStringAsFixed(1)} KM',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: goldPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 16),

              // Tabel Metrik Atletik (Waktu, Pace, Langkah)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Row(
                  children: [
                    _buildMetricBox('WAKTU FINISH', _formatDuration(block.durationSeconds), deepNavy),
                    _divider(),
                    _buildMetricBox('PACE RATA-RATA', _formatPace(block.distanceKm, block.durationSeconds), deepNavy),
                    _divider(),
                    _buildMetricBox('TOTAL LANGKAH', '${block.stepsCount}', deepNavy),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Badge Integritas & Jaringan
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildPillBadge(
                    icon: Icons.verified_user_rounded,
                    label: 'ANTI-CHEAT: VERIFIED',
                    bgColor: const Color(0xFFDCFCE7),
                    textColor: const Color(0xFF15803D),
                  ),
                  _buildPillBadge(
                    icon: Icons.link_rounded,
                    label: block.polygonTxHash != null ? 'POLYGON AMOY: ON-CHAIN' : 'LOCAL LEDGER: VERIFIED',
                    bgColor: const Color(0xFFE0F2FE),
                    textColor: const Color(0xFF0369A1),
                  ),
                  _buildPillBadge(
                    icon: Icons.military_tech_rounded,
                    label: '${block.tier} FINISHER',
                    bgColor: const Color(0xFFFEF3C7),
                    textColor: const Color(0xFFB45309),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bagian Bukti Kriptografis & Stempel
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // QR Code Kriptografis
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        child: QrImageView(
                          data: _getVerificationPayload(),
                          version: QrVersions.auto,
                          size: 78.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'SCAN VERIFIKASI',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w900,
                          fontSize: 7.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Stempel Segel Emas & Tanda Tangan Komite
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Segel Emas
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: goldPrimary, width: 1.2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars_rounded, color: goldPrimary, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'OFFICIAL FINISHER SEAL',
                                style: TextStyle(
                                  color: goldPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8.5,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Garis Tanda Tangan
                        Container(width: 120, height: 1, color: const Color(0xFF94A3B8)),
                        const SizedBox(height: 4),
                        const Text(
                          'Race Committee Director',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Global Virtual Athletics Federation',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Catatan Kaki Metadata Blok (Font Monospace)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOKEN ID: ${block.tokenId} • BLOCK #${block.index}',
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SHA-256: ${block.hash.length > 32 ? "${block.hash.substring(0, 32)}..." : block.hash}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontFamily: 'monospace',
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBox(String title, String value, Color textColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0xFFCBD5E1),
    );
  }

  Widget _buildPillBadge({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

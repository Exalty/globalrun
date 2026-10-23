import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/timezone_service.dart';
import '../theme/duo_theme.dart';
import 'notification_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isBiometricActive = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _authService.getUserProfile();
    final bioEnabled = await _authService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isBiometricActive = bioEnabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleToggleBiometric(bool value) async {
    if (value) {
      // Nyalakan: Minta pemindaian sidik jari untuk verifikasi kepemilikan perangkat
      final success = await _authService.setBiometricEnabled(true);
      if (success) {
        setState(() => _isBiometricActive = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: DuoColors.questGreen),
                  SizedBox(width: 8),
                  Text('Login sidik jari berhasil diaktifkan!'),
                ],
              ),
              backgroundColor: DuoColors.surface,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verifikasi sidik jari dibatalkan atau gagal.'),
              backgroundColor: DuoColors.heartRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      // Matikan
      await _authService.setBiometricEnabled(false);
      setState(() => _isBiometricActive = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login sidik jari dinonaktifkan.'),
            backgroundColor: DuoColors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: DuoColors.background,
        body: Center(child: CircularProgressIndicator(color: DuoColors.primaryBlue)),
      );
    }

    final currencyService = context.watch<CurrencyService>();
    final timezoneService = context.watch<TimezoneService>();
    final selectedCurrency = currencyService.selectedCurrency;
    final selectedTimezone = timezoneService.selectedTimezone;

    final name = (_userProfile?['name'] != null && _userProfile!['name'].toString().isNotEmpty)
        ? _userProfile!['name']
        : 'Atlet Global';
    final email = (_userProfile?['email'] != null && _userProfile!['email'].toString().isNotEmpty)
        ? _userProfile!['email']
        : 'email@kompetisi.com';
    final walletUsd = (_userProfile?['wallet'] ?? 250.0) as double;

    final walletFormatted = currencyService.formatCurrency(walletUsd, selectedCurrency);

    return Scaffold(
      backgroundColor: DuoColors.background,
      appBar: AppBar(
        title: const Text(
          'PROFIL ATLET',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 18),
        ),
        backgroundColor: DuoColors.surface,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: DuoColors.surfaceBorder, width: 2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // 1. Athlete Card Header (Duolingo 3D style)
            DuoCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: DuoColors.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: DuoColors.primaryBlue, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: DuoColors.primaryBlueShadow,
                              offset: Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.person_rounded, size: 54, color: DuoColors.primaryBlue),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: DuoColors.questGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: DuoColors.surface, width: 2.5),
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(color: DuoColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DuoChip(
                        icon: const Text('🔥', style: TextStyle(fontSize: 14)),
                        label: 'LEVEL 5 ATLET',
                        borderColor: DuoColors.streakGoldShadow,
                        backgroundColor: DuoColors.background,
                        textColor: DuoColors.streakGold,
                      ),
                      const SizedBox(width: 8),
                      DuoChip(
                        icon: Icon(
                          _isBiometricActive ? Icons.fingerprint_rounded : Icons.lock_outline_rounded,
                          color: _isBiometricActive ? DuoColors.questGreen : DuoColors.textMuted,
                          size: 16,
                        ),
                        label: _isBiometricActive ? 'SIDIK JARI AKTIF' : 'SIDIK JARI MATI',
                        borderColor: _isBiometricActive ? DuoColors.questGreenShadow : DuoColors.surfaceBorder,
                        backgroundColor: DuoColors.background,
                        textColor: _isBiometricActive ? DuoColors.questGreen : DuoColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. DOMPET DIGITAL (Race Wallet) - Duolingo 3D
            DuoCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DOMPET DIGITAL (RACE WALLET)',
                        style: TextStyle(
                          color: DuoColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: DuoColors.primaryBlue.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DuoColors.primaryBlue, width: 1.5),
                        ),
                        child: Text(
                          selectedCurrency,
                          style: const TextStyle(
                            color: DuoColors.primaryBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 26)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            walletFormatted,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (selectedCurrency != 'USD')
                            Text(
                              '≈ \$${walletUsd.toStringAsFixed(2)} USD',
                              style: const TextStyle(
                                color: DuoColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DuoButton(
                    text: 'TOP UP SALDO',
                    height: 46,
                    backgroundColor: DuoColors.streakGold,
                    shadowColor: DuoColors.streakGoldShadow,
                    textColor: Colors.black,
                    icon: const Icon(Icons.add_card_rounded, color: Colors.black, size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Top-up saldo berhasil disimulasikan!'),
                          backgroundColor: DuoColors.surface,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 3. PENGATURAN MATA UANG & ZONA WAKTU (Duolingo 3D)
            DuoCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: DuoColors.primaryBlue.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DuoColors.primaryBlue, width: 1.5),
                        ),
                        child: const Icon(Icons.currency_exchange_rounded, color: DuoColors.primaryBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MATA UANG & ZONA WAKTU',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Sinkronisasi API global kompetisi',
                              style: TextStyle(color: DuoColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: currencyService.hasApiData ? DuoColors.questGreen : DuoColors.streakGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Pilihan Mata Uang
                  const Text(
                    'MATA UANG AKTIF',
                    style: TextStyle(color: DuoColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: DuoColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: DuoColors.surfaceBorder, width: 2),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCurrency,
                      dropdownColor: DuoColors.surface,
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      items: currencyService.currencies.keys.map((c) {
                        final rate = currencyService.currencies[c]!;
                        return DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Text(
                                rate.symbol,
                                style: const TextStyle(color: DuoColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${rate.code} — ${rate.name}',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          currencyService.setSelectedCurrency(val);
                        }
                      },
                    ),
                  ),

                  if (currencyService.hasApiData)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '📊 ${currencyService.getRateLabel(selectedCurrency)}',
                        style: const TextStyle(color: DuoColors.questGreen, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Pilihan Zona Waktu
                  const Text(
                    'ZONA WAKTU AKTIF',
                    style: TextStyle(color: DuoColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: DuoColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: DuoColors.surfaceBorder, width: 2),
                    ),
                    child: DropdownButton<TimezoneModel>(
                      isExpanded: true,
                      value: selectedTimezone,
                      dropdownColor: DuoColors.surface,
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      items: timezoneService.supportedZones.map((z) {
                        return DropdownMenuItem(
                          value: z,
                          child: Row(
                            children: [
                              Text(z.flag, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${z.code} (${timezoneService.getOffsetLabel(z)})',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          timezoneService.setSelectedTimezone(val);
                        }
                      },
                    ),
                  ),

                  if (timezoneService.hasApiData)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '🌍 ${selectedTimezone.label} • ${timezoneService.getOffsetLabel(selectedTimezone)}',
                        style: const TextStyle(color: DuoColors.questGreen, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Refresh Button 3D
                  DuoButton(
                    text: (currencyService.isLoading || timezoneService.isLoading)
                        ? 'MEMPERBARUI DARI API...'
                        : 'PERBARUI KURS & ZONA WAKTU',
                    backgroundColor: DuoColors.secondaryButton,
                    shadowColor: DuoColors.secondaryButtonShadow,
                    textColor: DuoColors.primaryBlue,
                    height: 46,
                    isLoading: (currencyService.isLoading || timezoneService.isLoading),
                    icon: const Icon(Icons.refresh_rounded, color: DuoColors.primaryBlue, size: 20),
                    onPressed: (currencyService.isLoading || timezoneService.isLoading)
                        ? null
                        : () async {
                            await currencyService.fetchRatesFromApi();
                            await timezoneService.fetchTimezonesFromApi();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        currencyService.hasApiData
                                            ? Icons.check_circle_rounded
                                            : Icons.warning_rounded,
                                        color: currencyService.hasApiData
                                            ? DuoColors.questGreen
                                            : DuoColors.streakGold,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          currencyService.hasApiData
                                              ? 'Kurs & zona waktu berhasil diperbarui!'
                                              : 'Gagal memperbarui. Menggunakan data offline.',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: DuoColors.surface,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 4. PENGATURAN BIOMETRIK FINGERPRINT (Duolingo 3D)
            DuoCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isBiometricActive
                                  ? DuoColors.primaryBlue.withOpacity(0.18)
                                  : DuoColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isBiometricActive ? DuoColors.primaryBlue : DuoColors.surfaceBorder,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.fingerprint_rounded,
                              color: _isBiometricActive ? DuoColors.primaryBlue : DuoColors.textMuted,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LOGIN SIDIK JARI',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isBiometricActive ? 'Status: Aktif' : 'Status: Nonaktif',
                                style: TextStyle(
                                  color: _isBiometricActive ? DuoColors.questGreen : DuoColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isBiometricActive,
                        activeColor: DuoColors.primaryBlue,
                        onChanged: (bool value) => _handleToggleBiometric(value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isBiometricActive
                        ? 'Aktif — Anda dapat login langsung menggunakan sidik jari yang terdaftar di HP Anda.'
                        : 'Nonaktif — Nyalakan saklar untuk mengaktifkan login cepat dengan sidik jari.',
                    style: const TextStyle(color: DuoColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 5. Race Career Statistics (Duolingo 3D)
            DuoCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STATISTIK KOMPETISI',
                    style: TextStyle(
                      color: DuoColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Total Jarak', '42.5 KM', Icons.route_rounded, DuoColors.primaryBlue),
                      _buildStatColumn('Race Diikuti', '5 Acara', Icons.emoji_events_rounded, DuoColors.streakGold),
                      _buildStatColumn('Medali NFT', '3 Dicetak', Icons.military_tech_rounded, DuoColors.neonCyan),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 6. Shortcut Pusat Notifikasi Mobile (Duolingo 3D)
            DuoCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: DuoColors.primaryBlue.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DuoColors.primaryBlue, width: 1.5),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: DuoColors.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PUSAT NOTIFIKASI MOBILE',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Push alert race, flag-off, & AI Coach',
                          style: TextStyle(color: DuoColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: DuoColors.textMuted),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 7. Logout 3D Button (Duolingo Red Button)
            DuoButton(
              text: 'LOGOUT DARI AKUN',
              backgroundColor: DuoColors.heartRed,
              shadowColor: DuoColors.heartRedShadow,
              height: 50,
              icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
              onPressed: () => _confirmLogout(context),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DuoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: DuoColors.surfaceBorder, width: 2),
        ),
        title: const Text(
          'Keluar dari Aplikasi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Pilih aksi keluar:\n\n• "Logout": Keluar sesi akun saat ini.\n• "Hapus Akun & Reset": Membersihkan seluruh data sesi agar Anda dapat mendaftar akun baru dari awal.',
          style: TextStyle(color: DuoColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: DuoColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.resetAllAccounts();
              widget.onLogout();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: DuoColors.streakGold),
              foregroundColor: DuoColors.streakGold,
            ),
            child: const Text('Hapus & Reset', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DuoColors.heartRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: DuoColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ],
    );
  }
}

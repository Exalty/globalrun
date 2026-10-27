import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/timezone_service.dart';
import '../services/theme_service.dart';
import '../theme/duo_theme.dart';
import 'notification_screen.dart';
import 'topup_screen.dart';
import '../services/run_history_service.dart';
import '../services/blockchain_service.dart';
import 'run_history_screen.dart';
import 'blockchain_certificate_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  /// Opsional. Jika null dipakai BlockchainService() (singleton).
  final BlockchainService? blockchainService;

  const ProfileScreen({super.key, required this.onLogout, this.blockchainService});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final GlobalKey _biometricSectionKey = GlobalKey();

  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isBiometricActive = false;
  bool _isBiometricHighlighted = false;
  RunStats _stats = RunStats.empty;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _authService.getUserProfile();
    final bioEnabled = await _authService.isBiometricEnabled();
    final stats = await RunHistoryService().computeStats();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isBiometricActive = bioEnabled;
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  /// Membuka layar Top Up Saldo, lalu memuat ulang saldo jika ada perubahan.
  Future<void> _openTopUp() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TopUpScreen()),
    );
    if (changed == true) _loadProfile();
  }

  /// Statistik Kompetisi -> Riwayat Lari
  Future<void> _openRunHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RunHistoryScreen(
          blockchainService: widget.blockchainService ?? BlockchainService(),
        ),
      ),
    );
    if (mounted) _loadProfile(); // lari bisa dihapus di riwayat -> perbarui statistik
  }

  /// Statistik Kompetisi -> Sertifikat & Medali NFT
  Future<void> _openMedals() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlockchainCertificateScreen(
          blockchainService: widget.blockchainService ?? BlockchainService(),
        ),
      ),
    );
    if (mounted) _loadProfile();
  }

  /// Mengarahkan dan scroll halus ke kartu pengaturan sidik jari di halaman profil
  void _scrollToBiometricSetting() {
    final targetContext = _biometricSectionKey.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _isBiometricHighlighted = true);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.touch_app_rounded, color: DuoColors.primaryBlue),
              SizedBox(width: 8),
              Text('Mengarahkan ke menu pengaturan sidik jari...'),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _isBiometricHighlighted = false);
      });
    }
  }

  Future<void> _handleToggleBiometric(bool value) async {
    if (value) {
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
      await _authService.setBiometricEnabled(false);
      setState(() => _isBiometricActive = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login sidik jari dinonaktifkan.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.background,
        body: const Center(child: CircularProgressIndicator(color: DuoColors.primaryBlue)),
      );
    }

    final currencyService = context.watch<CurrencyService>();
    final timezoneService = context.watch<TimezoneService>();
    final themeService = context.watch<ThemeService>();

    final selectedCurrency = currencyService.selectedCurrency;
    final selectedTimezone = timezoneService.selectedTimezone;

    final name = (_userProfile?['name'] != null && _userProfile!['name'].toString().isNotEmpty)
        ? _userProfile!['name']
        : 'Atlet Global';
    final email = (_userProfile?['email'] != null && _userProfile!['email'].toString().isNotEmpty)
        ? _userProfile!['email']
        : 'email@kompetisi.com';
    // Cast aman: saldo bisa tersimpan sebagai int atau double
    final walletUsd = ((_userProfile?['wallet'] ?? 0.0) as num).toDouble();
    final walletFormatted = currencyService.formatCurrency(walletUsd, selectedCurrency);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'PROFIL ATLET',
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
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: palette.primaryBlue,
        backgroundColor: palette.surface,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // 1. Athlete Card Header
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
                          color: palette.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.primaryBlue, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primaryBlueShadow,
                              offset: const Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(Icons.person_rounded, size: 54, color: palette.primaryBlue),
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
                            border: Border.all(color: palette.surface, width: 2.5),
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name.toUpperCase(),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(color: palette.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DuoChip(
                        label: 'LEVEL 5 ATLET',
                        borderColor: DuoColors.streakGoldShadow,
                        backgroundColor: palette.background,
                        textColor: DuoColors.streakGold,
                      ),
                      const SizedBox(width: 8),
                      // Chip Status Sidik Jari (Bisa diklik untuk mengarahkan ke menu sidik jari)
                      DuoChip(
                        icon: Icon(
                          _isBiometricActive ? Icons.fingerprint_rounded : Icons.lock_outline_rounded,
                          color: _isBiometricActive ? DuoColors.questGreen : palette.textMuted,
                          size: 16,
                        ),
                        label: _isBiometricActive ? 'SIDIK JARI AKTIF' : 'SIDIK JARI MATI',
                        borderColor: _isBiometricActive ? DuoColors.questGreenShadow : palette.surfaceBorder,
                        backgroundColor: palette.background,
                        textColor: _isBiometricActive ? DuoColors.questGreen : palette.textMuted,
                        onTap: _scrollToBiometricSetting,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. DOMPET DIGITAL (Race Wallet)
            DuoCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DOMPET DIGITAL (RACE WALLET)',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: palette.primaryBlue.withOpacity(palette.isDark ? 0.18 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.primaryBlue, width: 1.5),
                        ),
                        child: Text(
                          selectedCurrency,
                          style: TextStyle(
                            color: palette.primaryBlue,
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
                      const Icon(Icons.account_balance_wallet_rounded, color: DuoColors.streakGold, size: 28),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            walletFormatted,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (selectedCurrency != 'USD')
                            Text(
                              '≈ \$${walletUsd.toStringAsFixed(2)} USD',
                              style: TextStyle(
                                color: palette.textMuted,
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
                    onPressed: _openTopUp,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 3. PENGATURAN TEMA APLIKASI (LIGHT MODE / DARK MODE)
            DuoCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: themeService.isDarkMode
                              ? DuoColors.streakGold.withOpacity(0.18)
                              : palette.primaryBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: themeService.isDarkMode ? DuoColors.streakGold : palette.primaryBlue,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          themeService.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: themeService.isDarkMode ? DuoColors.streakGold : palette.primaryBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TEMA TAMPILAN',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            themeService.isDarkMode ? 'Mode Gelap (Dark Mode)' : 'Mode Terang (Light Mode)',
                            style: TextStyle(
                              color: themeService.isDarkMode ? DuoColors.streakGold : palette.primaryBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: themeService.isDarkMode,
                    activeColor: DuoColors.streakGold,
                    inactiveThumbColor: palette.primaryBlue,
                    inactiveTrackColor: palette.primaryBlue.withOpacity(0.3),
                    onChanged: (bool isDark) {
                      themeService.setDarkMode(isDark);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 4. PENGATURAN MATA UANG & ZONA WAKTU
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
                          color: palette.primaryBlue.withOpacity(palette.isDark ? 0.18 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.primaryBlue, width: 1.5),
                        ),
                        child: Icon(Icons.currency_exchange_rounded, color: palette.primaryBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MATA UANG & ZONA WAKTU',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sinkronisasi API global kompetisi',
                              style: TextStyle(color: palette.textMuted, fontSize: 11),
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
                  Text(
                    'MATA UANG AKTIF',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.surfaceBorder, width: 2),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCurrency,
                      dropdownColor: palette.surface,
                      underline: const SizedBox(),
                      style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      items: currencyService.currencies.keys.map((c) {
                        final rate = currencyService.currencies[c]!;
                        return DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Text(
                                rate.symbol,
                                style: TextStyle(color: palette.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${rate.code} — ${rate.name}',
                                  style: TextStyle(color: palette.textPrimary, fontSize: 13),
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
                        currencyService.getRateLabel(selectedCurrency),
                        style: const TextStyle(color: DuoColors.questGreen, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Pilihan Zona Waktu
                  Text(
                    'ZONA WAKTU AKTIF',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.surfaceBorder, width: 2),
                    ),
                    child: DropdownButton<TimezoneModel>(
                      isExpanded: true,
                      value: selectedTimezone,
                      dropdownColor: palette.surface,
                      underline: const SizedBox(),
                      style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
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
                                  style: TextStyle(color: palette.textPrimary, fontSize: 13),
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
                        '${selectedTimezone.label} • ${timezoneService.getOffsetLabel(selectedTimezone)}',
                        style: const TextStyle(color: DuoColors.questGreen, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Refresh Button 3D
                  DuoButton(
                    text: (currencyService.isLoading || timezoneService.isLoading)
                        ? 'MEMPERBARUI DARI API...'
                        : 'PERBARUI KURS & ZONA WAKTU',
                    backgroundColor: palette.secondaryButton,
                    shadowColor: palette.secondaryButtonShadow,
                    textColor: palette.primaryBlue,
                    height: 46,
                    isLoading: (currencyService.isLoading || timezoneService.isLoading),
                    icon: Icon(Icons.refresh_rounded, color: palette.primaryBlue, size: 20),
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

            // 5. PENGATURAN BIOMETRIK FINGERPRINT (Duolingo 3D dengan Key Scroll)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: _isBiometricHighlighted
                    ? [
                        BoxShadow(
                          color: palette.primaryBlue.withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: DuoCard(
                key: _biometricSectionKey, // Key untuk Scrollable.ensureVisible
                borderColor: _isBiometricHighlighted ? palette.primaryBlue : palette.surfaceBorder,
                shadowColor: _isBiometricHighlighted ? palette.primaryBlueShadow : palette.surfaceShadow,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isBiometricHighlighted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: palette.primaryBlue.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.primaryBlue, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded, color: palette.primaryBlue, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'PENGATURAN SIDIK JARI TERPILIH',
                              style: TextStyle(
                                color: palette.primaryBlue,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isBiometricActive
                                    ? palette.primaryBlue.withOpacity(palette.isDark ? 0.18 : 0.12)
                                    : palette.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isBiometricActive ? palette.primaryBlue : palette.surfaceBorder,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.fingerprint_rounded,
                                color: _isBiometricActive ? palette.primaryBlue : palette.textMuted,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LOGIN SIDIK JARI',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isBiometricActive ? 'Status: Aktif' : 'Status: Nonaktif',
                                  style: TextStyle(
                                    color: _isBiometricActive ? DuoColors.questGreen : palette.textMuted,
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
                          activeColor: palette.primaryBlue,
                          onChanged: (bool value) => _handleToggleBiometric(value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isBiometricActive
                          ? 'Aktif — Anda dapat login langsung menggunakan sidik jari yang terdaftar di HP Anda.'
                          : 'Nonaktif — Nyalakan saklar untuk mengaktifkan login cepat dengan sidik jari.',
                      style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // 6. Race Career Statistics
            DuoCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STATISTIK KOMPETISI',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Total Jarak', '${_stats.totalKm.toStringAsFixed(2)} KM',
                          Icons.route_rounded, palette.primaryBlue, palette,
                          onTap: _openRunHistory),
                      _buildStatColumn('Race Diikuti', '${_stats.raceCount} Acara',
                          Icons.emoji_events_rounded, DuoColors.streakGold, palette,
                          onTap: _openRunHistory),
                      _buildStatColumn('Medali NFT', '${_stats.medalCount} Dicetak',
                          Icons.military_tech_rounded, palette.neonCyan, palette,
                          onTap: _openMedals),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 14, color: palette.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Ketuk untuk melihat riwayat lari & medali NFT',
                        style: TextStyle(color: palette.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 7. Shortcut Pusat Notifikasi Mobile
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
                      color: palette.primaryBlue.withOpacity(palette.isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.primaryBlue, width: 1.5),
                    ),
                    child: Icon(Icons.notifications_active_rounded, color: palette.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PUSAT NOTIFIKASI MOBILE',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Push alert race, flag-off, & AI Coach',
                          style: TextStyle(color: palette.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: palette.textMuted),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 7.5 Status Dual Database
            DuoCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: DuoColors.questGreen.withOpacity(palette.isDark ? 0.18 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DuoColors.questGreen, width: 1.5),
                        ),
                        child: const Icon(Icons.storage_rounded, color: DuoColors.questGreen, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ARSITEKTUR BASIS DATA',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Implementasi Dual Database (Lokal & Online)',
                              style: TextStyle(color: palette.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: DuoColors.surfaceBorder, height: 1),
                  const SizedBox(height: 12),
                  _buildDbRow(
                    label: 'Database Lokal',
                    system: 'PostgreSQL Server (Port 5000)',
                    palette: palette,
                  ),
                  const SizedBox(height: 10),
                  _buildDbRow(
                    label: 'Database Online',
                    system: 'Supabase Cloud (PostgreSQL)',
                    palette: palette,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 8. Logout 3D Button (Duolingo Red Button)
            DuoButton(
              text: 'LOGOUT DARI AKUN',
              backgroundColor: DuoColors.heartRed,
              shadowColor: DuoColors.heartRedShadow,
              height: 50,
              icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
              onPressed: () => _confirmLogout(context, palette),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, DuoColorPalette palette) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.surfaceBorder, width: 2),
        ),
        title: Text(
          'Keluar dari Aplikasi',
          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Pilih aksi keluar:\n\n• "Logout": Keluar sesi akun saat ini.\n• "Hapus Akun & Reset": Membersihkan seluruh data sesi agar Anda dapat mendaftar akun baru dari awal.',
          style: TextStyle(color: palette.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: palette.textMuted, fontWeight: FontWeight.bold)),
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

  Widget _buildStatColumn(
    String label,
    String value,
    IconData icon,
    Color color,
    DuoColorPalette palette, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDbRow({
    required String label,
    required String system,
    required DuoColorPalette palette,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
            Text(system, style: TextStyle(color: palette.textMuted, fontSize: 11)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: DuoColors.questGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: DuoColors.questGreen, width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: DuoColors.questGreen, size: 13),
              SizedBox(width: 4),
              Text(
                'AKTIF',
                style: TextStyle(color: DuoColors.questGreen, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
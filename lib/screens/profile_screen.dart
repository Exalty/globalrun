import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/timezone_service.dart';
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
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                  SizedBox(width: 8),
                  Text('Login sidik jari (biometrik) berhasil diaktifkan!'),
                ],
              ),
              backgroundColor: Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verifikasi sidik jari dibatalkan atau gagal.'),
              backgroundColor: Colors.redAccent,
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
            backgroundColor: Color(0xFF1E293B),
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
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }

    // Consume currency & timezone providers — otomatis rebuild saat berubah
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

    // Format wallet balance sesuai mata uang terpilih
    final walletFormatted = currencyService.formatCurrency(walletUsd, selectedCurrency);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Profil Atlet', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Athlete Card Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                        child: const Icon(Icons.person_rounded, size: 54, color: Colors.cyanAccent),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.cyanAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded, color: Colors.black, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isBiometricActive
                          ? Colors.cyanAccent.withOpacity(0.15)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isBiometricActive
                            ? Colors.cyanAccent.withOpacity(0.4)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isBiometricActive ? Icons.fingerprint_rounded : Icons.lock_outline_rounded,
                          color: _isBiometricActive ? Colors.cyanAccent : Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isBiometricActive ? 'Biometrik Aktif' : 'Biometrik Nonaktif',
                          style: TextStyle(
                            color: _isBiometricActive ? Colors.cyanAccent : Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ══════════════════════════════════════════════════════════
            // DOMPET DIGITAL — Saldo ditampilkan dalam mata uang terpilih
            // Perubahan mata uang di HomeScreen otomatis memperbarui di sini
            // ══════════════════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Dompet Digital (Race Wallet)',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const Spacer(),
                                // Badge mata uang aktif
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.tealAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    selectedCurrency,
                                    style: const TextStyle(
                                      color: Colors.tealAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Saldo dalam mata uang terpilih
                            Text(
                              walletFormatted,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Info konversi dari USD
                            if (selectedCurrency != 'USD')
                              Text(
                                '≈ \$${walletUsd.toStringAsFixed(2)} USD',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Top-up saldo berhasil disimulasikan!')),
                            );
                          },
                          icon: const Icon(Icons.add_card_rounded, size: 18),
                          label: const Text('Top Up'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ══════════════════════════════════════════════════════════
            // PENGATURAN MATA UANG & ZONA WAKTU (di halaman Profile)
            // ══════════════════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.currency_exchange_rounded, color: Colors.cyanAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mata Uang & Zona Waktu',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Perubahan berlaku di seluruh aplikasi',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // API status dot
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: currencyService.hasApiData ? Colors.greenAccent : Colors.orangeAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Pilihan Mata Uang
                  const Text('Mata Uang Aktif:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCurrency,
                      dropdownColor: const Color(0xFF1E293B),
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
                                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
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

                  // Kurs info
                  if (currencyService.hasApiData)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '📊 ${currencyService.getRateLabel(selectedCurrency)}',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Pilihan Zona Waktu
                  const Text('Zona Waktu Aktif:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<TimezoneModel>(
                      isExpanded: true,
                      value: selectedTimezone,
                      dropdownColor: const Color(0xFF1E293B),
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

                  // Timezone API info
                  if (timezoneService.hasApiData)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '🌍 ${selectedTimezone.label} • ${timezoneService.getOffsetLabel(selectedTimezone)}',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                      ),
                    ),

                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),

                  // Refresh dari API
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
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
                                              ? Colors.greenAccent
                                              : Colors.orangeAccent,
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
                                    backgroundColor: const Color(0xFF1E293B),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      icon: (currencyService.isLoading || timezoneService.isLoading)
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        (currencyService.isLoading || timezoneService.isLoading)
                            ? 'Memperbarui dari API...'
                            : 'Perbarui Kurs & Zona Waktu (API)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        side: const BorderSide(color: Colors.cyanAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // PENGATURAN BIOMETRIK FINGERPRINT (Bisa dinyalakan di menu profile)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isBiometricActive ? Colors.cyanAccent.withOpacity(0.4) : Colors.white12,
                ),
              ),
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
                                  ? Colors.cyanAccent.withOpacity(0.2)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.fingerprint_rounded,
                              color: _isBiometricActive ? Colors.cyanAccent : Colors.white54,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Login Sidik Jari',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isBiometricActive ? 'Status: Aktif' : 'Status: Nonaktif',
                                style: TextStyle(
                                  color: _isBiometricActive ? Colors.greenAccent : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isBiometricActive,
                        activeColor: Colors.cyanAccent,
                        onChanged: (bool value) => _handleToggleBiometric(value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isBiometricActive
                        ? 'Aktif — Anda dapat login langsung menggunakan sidik jari yang terdaftar di HP Anda.'
                        : 'Nonaktif — Nyalakan saklar untuk mengaktifkan login cepat dengan sidik jari.',
                    style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Race Career Statistics
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Statistik Kompetisi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Total Jarak', '42.5 KM', Icons.route_rounded, Colors.cyanAccent),
                      _buildStatColumn('Race Diikuti', '5 Acara', Icons.emoji_events_rounded, Colors.amberAccent),
                      _buildStatColumn('Medali NFT', '3 Dicetak', Icons.military_tech_rounded, Colors.purpleAccent),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Shortcut Pengaturan Notifikasi Mobile
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: Colors.cyanAccent, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pusat Notifikasi Mobile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 2),
                          Text('Push alert race, flag-off, & AI Coach', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Logout & Reset Session Button
            Center(
              child: TextButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Keluar dari Aplikasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Pilih aksi keluar:\n\n• "Logout": Keluar sesi akun saat ini.\n• "Hapus Akun & Reset": Membersihkan seluruh data sesi agar Anda dapat mendaftar akun baru dari awal.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.resetAllAccounts();
              widget.onLogout();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orangeAccent),
              foregroundColor: Colors.orangeAccent,
            ),
            child: const Text('Hapus & Reset'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

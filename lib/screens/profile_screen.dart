import 'package:flutter/material.dart';
import '../services/auth_service.dart';
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

  Future<void> _openDeviceSecuritySettings() async {
    await _authService.openDeviceSecuritySettings();
  }

  void _handleDeleteBiometric() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Hapus Sidik Jari?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Data sidik jari akun Anda akan dihapus dari aplikasi ini.\n\nAnda tidak bisa lagi masuk menggunakan sidik jari sampai Anda mendaftarkan jari baru di menu ini.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.removeBiometrics();
              setState(() => _isBiometricActive = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data sidik jari berhasil dihapus dari aplikasi.'),
                    backgroundColor: Color(0xFF1E293B),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus Sekarang'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }

    final name = (_userProfile?['name'] != null && _userProfile!['name'].toString().isNotEmpty)
        ? _userProfile!['name']
        : 'Atlet Global';
    final email = (_userProfile?['email'] != null && _userProfile!['email'].toString().isNotEmpty)
        ? _userProfile!['email']
        : 'email@kompetisi.com';
    final wallet = _userProfile?['wallet'] ?? 250.0;

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

            // Virtual Wallet Card (SRS Point: Dompet Digital)
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dompet Digital (Race Wallet)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('\$$wallet USD', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  ElevatedButton.icon(
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
                        ? 'Sidik jari aktif. Anda bisa langsung masuk di layar login menggunakan jari yang terdaftar di HP.'
                        : 'Nyalakan saklar untuk memindai sidik jari dan mengaktifkan fitur login biometrik.',
                    style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),
                  if (_isBiometricActive) ...[
                    Row(
                      children: [
                        // Tombol Buka Pengaturan HP
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openDeviceSecuritySettings,
                            icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                            label: const Text('Pengaturan HP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.cyanAccent,
                              side: const BorderSide(color: Colors.cyanAccent),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Tombol Hapus Sidik Jari
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _handleDeleteBiometric,
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: const Text('Hapus Sidik Jari', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Panduan saat biometrik nonaktif
                    OutlinedButton.icon(
                      onPressed: _openDeviceSecuritySettings,
                      icon: const Icon(Icons.settings_rounded, size: 16),
                      label: const Text(
                        'Daftarkan Jari Baru di Pengaturan HP',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '💡 Catatan: Sensor HP hanya menerima jari yang sudah terdaftar di Pengaturan HP Anda (Kata Sandi & Keamanan > Sidik Jari).',
                      style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.3),
                    ),
                  ],
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

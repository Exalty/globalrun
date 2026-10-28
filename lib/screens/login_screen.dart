import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/duo_theme.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _canUseBiometrics = false;
  bool _isBiometricConfigured = false;
  String? _errorMessage;

  // Status koneksi database
  bool _localDbConnected = false;
  bool _onlineDbConnected = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _checkDatabases();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final available = await _authService.canCheckBiometrics();
    final configured = await _authService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _canUseBiometrics = available;
        _isBiometricConfigured = configured;
      });
    }
  }

  bool _isCheckingDb = false;

  Future<void> _checkDatabases() async {
    if (_isCheckingDb) return;
    setState(() => _isCheckingDb = true);
    try {
      final status = await _authService.checkDatabaseStatus();
      if (mounted) {
        setState(() {
          _localDbConnected = status['local'] == true;
          _onlineDbConnected = status['online'] == true;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isCheckingDb = false);
      }
    }
  }

  // Submit Login atau Registrasi Langsung (Tanpa OTP)
  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isRegisterMode) {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          setState(() {
            _errorMessage = 'Nama lengkap wajib diisi!';
            _isLoading = false;
          });
          return;
        }

        if (email.isEmpty || password.isEmpty) {
          setState(() {
            _errorMessage = 'Email dan password wajib diisi!';
            _isLoading = false;
          });
          return;
        }

        if (password.length < 6) {
          setState(() {
            _errorMessage = 'Password minimal harus 6 karakter!';
            _isLoading = false;
          });
          return;
        }

        // Registrasi Dual-Database (Lokal + Online)
        final res = await _authService.register(
          name: name,
          email: email,
          password: password,
        );

        if (res['success'] == true) {
          if (res['source'] == 'cache' && mounted) {
            final palette = DuoColors.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: palette.streakGold, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        res['message'] ?? 'Login berhasil (Mode Cache Offline)',
                        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                backgroundColor: palette.surface,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          widget.onLoginSuccess();
        } else {
          setState(() => _errorMessage = res['message']);
        }
      } else {
        // Login Langsung
        if (email.isEmpty || password.isEmpty) {
          setState(() {
            _errorMessage = 'Email dan password wajib diisi!';
            _isLoading = false;
          });
          return;
        }

        final res = await _authService.login(
          email: email,
          password: password,
        );

        if (res['success'] == true) {
          if (res['source'] == 'cache' && mounted) {
            final palette = DuoColors.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: palette.streakGold, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        res['message'] ?? 'Login berhasil (Mode Cache Offline)',
                        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                backgroundColor: palette.surface,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          widget.onLoginSuccess();
        } else {
          setState(() => _errorMessage = res['message']);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final configured = await _authService.isBiometricEnabled();
      if (!configured) {
        _showBiometricNotConfiguredDialog();
        return;
      }

      final success = await _authService.authenticateWithBiometrics();
      if (success) {
        widget.onLoginSuccess();
      } else {
        setState(() => _errorMessage = 'Pemindaian sidik jari dibatalkan atau gagal.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Kesalahan sensor biometrik: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBiometricNotConfiguredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DuoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: DuoColors.surfaceBorder, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.fingerprint_rounded, color: DuoColors.primaryBlue, size: 28),
            SizedBox(width: 10),
            Text('Biometrik Belum Aktif', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        content: const Text(
          'Login sidik jari belum dinyalakan untuk akun ini.\n\nSilakan masuk terlebih dahulu menggunakan email dan password, lalu nyalakan saklar "Sidik Jari" di menu Profil.',
          style: TextStyle(color: DuoColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          DuoButton(
            text: 'MENGERTI',
            height: 44,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Duolingo-style 3D Mascot/Icon Badge
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: DuoColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: DuoColors.primaryBlue, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: DuoColors.primaryBlueShadow,
                        offset: Offset(0, 5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.directions_run_rounded,
                      size: 54,
                      color: DuoColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'GLOBAL RUN',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegisterMode
                      ? 'Daftarkan atlet baru dan mulai petualangan lari!'
                      : 'Masuk dan taklukkan leaderboard kompetisi!',
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // DuoCard Form Container
                DuoCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      // Mode Selector Pill (Masuk / Daftar)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: palette.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: palette.surfaceBorder, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildModeTab(
                                title: 'MASUK',
                                isActive: !_isRegisterMode,
                                onTap: () {
                                  if (_isRegisterMode) {
                                    setState(() {
                                      _isRegisterMode = false;
                                      _errorMessage = null;
                                    });
                                  }
                                },
                              ),
                            ),
                            Expanded(
                              child: _buildModeTab(
                                title: 'DAFTAR',
                                isActive: _isRegisterMode,
                                onTap: () {
                                  if (!_isRegisterMode) {
                                    setState(() {
                                      _isRegisterMode = true;
                                      _errorMessage = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Input Nama Lengkap (Khusus Mode Daftar)
                      if (_isRegisterMode) ...[
                        _buildTextField(
                          controller: _nameController,
                          label: 'Nama Lengkap',
                          hint: 'Contoh: Bima Perkasa',
                          icon: Icons.person_rounded,
                          palette: palette,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Input Email
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'contoh@domain.com',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        palette: palette,
                      ),
                      const SizedBox(height: 14),

                      // Input Password
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscureText: true,
                        palette: palette,
                      ),

                      // Banner Pesan Error
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: DuoColors.heartRed.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DuoColors.heartRed, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: DuoColors.heartRed, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: DuoColors.heartRed,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      // Tombol Submit 3D Duolingo
                      DuoButton(
                        text: _isRegisterMode ? 'DAFTAR SEKARANG' : 'MASUK SEKARANG',
                        width: double.infinity,
                        isLoading: _isLoading,
                        onPressed: _handleSubmit,
                      ),

                      // Tombol Sidik Jari (Biometrik) di mode Login
                      if (!_isRegisterMode && _canUseBiometrics) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Divider(color: palette.surfaceBorder, thickness: 1.5)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'ATAU',
                                style: TextStyle(
                                  color: DuoColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: palette.surfaceBorder, thickness: 1.5)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        DuoButton(
                          text: _isBiometricConfigured ? 'LOGIN SIDIK JARI' : 'SIDIK JARI (BELUM AKTIF)',
                          backgroundColor: DuoColors.secondaryButton,
                          shadowColor: DuoColors.secondaryButtonShadow,
                          textColor: _isBiometricConfigured ? DuoColors.primaryBlue : DuoColors.textMuted,
                          width: double.infinity,
                          icon: Icon(
                            Icons.fingerprint_rounded,
                            color: _isBiometricConfigured ? palette.primaryBlue : palette.textMuted,
                            size: 24,
                          ),
                          onPressed: _isLoading ? null : _handleBiometricLogin,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Indikator Dual Database Status (Lokal & Online) - Bisa diklik untuk cek ulang
                InkWell(
                  onTap: _isCheckingDb ? null : _checkDatabases,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.surfaceBorder, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isCheckingDb
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.primaryBlue,
                                ),
                              )
                            : Icon(
                                Icons.storage_rounded,
                                size: 15,
                                color: palette.textMuted,
                              ),
                        const SizedBox(width: 8),
                        _buildDbStatusDot(_localDbConnected, 'DB Lokal', palette),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('•', style: TextStyle(color: palette.textMuted, fontSize: 12)),
                        ),
                        _buildDbStatusDot(_onlineDbConnected, 'DB Online (Supabase)', palette),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.refresh_rounded,
                          size: 13,
                          color: palette.textMuted.withOpacity(0.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDbStatusDot(bool isOnline, String label, DuoColorPalette palette) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? palette.questGreen : palette.streakGold,
            boxShadow: [
              BoxShadow(
                color: (isOnline ? palette.questGreen : palette.streakGold).withOpacity(0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: isOnline ? palette.questGreen : palette.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildModeTab({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? DuoColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? DuoColors.primaryBlue.withOpacity(0.5) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? DuoColors.primaryBlue : DuoColors.textMuted,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required DuoColorPalette palette,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: palette.textMuted, fontSize: 13),
            prefixIcon: Icon(icon, color: palette.primaryBlue, size: 20),
            filled: true,
            fillColor: palette.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: palette.surfaceBorder, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: palette.primaryBlue, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

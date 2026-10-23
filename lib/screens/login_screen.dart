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

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
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

  Future<void> _handlePasswordSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegisterMode) {
        if (_nameController.text.trim().isEmpty) {
          setState(() {
            _errorMessage = 'Nama lengkap wajib diisi!';
            _isLoading = false;
          });
          return;
        }

        if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
          setState(() {
            _errorMessage = 'Email dan password wajib diisi!';
            _isLoading = false;
          });
          return;
        }

        final res = await _authService.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (res['success'] == true) {
          widget.onLoginSuccess();
        } else {
          setState(() => _errorMessage = res['message']);
        }
      } else {
        if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
          setState(() {
            _errorMessage = 'Email dan password wajib diisi!';
            _isLoading = false;
          });
          return;
        }

        final res = await _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (res['success'] == true) {
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
    return Scaffold(
      backgroundColor: DuoColors.background,
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

                const Text(
                  'GLOBAL RUN',
                  style: TextStyle(
                    color: Colors.white,
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
                  style: const TextStyle(color: DuoColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // DuoCard Form Container
                DuoCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      // Mode Selector Pill (Masuk / Daftar)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: DuoColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: DuoColors.surfaceBorder, width: 1.5),
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

                      if (_isRegisterMode) ...[
                        _buildTextField(
                          controller: _nameController,
                          label: 'Nama Lengkap',
                          hint: 'Contoh: Bima Perkasa',
                          icon: Icons.person_rounded,
                        ),
                        const SizedBox(height: 14),
                      ],

                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'contoh@domain.com',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscureText: true,
                      ),

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
                        text: _isRegisterMode ? 'DAFTAR SEKARANG' : 'MASUK DENGAN SANDI',
                        width: double.infinity,
                        isLoading: _isLoading,
                        onPressed: _handlePasswordSubmit,
                      ),

                      // Tombol Sidik Jari (Biometrik) di mode Login
                      if (!_isRegisterMode && _canUseBiometrics) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: DuoColors.surfaceBorder, thickness: 1.5)),
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
                            const Expanded(child: Divider(color: DuoColors.surfaceBorder, thickness: 1.5)),
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
                            color: _isBiometricConfigured ? DuoColors.primaryBlue : DuoColors.textMuted,
                            size: 24,
                          ),
                          onPressed: _isLoading ? null : _handleBiometricLogin,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: DuoColors.textSecondary,
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: DuoColors.textMuted, fontSize: 13),
            prefixIcon: Icon(icon, color: DuoColors.primaryBlue, size: 20),
            filled: true,
            fillColor: DuoColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: DuoColors.surfaceBorder, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: DuoColors.primaryBlue, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

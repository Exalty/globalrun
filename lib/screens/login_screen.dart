import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  // Tidak ada dummy email/password; form kosong untuk pendaftaran/login manual
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
      setState(() => _errorMessage = 'Terjadi kesalahan sistem: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBiometricLogin() async {
    // Cek apakah pengguna sudah mengaktifkan biometrik di menu Profil
    final isConfigured = await _authService.isBiometricEnabled();

    if (!isConfigured) {
      _showBiometricNotConfiguredDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.loginWithBiometrics();
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
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.fingerprint_rounded, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Text('Biometrik Belum Aktif', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Login sidik jari belum dinyalakan untuk akun ini.\n\nSilakan masuk terlebih dahulu menggunakan email dan password, lalu nyalakan "Login Sidik Jari" di menu Profil.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.cyanAccent, Colors.blueAccent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_run_rounded,
                    size: 54,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'GLOBAL VIRTUAL RACE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegisterMode ? 'Daftar akun atlet baru secara manual' : 'Masuk untuk sinkronisasi lomba & leaderboard',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      if (_isRegisterMode) ...[
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Nama Lengkap',
                            hintText: 'Contoh: Bima Perkasa',
                            hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                            labelStyle: const TextStyle(color: Colors.white60),
                            prefixIcon: const Icon(Icons.person_rounded, color: Colors.cyanAccent),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'contoh@domain.com',
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                          labelStyle: const TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(Icons.email_rounded, color: Colors.cyanAccent),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(Icons.lock_rounded, color: Colors.cyanAccent),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Tombol Submit Manual (Register / Login)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handlePasswordSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : Text(
                                  _isRegisterMode ? 'DAFTAR SEKARANG' : 'MASUK DENGAN SANDI',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                                ),
                        ),
                      ),

                      // Tombol Biometrik Fingerprint (Hanya di mode Login)
                      if (!_isRegisterMode && _canUseBiometrics) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Colors.white24)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('ATAU', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                            ),
                            const Expanded(child: Divider(color: Colors.white24)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleBiometricLogin,
                          icon: Icon(
                            Icons.fingerprint_rounded,
                            color: _isBiometricConfigured ? Colors.cyanAccent : Colors.white38,
                            size: 28,
                          ),
                          label: Text(
                            _isBiometricConfigured
                                ? 'Masuk Sidik Jari (Biometrik)'
                                : 'Masuk Sidik Jari (Belum Aktif)',
                            style: TextStyle(
                              color: _isBiometricConfigured ? Colors.white : Colors.white60,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            side: BorderSide(
                              color: _isBiometricConfigured ? Colors.cyanAccent : Colors.white24,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                // Toggle Login / Register Mode
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isRegisterMode = !_isRegisterMode;
                      _errorMessage = null;
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      text: _isRegisterMode ? 'Sudah memiliki akun? ' : 'Belum punya akun kompetisi? ',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                      children: [
                        TextSpan(
                          text: _isRegisterMode ? 'Masuk di sini' : 'Daftar sekarang',
                          style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
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
}

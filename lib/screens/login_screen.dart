import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _otpController = TextEditingController();

  bool _isRegisterMode = false;
  bool _isRegOtpPending = false; // Menunggu verifikasi OTP registrasi
  bool _isOtpMode = false; // false = login sandi, true = login kode email (OTP)
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;
  int _otpCooldown = 0;
  Timer? _cooldownTimer;

  bool _canUseBiometrics = false;
  bool _isBiometricConfigured = false;
  String? _errorMessage;
  String? _successMessage;

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
    _otpController.dispose();
    _cooldownTimer?.cancel();
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

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    setState(() => _otpCooldown = 60);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCooldown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _otpCooldown = 0);
        }
      } else {
        if (mounted) {
          setState(() => _otpCooldown--);
        }
      }
    });
  }

  // Permintaan Kirim Kode Verifikasi ke Email (Mode Login OTP)
  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Silakan isi alamat email terlebih dahulu!';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final res = await _authService.sendEmailOtp(email);
      if (res['success'] == true) {
        setState(() {
          _otpSent = true;
          _successMessage = res['message'] ?? 'Kode verifikasi telah dikirim ke email!';
          _errorMessage = null;
        });
        _startCooldownTimer();

        if (mounted) {
          _showOtpSentDialog(email, res['demo_code']?.toString());
        }
      } else {
        setState(() {
          _errorMessage = res['message'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengirim kode verifikasi: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
      }
    }
  }

  // Verifikasi Kode OTP & Masuk (Mode Login OTP)
  Future<void> _handleVerifyLoginOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Email wajib diisi!');
      return;
    }

    if (otp.isEmpty || otp.length < 6) {
      setState(() => _errorMessage = 'Masukkan 6 digit kode verifikasi!');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _authService.verifyEmailOtp(email: email, code: otp);
      if (res['success'] == true) {
        widget.onLoginSuccess();
      } else {
        setState(() => _errorMessage = res['message']);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Verifikasi Kode OTP Pendaftaran Akun Baru
  Future<void> _handleVerifyRegistrationOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length < 6) {
      setState(() => _errorMessage = 'Masukkan 6 digit kode verifikasi!');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _authService.verifyRegistrationOtp(
        email: email,
        code: otp,
      );

      if (res['success'] == true) {
        widget.onLoginSuccess();
      } else {
        setState(() => _errorMessage = res['message']);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Registrasi atau Login dengan Sandi
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

        if (_passwordController.text.length < 6) {
          setState(() {
            _errorMessage = 'Password minimal harus 6 karakter!';
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
          if (res['requireOtp'] == true) {
            // Perlu verifikasi OTP pendaftaran
            setState(() {
              _isRegOtpPending = true;
              _successMessage = res['message'];
              _errorMessage = null;
              _otpController.clear();
            });
            _startCooldownTimer();
            if (mounted) {
              _showOtpSentDialog(_emailController.text.trim(), res['demo_code']?.toString());
            }
          } else {
            widget.onLoginSuccess();
          }
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

  void _showOtpSentDialog(String email, String? demoCode) {
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
            Icon(Icons.mark_email_read_rounded, color: DuoColors.questGreen, size: 28),
            SizedBox(width: 10),
            Text('Kode Terkirim!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kode verifikasi 6 digit telah dikirim ke:\n$email',
              style: const TextStyle(color: DuoColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Silakan buka kotak masuk email Anda (periksa juga folder Spam/Promotions jika belum muncul).',
              style: TextStyle(color: DuoColors.textMuted, fontSize: 12),
            ),
            if (demoCode != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DuoColors.questGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DuoColors.questGreen, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Text('KODE ANDA', style: TextStyle(color: DuoColors.questGreen, fontSize: 11, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      demoCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (demoCode != null)
            TextButton(
              onPressed: () {
                _otpController.text = demoCode;
                Navigator.pop(ctx);
              },
              child: const Text('TEMPEL KE FORM', style: TextStyle(color: DuoColors.questGreen, fontWeight: FontWeight.bold)),
            ),
          DuoButton(
            text: 'MENGERTI',
            height: 44,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
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
          'Login sidik jari belum dinyalakan untuk akun ini.\n\nSilakan masuk terlebih dahulu menggunakan email dan password/kode verifikasi, lalu nyalakan saklar "Sidik Jari" di menu Profil.',
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
                      ? (_isRegOtpPending
                          ? 'Aktivasi akun atlet baru dengan kode email'
                          : 'Daftarkan atlet baru dan mulai petualangan lari!')
                      : (_isOtpMode
                          ? 'Minta kode verifikasi 6 digit ke email terdaftar Anda'
                          : 'Masuk dan taklukkan leaderboard kompetisi!'),
                  style: const TextStyle(color: DuoColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // DuoCard Form Container
                DuoCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      // Mode Selector Pill (Masuk / Daftar) - Sembunyikan saat verifikasi OTP registrasi berlangsung
                      if (!_isRegOtpPending) ...[
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
                                        _isRegOtpPending = false;
                                        _errorMessage = null;
                                        _successMessage = null;
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
                                        _isRegOtpPending = false;
                                        _errorMessage = null;
                                        _successMessage = null;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Jika di mode MASUK, sediakan opsi metode: Sandi atau Kode Email (OTP)
                      if (!_isRegisterMode) ...[
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: palette.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: palette.surfaceBorder, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildSubTab(
                                  title: 'KATA SANDI',
                                  icon: Icons.key_rounded,
                                  isActive: !_isOtpMode,
                                  onTap: () {
                                    setState(() {
                                      _isOtpMode = false;
                                      _errorMessage = null;
                                      _successMessage = null;
                                    });
                                  },
                                  palette: palette,
                                ),
                              ),
                              Expanded(
                                child: _buildSubTab(
                                  title: 'KODE EMAIL',
                                  icon: Icons.mark_email_read_rounded,
                                  isActive: _isOtpMode,
                                  onTap: () {
                                    setState(() {
                                      _isOtpMode = true;
                                      _errorMessage = null;
                                      _successMessage = null;
                                    });
                                  },
                                  palette: palette,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // FORM SECTION DINAMIS
                      if (_isRegisterMode) ...[
                        if (_isRegOtpPending) ...[
                          // STEP 2 REGISTRASI: VERIFIKASI OTP EMAIL
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: DuoColors.questGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: DuoColors.questGreen, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.mark_email_unread_rounded, color: DuoColors.questGreen, size: 26),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Verifikasi Email Pendaftaran',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Kode OTP 6 digit telah dikirim ke ${_emailController.text.trim()}. Masukkan di bawah untuk mengaktifkan akun:',
                                        style: const TextStyle(color: DuoColors.textSecondary, fontSize: 11, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Input Kode 6 Digit
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'KODE AKTIVASI (6 DIGIT)',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 6,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 8,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '••••••',
                                  hintStyle: TextStyle(
                                    color: palette.textMuted,
                                    letterSpacing: 8,
                                    fontSize: 22,
                                  ),
                                  prefixIcon: const Icon(Icons.verified_user_rounded, color: DuoColors.questGreen, size: 22),
                                  filled: true,
                                  fillColor: palette.background,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: DuoColors.questGreen, width: 2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: DuoColors.questGreen, width: 2.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          DuoButton(
                            text: 'VERIFIKASI & AKTIFKAN AKUN',
                            width: double.infinity,
                            backgroundColor: DuoColors.questGreen,
                            shadowColor: DuoColors.questGreenShadow,
                            isLoading: _isLoading,
                            onPressed: _handleVerifyRegistrationOtp,
                          ),
                          const SizedBox(height: 12),

                          // Tombol Kirim Ulang & Ubah Email
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isRegOtpPending = false;
                                    _errorMessage = null;
                                  });
                                },
                                child: const Text(
                                  '← Ubah Data',
                                  style: TextStyle(color: DuoColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              TextButton(
                                onPressed: (_isSendingOtp || _otpCooldown > 0)
                                    ? null
                                    : () async {
                                        setState(() => _isSendingOtp = true);
                                        await _authService.sendEmailOtp(_emailController.text.trim());
                                        setState(() => _isSendingOtp = false);
                                        _startCooldownTimer();
                                      },
                                child: Text(
                                  _otpCooldown > 0 ? 'Kirim ulang ($_otpCooldown s)' : 'Kirim Ulang Kode',
                                  style: TextStyle(
                                    color: _otpCooldown > 0 ? DuoColors.textMuted : DuoColors.primaryBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // STEP 1 REGISTRASI: ISI NAMA, EMAIL, PASSWORD
                          _buildTextField(
                            controller: _nameController,
                            label: 'Nama Lengkap',
                            hint: 'Contoh: Bima Perkasa',
                            icon: Icons.person_rounded,
                            palette: palette,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'contoh@domain.com',
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            palette: palette,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Minimal 6 karakter',
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                            palette: palette,
                          ),
                          const SizedBox(height: 22),
                          DuoButton(
                            text: 'DAFTAR SEKARANG',
                            width: double.infinity,
                            isLoading: _isLoading,
                            onPressed: _handlePasswordSubmit,
                          ),
                        ],
                      ] else if (_isOtpMode) ...[
                        // MODE LOGIN DENGAN KODE EMAIL (OTP)
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email Terkait Akun',
                          hint: 'Masukkan email terdaftar',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          palette: palette,
                        ),
                        const SizedBox(height: 14),

                        // Tombol Minta Kode Verifikasi
                        DuoButton(
                          text: _otpCooldown > 0
                              ? 'KIRIM ULANG ($_otpCooldown DTIK)'
                              : (_otpSent ? 'KIRIM ULANG KODE' : 'MINTA KODE VERIFIKASI'),
                          width: double.infinity,
                          backgroundColor: _otpCooldown > 0 ? DuoColors.secondaryButton : DuoColors.primaryBlue,
                          shadowColor: _otpCooldown > 0 ? DuoColors.secondaryButtonShadow : DuoColors.primaryBlueShadow,
                          textColor: _otpCooldown > 0 ? DuoColors.textMuted : Colors.white,
                          icon: Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: _otpCooldown > 0 ? DuoColors.textMuted : Colors.white,
                          ),
                          isLoading: _isSendingOtp,
                          onPressed: (_isSendingOtp || _otpCooldown > 0) ? null : _handleSendOtp,
                        ),

                        if (_otpSent) ...[
                          const SizedBox(height: 18),
                          // Input Kode 6 Digit
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'KODE VERIFIKASI (6 DIGIT)',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 6,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 8,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '••••••',
                                  hintStyle: TextStyle(
                                    color: palette.textMuted,
                                    letterSpacing: 8,
                                    fontSize: 22,
                                  ),
                                  prefixIcon: const Icon(Icons.pin_rounded, color: DuoColors.questGreen, size: 22),
                                  filled: true,
                                  fillColor: palette.background,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: DuoColors.questGreen, width: 2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: DuoColors.questGreen, width: 2.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          DuoButton(
                            text: 'VERIFIKASI & MASUK',
                            width: double.infinity,
                            backgroundColor: DuoColors.questGreen,
                            shadowColor: DuoColors.questGreenShadow,
                            isLoading: _isLoading,
                            onPressed: _handleVerifyLoginOtp,
                          ),
                        ],
                      ] else ...[
                        // MODE LOGIN DENGAN PASSWORD
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'contoh@domain.com',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          palette: palette,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          obscureText: true,
                          palette: palette,
                        ),
                        const SizedBox(height: 22),
                        DuoButton(
                          text: 'MASUK DENGAN SANDI',
                          width: double.infinity,
                          isLoading: _isLoading,
                          onPressed: _handlePasswordSubmit,
                        ),

                        // Tombol Sidik Jari (Biometrik)
                        if (_canUseBiometrics) ...[
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

                      // Banner Pesan Sukses
                      if (_successMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: DuoColors.questGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DuoColors.questGreen, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: DuoColors.questGreen, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: const TextStyle(
                                    color: DuoColors.questGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

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

  Widget _buildSubTab({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required DuoColorPalette palette,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? palette.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isActive ? palette.primaryBlue.withOpacity(0.4) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? palette.primaryBlue : palette.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isActive ? palette.primaryBlue : palette.textMuted,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
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

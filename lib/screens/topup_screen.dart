import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/payment_service.dart';
import '../theme/duo_theme.dart';

class _PayMethod {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _PayMethod(this.id, this.name, this.subtitle, this.icon, this.color);
}

/// Top up saldo (SIMULASI): isi nominal, pilih metode, langsung disetujui.
/// Nominal diinput dalam IDR lalu dikonversi ke USD (satuan saldo) memakai
/// kurs dari CurrencyService.
class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  static const int _minIdr = 10000;
  static const int _maxIdr = 10000000;
  static const List<int> _quickAmounts = [50000, 100000, 250000, 500000];

  static const List<_PayMethod> _methods = [
    _PayMethod('gopay', 'GoPay', 'Dompet digital', Icons.account_balance_wallet_rounded,
        Color(0xFF00AA13)),
    _PayMethod('shopeepay', 'ShopeePay', 'Dompet digital', Icons.shopping_bag_rounded,
        Color(0xFFEE4D2D)),
    _PayMethod('mbanking', 'M-Banking', 'Transfer bank', Icons.account_balance_rounded,
        Color(0xFF1E88E5)),
  ];

  final TextEditingController _amountCtrl = TextEditingController();
  final NumberFormat _idrFmt = NumberFormat('#,###', 'id_ID');

  String? _methodId;
  bool _processing = false;
  double _balanceUsd = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final b = await AuthService().getWalletUsd();
    if (mounted) setState(() => _balanceUsd = b);
  }

  int get _amount => int.tryParse(_amountCtrl.text) ?? 0;

  bool get _amountValid => _amount >= _minIdr && _amount <= _maxIdr;
  bool get _canSubmit => _amountValid && _methodId != null && !_processing;

  String _idr(num v) => 'Rp ${_idrFmt.format(v)}';

  void _setAmount(int v) {
    _amountCtrl.text = v.toString();
    _amountCtrl.selection = TextSelection.collapsed(offset: _amountCtrl.text.length);
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();

    final currency = context.read<CurrencyService>();
    final rate = currency.currencies['IDR']?.ratePerUsd ?? 16250.0;
    final method = _methods.firstWhere((m) => m.id == _methodId);
    final amount = _amount;

    setState(() => _processing = true);

    // Simulasi proses pembayaran
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      await PaymentService().topUp(
        amountIdr: amount.toDouble(),
        methodName: method.name,
        idrPerUsd: rate,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Top up gagal: $e'),
          backgroundColor: DuoColors.heartRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final newBalance = await AuthService().getWalletUsd();
    if (!mounted) return;
    setState(() {
      _processing = false;
      _balanceUsd = newBalance;
    });

    final palette = DuoColors.of(context);
    final selected = currency.selectedCurrency;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.surfaceBorder, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: DuoColors.questGreen, size: 26),
            const SizedBox(width: 8),
            Text('Top Up Berhasil',
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          '${_idr(amount)} via ${method.name} langsung masuk ke saldo kamu.\n\n'
          'Saldo sekarang: ${currency.formatCurrency(newBalance, selected)}',
          style: TextStyle(color: palette.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: DuoColors.questGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (mounted) Navigator.pop(context, true); // true = saldo berubah
  }

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    final currency = context.watch<CurrencyService>();
    final selected = currency.selectedCurrency;
    final rate = currency.currencies['IDR']?.ratePerUsd ?? 16250.0;
    final previewUsd = _amount / rate;

    String? amountError;
    if (_amountCtrl.text.isNotEmpty && !_amountValid) {
      amountError = _amount < _minIdr
          ? 'Minimal top up ${_idr(_minIdr)}'
          : 'Maksimal top up ${_idr(_maxIdr)}';
    }

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text('TOP UP SALDO',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 18,
                color: palette.textPrimary)),
        backgroundColor: palette.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        shape: Border(bottom: BorderSide(color: palette.surfaceBorder, width: 2)),
      ),
      body: AbsorbPointer(
        absorbing: _processing,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Saldo saat ini
              DuoCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: DuoColors.streakGold, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SALDO SAAT INI',
                              style: TextStyle(
                                  color: palette.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8)),
                          const SizedBox(height: 2),
                          Text(currency.formatCurrency(_balanceUsd, selected),
                              style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Input nominal
              Text('NOMINAL TOP UP (IDR)',
                  style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: amountError != null ? DuoColors.heartRed : palette.surfaceBorder,
                    width: 2,
                  ),
                ),
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                      color: palette.textPrimary, fontSize: 20, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    prefixText: 'Rp  ',
                    prefixStyle: TextStyle(
                        color: palette.primaryBlue, fontSize: 20, fontWeight: FontWeight.w900),
                    hintText: '0',
                    hintStyle: TextStyle(color: palette.textMuted),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (amountError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(amountError,
                      style: const TextStyle(
                          color: DuoColors.heartRed,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                )
              else if (_amount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${_idr(_amount)}  ≈  \$${previewUsd.toStringAsFixed(2)} USD',
                    style: TextStyle(
                        color: palette.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 12),

              // Nominal cepat
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickAmounts.map((v) {
                  final active = _amount == v;
                  return InkWell(
                    onTap: () => _setAmount(v),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? palette.primaryBlue.withOpacity(palette.isDark ? 0.20 : 0.14)
                            : palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active ? palette.primaryBlue : palette.surfaceBorder,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        _idr(v),
                        style: TextStyle(
                          color: active ? palette.primaryBlue : palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Metode pembayaran
              Text('METODE PEMBAYARAN',
                  style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              ..._methods.map((m) {
                final active = _methodId == m.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => setState(() => _methodId = m.id),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: active ? m.color.withOpacity(0.12) : palette.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: active ? m.color : palette.surfaceBorder,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: m.color.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(m.icon, color: m.color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    style: TextStyle(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14)),
                                Text(m.subtitle,
                                    style: TextStyle(color: palette.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Icon(
                            active
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: active ? m.color : palette.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),

              DuoButton(
                text: _processing ? 'MEMPROSES PEMBAYARAN...' : 'TOP UP SEKARANG',
                height: 50,
                backgroundColor: DuoColors.questGreen,
                shadowColor: DuoColors.questGreenShadow,
                textColor: Colors.white,
                isLoading: _processing,
                icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                onPressed: _canSubmit ? _submit : null,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
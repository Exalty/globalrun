import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Hasil pembayaran biaya pendaftaran race.
enum PayResult { success, free, alreadyPaid, insufficient }

/// Satu baris riwayat transaksi (simulasi).
class PaymentTransaction {
  final String id;
  final String type; // 'topup' | 'entry'
  final String title; // contoh: "Top Up via GoPay" / nama race
  final double amountUsd; // positif = uang masuk, negatif = uang keluar
  final DateTime createdAt;

  const PaymentTransaction({
    required this.id,
    required this.type,
    required this.title,
    required this.amountUsd,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'amountUsd': amountUsd,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PaymentTransaction.fromJson(Map<String, dynamic> j) => PaymentTransaction(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        amountUsd: (j['amountUsd'] as num).toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// Pembayaran SIMULASI: tidak ada uang sungguhan yang diproses.
/// Saldo disimpan di AuthService (SharedPreferences, satuan USD).
class PaymentService {
  static final PaymentService _instance = PaymentService._();
  factory PaymentService() => _instance;
  PaymentService._();

  static const String _paidKey = 'paid_event_ids';
  static const String _txKey = 'payment_transactions';
  static const int _maxTx = 100;

  final AuthService _auth = AuthService();

  Future<bool> isPaid(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_paidKey) ?? const <String>[]).contains(eventId);
  }

  /// Potong saldo untuk biaya pendaftaran. Aman dipanggil berulang:
  /// event yang sudah dibayar tidak ditagih lagi.
  Future<PayResult> payEntryFee({
    required String eventId,
    required String eventTitle,
    required double feeUsd,
  }) async {
    if (feeUsd <= 0) return PayResult.free;
    if (await isPaid(eventId)) return PayResult.alreadyPaid;

    final ok = await _auth.deductFromWallet(feeUsd); // cek saldo di dalam method
    if (!ok) return PayResult.insufficient;

    final prefs = await SharedPreferences.getInstance();
    final paid = prefs.getStringList(_paidKey) ?? <String>[];
    if (!paid.contains(eventId)) paid.add(eventId);
    await prefs.setStringList(_paidKey, paid);

    await _addTransaction(PaymentTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      type: 'entry',
      title: 'Biaya pendaftaran: $eventTitle',
      amountUsd: -feeUsd,
      createdAt: DateTime.now(),
    ));
    return PayResult.success;
  }

  /// Top up simulasi: langsung disetujui. Nominal dalam IDR, dikonversi ke USD.
  Future<double> topUp({
    required double amountIdr,
    required String methodName,
    required double idrPerUsd,
  }) async {
    final usd = amountIdr / idrPerUsd;
    await _auth.addToWallet(usd);
    await _addTransaction(PaymentTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      type: 'topup',
      title: 'Top Up via $methodName',
      amountUsd: usd,
      createdAt: DateTime.now(),
    ));
    return usd;
  }

  Future<List<PaymentTransaction>> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_txKey) ?? const <String>[];
    final out = <PaymentTransaction>[];
    for (final s in raw) {
      try {
        out.add(PaymentTransaction.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Transaksi rusak: $e');
      }
    }
    return out; // terbaru dulu
  }

  Future<void> _addTransaction(PaymentTransaction tx) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_txKey) ?? <String>[];
    list.insert(0, jsonEncode(tx.toJson()));
    if (list.length > _maxTx) list.removeRange(_maxTx, list.length);
    await prefs.setStringList(_txKey, list);
  }
}
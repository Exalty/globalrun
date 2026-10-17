import 'package:intl/intl.dart';

class CurrencyRate {
  final String code; // USD, IDR, EUR, GBP, JPY, SGD
  final String symbol;
  final String name;
  final double ratePerUsd; // base 1 USD = rate

  const CurrencyRate({
    required this.code,
    required this.symbol,
    required this.name,
    required this.ratePerUsd,
  });
}

class CurrencyService {
  // Rates against USD (base)
  static final Map<String, CurrencyRate> currencies = {
    'USD': const CurrencyRate(code: 'USD', symbol: '\$', name: 'US Dollar', ratePerUsd: 1.0),
    'IDR': const CurrencyRate(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah', ratePerUsd: 16250.0),
    'EUR': const CurrencyRate(code: 'EUR', symbol: '€', name: 'Euro', ratePerUsd: 0.92),
    'GBP': const CurrencyRate(code: 'GBP', symbol: '£', name: 'British Pound', ratePerUsd: 0.79),
    'JPY': const CurrencyRate(code: 'JPY', symbol: '¥', name: 'Japanese Yen', ratePerUsd: 154.5),
    'SGD': const CurrencyRate(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', ratePerUsd: 1.35),
    'AUD': const CurrencyRate(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', ratePerUsd: 1.52),
  };

  static double convert(double amountUsd, String targetCurrencyCode) {
    final rate = currencies[targetCurrencyCode]?.ratePerUsd ?? 1.0;
    return amountUsd * rate;
  }

  static String formatCurrency(double amountUsd, String targetCurrencyCode) {
    final rate = currencies[targetCurrencyCode] ?? currencies['USD']!;
    final converted = amountUsd * rate.ratePerUsd;

    if (rate.code == 'IDR' || rate.code == 'JPY') {
      final formatter = NumberFormat('#,###', 'id_ID');
      return '${rate.symbol} ${formatter.format(converted.round())}';
    } else {
      final formatter = NumberFormat('#,##0.00', 'en_US');
      return '${rate.symbol}${formatter.format(converted)}';
    }
  }
}

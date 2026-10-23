import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runcompete/main.dart';
import 'package:runcompete/services/blockchain_service.dart';
import 'package:runcompete/services/ai_coach_service.dart';
import 'package:runcompete/services/auth_service.dart';
import 'package:runcompete/services/currency_service.dart';
import 'package:runcompete/services/timezone_service.dart';
import 'package:runcompete/services/theme_service.dart';
import 'package:runcompete/services/event_service.dart';
import 'package:runcompete/services/sensor_service.dart';
import 'package:runcompete/services/location_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final blockchainService = BlockchainService();
    final aiCoachService = AiCoachService();
    final authService = AuthService();
    final currencyService = CurrencyService();
    final timezoneService = TimezoneService();
    final themeService = ThemeService();
    final eventService = EventService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MotionSensorService()),
          ChangeNotifierProvider(create: (_) => LocationTrackingService()),
          ChangeNotifierProvider.value(value: currencyService),
          ChangeNotifierProvider.value(value: timezoneService),
          ChangeNotifierProvider.value(value: themeService),
          ChangeNotifierProvider.value(value: eventService),
        ],
        child: GlobalVirtualRaceApp(
          blockchainService: blockchainService,
          aiCoachService: aiCoachService,
          authService: authService,
        ),
      ),
    );
  });
}

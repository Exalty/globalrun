import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/sensor_service.dart';
import 'services/location_service.dart';
import 'services/blockchain_service.dart';
import 'services/ai_coach_service.dart';
import 'services/auth_service.dart';
import 'services/currency_service.dart';
import 'services/timezone_service.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'screens/main_navigation_wrapper.dart';
import 'theme/duo_theme.dart';
import 'services/theme_service.dart';
import 'services/event_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: '.env');

  final notificationService = NotificationService();
  await notificationService.init();

  final blockchainService = BlockchainService();
  // Inject Gemini API key from .env automatically
  final aiCoachService = AiCoachService(
    apiKey: dotenv.env['GEMINI_API_KEY'],
  );
  final authService = AuthService();

  // Inisialisasi Currency & Timezone services (fetch dari API eksternal)
  final currencyService = CurrencyService();
  await currencyService.init();

  final timezoneService = TimezoneService();
  await timezoneService.init();

  final themeService = ThemeService();
  await themeService.init();

  final eventService = EventService();

  runApp(
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
}

class GlobalVirtualRaceApp extends StatefulWidget {
  final BlockchainService blockchainService;
  final AiCoachService aiCoachService;
  final AuthService authService;

  const GlobalVirtualRaceApp({
    super.key,
    required this.blockchainService,
    required this.aiCoachService,
    required this.authService,
  });

  @override
  State<GlobalVirtualRaceApp> createState() => _GlobalVirtualRaceAppState();
}

class _GlobalVirtualRaceAppState extends State<GlobalVirtualRaceApp> {
  bool _isLoggedIn = false;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    final loggedIn = await widget.authService.isLoggedIn();
    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _isCheckingAuth = false;
      });
    }
  }

  void _handleLoginSuccess() {
    setState(() => _isLoggedIn = true);
  }

  Future<void> _handleLogout() async {
    await widget.authService.logout();
    if (mounted) {
      setState(() => _isLoggedIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return MaterialApp(
      title: 'Global Virtual Race',
      debugShowCheckedModeBanner: false,
      themeMode: themeService.themeMode,
      theme: DuoThemeData.lightTheme,
      darkTheme: DuoThemeData.darkTheme,
      home: _isCheckingAuth
          ? const Scaffold(
              backgroundColor: DuoColors.background,
              body: Center(
                child: CircularProgressIndicator(color: DuoColors.primaryBlue),
              ),
            )
          : _isLoggedIn
              ? MainNavigationWrapper(
                  blockchainService: widget.blockchainService,
                  aiCoachService: widget.aiCoachService,
                  onLogout: _handleLogout,
                )
              : LoginScreen(
                  onLoginSuccess: _handleLoginSuccess,
                ),
    );
  }
}

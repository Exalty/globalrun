import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/sensor_service.dart';
import 'services/location_service.dart';
import 'services/blockchain_service.dart';
import 'services/ai_coach_service.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final blockchainService = BlockchainService();
  final aiCoachService = AiCoachService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MotionSensorService()),
        ChangeNotifierProvider(create: (_) => LocationTrackingService()),
      ],
      child: GlobalVirtualRaceApp(
        blockchainService: blockchainService,
        aiCoachService: aiCoachService,
      ),
    ),
  );
}

class GlobalVirtualRaceApp extends StatelessWidget {
  final BlockchainService blockchainService;
  final AiCoachService aiCoachService;

  const GlobalVirtualRaceApp({
    super.key,
    required this.blockchainService,
    required this.aiCoachService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global Virtual Race',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.amberAccent,
          surface: Color(0xFF1E293B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(
        blockchainService: blockchainService,
        aiCoachService: aiCoachService,
      ),
    );
  }
}

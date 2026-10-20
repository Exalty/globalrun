import 'package:flutter_test/flutter_test.dart';
import 'package:runcompete/main.dart';
import 'package:runcompete/services/blockchain_service.dart';
import 'package:runcompete/services/ai_coach_service.dart';
import 'package:runcompete/services/auth_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final blockchainService = BlockchainService();
    final aiCoachService = AiCoachService();
    final authService = AuthService();

    await tester.pumpWidget(
      GlobalVirtualRaceApp(
        blockchainService: blockchainService,
        aiCoachService: aiCoachService,
        authService: authService,
      ),
    );
  });
}

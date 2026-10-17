import 'package:flutter_test/flutter_test.dart';
import 'package:runcompete/main.dart';
import 'package:runcompete/services/blockchain_service.dart';
import 'package:runcompete/services/ai_coach_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final blockchainService = BlockchainService();
    final aiCoachService = AiCoachService();

    await tester.pumpWidget(
      GlobalVirtualRaceApp(
        blockchainService: blockchainService,
        aiCoachService: aiCoachService,
      ),
    );

    expect(find.text('Global Virtual Race'), findsOneWidget);
  });
}

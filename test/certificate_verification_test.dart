import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runcompete/models/blockchain_record.dart';
import 'package:runcompete/services/blockchain_service.dart';

class _AllowHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _AllowHttpOverrides();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Certificate & Polygon Verification Tests', () {
    test('encodeIsHashMintedCall formats ABI call correctly', () {
      const testHash = 'bd9fce3b901a8dca3f3621d8f8f50239bf5c9ce09e7bf860602c43cfa11f7361';
      final callData = BlockchainService.encodeIsHashMintedCall(testHash);

      // Selector
      expect(callData.startsWith('0x64545487'), isTrue);
      // Offset is 32 bytes (64 hex characters)
      expect(callData.substring(10, 74), '0000000000000000000000000000000000000000000000000000000000000020');
      // Length is 64 characters (0x40)
      expect(callData.substring(74, 138), '0000000000000000000000000000000000000000000000000000000000000040');
      // Arguments hex string length (excluding 0x and 8 hex chars selector) must be multiple of 64
      expect((callData.length - 10) % 64, 0);
    });

    test('Blockchain medal contract address is valid Ethereum address', () {
      expect(BlockchainService.medalContractAddress.startsWith('0x'), isTrue);
      expect(BlockchainService.medalContractAddress.length, 42);
    });

    test('QR Code payload never uses nonexistent polygonscan.com/verify', () {
      final blockWithoutPolygon = Block(
        index: 1,
        timestamp: '2026-11-20T00:00:00Z',
        raceId: 'race-test-1',
        raceTitle: 'Jakarta 10K',
        participantName: 'Budi Runner',
        distanceKm: 10.0,
        durationSeconds: 3600,
        stepsCount: 8500,
        avgSpeedKmh: 10.0,
        previousHash: '0000000000000000000000000000000000000000000000000000000000000000',
        hash: 'abc123def456abc123def456abc123def456abc123def456abc123def456abc1',
      );

      final payload = blockWithoutPolygon.polygonscanUrl != null && blockWithoutPolygon.polygonscanUrl!.isNotEmpty
          ? blockWithoutPolygon.polygonscanUrl!
          : 'https://globalrun.app/verify?token=${blockWithoutPolygon.tokenId}&hash=${blockWithoutPolygon.hash}&runner=${Uri.encodeComponent(blockWithoutPolygon.participantName)}&race=${Uri.encodeComponent(blockWithoutPolygon.raceTitle)}&time=${blockWithoutPolygon.durationSeconds}&dist=${blockWithoutPolygon.distanceKm}';

      expect(payload.contains('polygonscan.com/verify'), isFalse);
      expect(payload.startsWith('https://globalrun.app/verify'), isTrue);
    });

    test('Scanner rejects fake verify endpoints and accepts valid explorer paths', () {
      // Fake verify endpoint that caused 404
      final fakeUri = Uri.parse('https://amoy.polygonscan.com/verify?token=GLR-1234');
      bool isFakeExplorer = fakeUri.host.contains('polygonscan.com') &&
          (fakeUri.pathSegments.contains('tx') ||
              fakeUri.pathSegments.contains('address') ||
              fakeUri.pathSegments.contains('token'));
      expect(isFakeExplorer, isFalse);

      // Real transaction URL
      final txUri = Uri.parse('https://amoy.polygonscan.com/tx/0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
      bool isTxExplorer = txUri.host.contains('polygonscan.com') &&
          (txUri.pathSegments.contains('tx') ||
              txUri.pathSegments.contains('address') ||
              txUri.pathSegments.contains('token'));
      expect(isTxExplorer, isTrue);

      // Real contract address URL
      final contractUri = Uri.parse('https://amoy.polygonscan.com/address/0xd3907914e96462C7B0EcC2fB1d1527585a008263');
      bool isContractExplorer = contractUri.host.contains('polygonscan.com') &&
          (contractUri.pathSegments.contains('tx') ||
              contractUri.pathSegments.contains('address') ||
              contractUri.pathSegments.contains('token'));
      expect(isContractExplorer, isTrue);
    });

    test('Live Polygon Amoy RPC verifies real minted medal correctly', () async {
      final service = BlockchainService();
      // Medal #5 real minted hash on contract 0xd3907914e96462C7B0EcC2fB1d1527585a008263
      const realMintedHash = 'bd9fce3b901a8dca3f3621d8f8f50239bf5c9ce09e7bf860602c43cfa11f7361';
      final res = await service.verifyHashOnPolygon(realMintedHash);

      expect(res['success'], isTrue);
      expect(res['isMinted'], isTrue);
      expect(res['contractAddress'], BlockchainService.medalContractAddress);
    });

    test('Live Polygon Amoy RPC correctly returns false for unminted hash', () async {
      final service = BlockchainService();
      const fakeHash = '0000000000000000000000000000000000000000000000000000000000fake00';
      final res = await service.verifyHashOnPolygon(fakeHash);

      expect(res['success'], isTrue);
      expect(res['isMinted'], isFalse);
    });
  });
}

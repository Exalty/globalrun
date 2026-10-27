const polygonService = require('../services/polygonService');

async function testMint() {
  console.log('Menguji minting medali perdana on-chain...');
  try {
    const result = await polygonService.mintMedalOnline({
      recipient: polygonService.adminAddress,
      participantName: 'Pelari Perdana GlobalRun',
      raceId: 'ev-test-1',
      raceTitle: 'Borobudur Virtual 10K 2026',
      distanceKm: 10.0,
      durationSeconds: 3120,
      avgSpeedKmh: 11.5,
      tier: 'GOLD',
      localBlockHash: '0x' + Array(64).fill('a').join(''),
    });

    console.log('==================================================');
    console.log('✅ TEST MINTING ON-CHAIN BERHASIL!');
    console.log(`TxHash        : ${result.txHash}`);
    console.log(`Polygonscan URL: ${result.polygonscanUrl}`);
    console.log('==================================================');
  } catch (e) {
    console.error('Test mint gagal:', e);
  }
}

testMint();

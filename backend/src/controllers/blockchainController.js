const polygonService = require('../services/polygonService');

exports.getWalletInfo = async (req, res) => {
  try {
    const info = await polygonService.getWalletInfo();
    return res.status(200).json({ success: true, data: info });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.mintMedal = async (req, res) => {
  try {
    const {
      recipient,
      participantName,
      raceId,
      raceTitle,
      distanceKm,
      durationSeconds,
      avgSpeedKmh,
      tier,
      localBlockHash,
    } = req.body;

    if (!localBlockHash) {
      return res.status(400).json({
        success: false,
        message: 'Parameter localBlockHash (SHA-256) wajib disertakan',
      });
    }

    const result = await polygonService.mintMedalOnline({
      recipient,
      participantName,
      raceId,
      raceTitle,
      distanceKm,
      durationSeconds,
      avgSpeedKmh,
      tier,
      localBlockHash,
    });

    return res.status(200).json(result);
  } catch (error) {
    console.error('[Blockchain Mint Error]:', error);
    return res.status(500).json({
      success: false,
      message: error.message || 'Gagal memproses transaksi minting on-chain',
    });
  }
};

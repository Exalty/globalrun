const express = require('express');
const router = express.Router();
const blockchainController = require('../controllers/blockchainController');

// GET /api/blockchain/wallet-info
router.get('/wallet-info', blockchainController.getWalletInfo);

// POST /api/blockchain/mint
router.post('/mint', blockchainController.mintMedal);

module.exports = router;

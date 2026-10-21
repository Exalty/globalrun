const express = require('express');
const router = express.Router();
const eventController = require('../controllers/eventController');
const authMiddleware = require('../middleware/authMiddleware');

// Get active race events
router.get('/', eventController.getEvents);

// Submit race result (Protected)
router.post('/results', authMiddleware, eventController.submitResult);

module.exports = router;

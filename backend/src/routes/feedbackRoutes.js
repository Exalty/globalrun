const express = require('express');
const router = express.Router();
const feedbackController = require('../controllers/feedbackController');
const authMiddleware = require('../middleware/authMiddleware');

// Public route to read feedbacks
router.get('/', feedbackController.getFeedbacks);

// Optional auth: authenticated users get linked by userId, or guest
router.post('/', (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authMiddleware(req, res, next);
  }
  next();
}, feedbackController.submitFeedback);

module.exports = router;

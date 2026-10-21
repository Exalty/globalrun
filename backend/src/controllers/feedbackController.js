const db = require('../config/db');

// Submit Feedback (Saran & Kesan)
exports.submitFeedback = async (req, res) => {
  const { rating, kesan, saran } = req.body;

  if (!rating || !kesan || !saran) {
    return res.status(400).json({
      success: false,
      message: 'Rating bintang, kesan, dan saran wajib diisi.',
    });
  }

  try {
    const userId = req.user ? req.user.id : null;
    const result = await db.query(
      `INSERT INTO feedback (user_id, rating, kesan, saran)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [userId, parseInt(rating), kesan.trim(), saran.trim()]
    );

    return res.status(201).json({
      success: true,
      message: 'Saran dan kesan Anda berhasil disimpan di server!',
      feedback: result.rows[0],
    });
  } catch (err) {
    console.error('submitFeedback error:', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal mengirim saran dan kesan.',
      error: err.message,
    });
  }
};

// Get All Feedback
exports.getFeedbacks = async (req, res) => {
  try {
    const result = await db.query(`
      SELECT f.id, f.rating, f.kesan, f.saran, f.created_at, COALESCE(u.full_name, 'Peserta Anonim') as author
      FROM feedback f
      LEFT JOIN users u ON f.user_id = u.id
      ORDER BY f.created_at DESC
      LIMIT 50
    `);

    return res.status(200).json({
      success: true,
      feedbacks: result.rows,
    });
  } catch (err) {
    console.error('getFeedbacks error:', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal memuat daftar saran & kesan.',
      error: err.message,
    });
  }
};

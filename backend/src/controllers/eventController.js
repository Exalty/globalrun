const db = require('../config/db');

// Get all active race events
exports.getEvents = async (req, res) => {
  try {
    const result = await db.query(
      'SELECT id, title, description, distance_km, type, start_time_utc, fee_usd FROM race_events ORDER BY id ASC'
    );
    return res.status(200).json({
      success: true,
      events: result.rows,
    });
  } catch (err) {
    console.error('getEvents error:', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal mengambil data event lomba.',
      error: err.message,
    });
  }
};

// Submit verified race result (linked to user & anti-cheat / blockchain)
exports.submitResult = async (req, res) => {
  const { race_id, distance_km, duration_seconds, steps_count, avg_speed_kmh, block_hash, is_anti_cheat_verified } = req.body;

  if (!distance_km || !duration_seconds) {
    return res.status(400).json({
      success: false,
      message: 'Jarak dan durasi lomba wajib disertakan.',
    });
  }

  try {
    const result = await db.query(
      `INSERT INTO race_results (user_id, race_id, distance_km, duration_seconds, steps_count, avg_speed_kmh, block_hash, is_anti_cheat_verified)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        req.user.id,
        race_id || null,
        distance_km,
        duration_seconds,
        steps_count || 0,
        avg_speed_kmh || 0.0,
        block_hash || null,
        is_anti_cheat_verified !== undefined ? is_anti_cheat_verified : true,
      ]
    );

    return res.status(201).json({
      success: true,
      message: 'Hasil lomba berhasil direkam ke PostgreSQL!',
      result: result.rows[0],
    });
  } catch (err) {
    console.error('submitResult error:', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal menyimpan hasil lomba.',
      error: err.message,
    });
  }
};

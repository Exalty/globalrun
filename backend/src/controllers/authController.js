const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../config/db');

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_globalrun_race_2026_jwt_token';
const JWT_EXPIRES_IN = '7d';

// Register User (Custom Bcrypt Hashing)
exports.register = async (req, res) => {
  const { full_name, email, password } = req.body;

  if (!full_name || !email || !password) {
    return res.status(400).json({
      success: false,
      message: 'Nama lengkap, email, dan password wajib diisi.',
    });
  }

  try {
    const existing = await db.query('SELECT id FROM users WHERE email = $1', [email.toLowerCase().trim()]);
    if (existing.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'Email sudah terdaftar. Silakan login atau gunakan email lain.',
      });
    }

    // Hash password with Bcrypt
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const result = await db.query(
      `INSERT INTO users (full_name, email, password_hash)
       VALUES ($1, $2, $3)
       RETURNING id, full_name, email, created_at`,
      [full_name.trim(), email.toLowerCase().trim(), passwordHash]
    );

    const newUser = result.rows[0];

    // Generate JWT
    const token = jwt.sign(
      { id: newUser.id, email: newUser.email },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    return res.status(201).json({
      success: true,
      message: 'Registrasi berhasil! Selamat datang di Global Virtual Race.',
      token,
      user: {
        id: newUser.id,
        full_name: newUser.full_name,
        email: newUser.email,
        created_at: newUser.created_at,
      },
    });
  } catch (err) {
    console.error('Register error:', err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan pada server saat registrasi.',
      error: err.message,
    });
  }
};

// Login User (Bcrypt Verification & JWT Generation)
exports.login = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      success: false,
      message: 'Email dan password wajib diisi.',
    });
  }

  try {
    const result = await db.query(
      'SELECT id, full_name, email, password_hash, created_at FROM users WHERE email = $1',
      [email.toLowerCase().trim()]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Kombinasi email atau password salah.',
      });
    }

    const user = result.rows[0];

    // Compare with bcrypt
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Kombinasi email atau password salah.',
      });
    }

    // Generate JWT
    const token = jwt.sign(
      { id: user.id, email: user.email },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    return res.status(200).json({
      success: true,
      message: 'Login berhasil!',
      token,
      user: {
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        created_at: user.created_at,
      },
    });
  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan pada server saat login.',
      error: err.message,
    });
  }
};

// Get User Profile & Career Stats (Protected)
exports.getProfile = async (req, res) => {
  try {
    const userRes = await db.query(
      'SELECT id, full_name, email, created_at FROM users WHERE id = $1',
      [req.user.id]
    );

    if (userRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Pengguna tidak ditemukan.',
      });
    }

    const user = userRes.rows[0];

    // Fetch career race stats
    const statsRes = await db.query(
      `SELECT 
        COALESCE(SUM(distance_km), 0) as total_distance_km,
        COUNT(id) as races_completed,
        COUNT(block_hash) as nft_medals
       FROM race_results
       WHERE user_id = $1`,
      [req.user.id]
    );

    const stats = statsRes.rows[0];

    return res.status(200).json({
      success: true,
      user: {
        ...user,
        stats: {
          total_distance_km: parseFloat(stats.total_distance_km).toFixed(1),
          races_completed: parseInt(stats.races_completed),
          nft_medals: parseInt(stats.nft_medals),
        },
      },
    });
  } catch (err) {
    console.error('GetProfile error:', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal mengambil data profil.',
      error: err.message,
    });
  }
};

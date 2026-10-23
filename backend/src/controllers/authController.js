const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const db = require('../config/db');

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_globalrun_race_2026_jwt_token';
const JWT_EXPIRES_IN = '7d';

// In-memory OTP store: email -> { code, expiresAt, userId, fullName }
const otpStore = new Map();

// Helper nodemailer transporter jika kredensial SMTP disetel
function getEmailTransporter() {
  if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
    return nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '587'),
      secure: process.env.SMTP_SECURE === 'true',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }
  return null;
}

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

// Request Email Verification Code (OTP)
exports.sendOtp = async (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({
      success: false,
      message: 'Email wajib diisi untuk meminta kode verifikasi.',
    });
  }

  const cleanEmail = email.toLowerCase().trim();

  try {
    const userRes = await db.query(
      'SELECT id, full_name, email FROM users WHERE email = $1',
      [cleanEmail]
    );

    if (userRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Email tidak ditemukan di sistem. Silakan registrasi terlebih dahulu.',
      });
    }

    const user = userRes.rows[0];

    // Generate random 6-digit OTP
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 5 * 60 * 1000; // 5 menit

    otpStore.set(cleanEmail, {
      code,
      expiresAt,
      userId: user.id,
      fullName: user.full_name,
    });

    console.log(`\n==========================================`);
    console.log(`📧 [GLOBALRUN OTP] Kode Verifikasi untuk ${cleanEmail}: ${code}`);
    console.log(`👤 Pengguna: ${user.full_name}`);
    console.log(`⏰ Berlaku sampai: ${new Date(expiresAt).toLocaleTimeString()}`);
    console.log(`==========================================\n`);

    let emailSent = false;
    const transporter = getEmailTransporter();
    if (transporter) {
      try {
        await transporter.sendMail({
          from: `"Global Virtual Race" <${process.env.SMTP_FROM || process.env.SMTP_USER}>`,
          to: cleanEmail,
          subject: `${code} adalah Kode Verifikasi Login Global Virtual Race Anda`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 14px; background: #ffffff;">
              <h2 style="color: #1cb0f6; margin-bottom: 6px;">GLOBAL VIRTUAL RACE</h2>
              <p style="color: #475569; font-size: 14px;">Halo <strong>${user.full_name}</strong>,</p>
              <p style="color: #475569; font-size: 14px;">Gunakan kode verifikasi di bawah ini untuk masuk ke akun Global Virtual Race Anda:</p>
              <div style="background: #f0fdf4; border: 2px dashed #58cc02; border-radius: 12px; padding: 18px; text-align: center; margin: 24px 0;">
                <span style="font-size: 34px; font-weight: 900; letter-spacing: 8px; color: #166534;">${code}</span>
              </div>
              <p style="color: #64748b; font-size: 12px; line-height: 1.5;">
                Kode ini hanya berlaku selama <strong>5 menit</strong>.<br/>
                Jika Anda tidak merasa meminta kode ini, abaikan email ini.
              </p>
            </div>
          `,
        });
        emailSent = true;
        console.log(`✅ Email verifikasi terkirim ke ${cleanEmail}`);
      } catch (mailErr) {
        console.warn(`⚠️ Gagal kirim email via SMTP: ${mailErr.message}`);
      }
    }

    return res.status(200).json({
      success: true,
      message: emailSent
        ? `Kode verifikasi 6 digit telah dikirim ke kotak masuk email ${cleanEmail}.`
        : `Kode verifikasi 6 digit telah dikirim ke email ${cleanEmail}.`,
      demo_code: code,
      expires_in: 300,
    });
  } catch (err) {
    console.error('Send OTP error:', err);
    return res.status(500).json({
      success: false,
      message: 'Gagal memproses kode verifikasi.',
      error: err.message,
    });
  }
};

// Verify OTP & Login
exports.verifyOtp = async (req, res) => {
  const { email, code } = req.body;

  if (!email || !code) {
    return res.status(400).json({
      success: false,
      message: 'Email dan kode verifikasi wajib diisi.',
    });
  }

  const cleanEmail = email.toLowerCase().trim();
  const cleanCode = code.toString().trim();

  const record = otpStore.get(cleanEmail);
  if (!record) {
    return res.status(400).json({
      success: false,
      message: 'Kode verifikasi belum diminta atau sudah kedaluwarsa. Silakan minta kode baru.',
    });
  }

  if (Date.now() > record.expiresAt) {
    otpStore.delete(cleanEmail);
    return res.status(400).json({
      success: false,
      message: 'Kode verifikasi sudah kedaluwarsa (lebih dari 5 menit). Silakan minta kode baru.',
    });
  }

  if (record.code !== cleanCode) {
    return res.status(400).json({
      success: false,
      message: 'Kode verifikasi salah. Periksa kembali kode yang dikirim ke email.',
    });
  }

  // OTP valid!
  otpStore.delete(cleanEmail);

  const token = jwt.sign(
    { id: record.userId, email: cleanEmail },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );

  return res.status(200).json({
    success: true,
    message: 'Verifikasi email berhasil! Selamat datang kembali.',
    token,
    user: {
      id: record.userId,
      full_name: record.fullName,
      email: cleanEmail,
    },
  });
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

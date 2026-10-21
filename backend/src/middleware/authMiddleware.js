const jwt = require('jsonwebtoken');

const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Akses ditolak. Token autentikasi JWT tidak ditemukan.',
    });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET || 'super_secret_jwt_key_globalrun_race_2026_jwt_token'
    );
    req.user = decoded; // { id, email, ... }
    next();
  } catch (err) {
    return res.status(401).json({
      success: false,
      message: 'Sesi kedaluwarsa atau token JWT tidak valid. Silakan login kembali.',
    });
  }
};

module.exports = authMiddleware;

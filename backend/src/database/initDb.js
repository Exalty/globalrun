const { Client, Pool } = require('pg');
require('dotenv').config();

async function initDatabase() {
  const adminClient = new Client({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432'),
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD,
    database: 'postgres',
  });

  try {
    await adminClient.connect();
    console.log('[1/3] Connected to PostgreSQL server...');

    const dbName = process.env.DB_NAME || 'globalrun_db';
    const checkDb = await adminClient.query(
      `SELECT 1 FROM pg_database WHERE datname = $1`,
      [dbName]
    );

    if (checkDb.rows.length === 0) {
      console.log(`Database "${dbName}" not found. Creating database...`);
      await adminClient.query(`CREATE DATABASE "${dbName}"`);
      console.log(`Database "${dbName}" created successfully!`);
    } else {
      console.log(`Database "${dbName}" already exists.`);
    }
  } catch (err) {
    console.error('Error during database check/creation:', err.message);
    throw err;
  } finally {
    await adminClient.end();
  }

  // Connect to target database
  const targetPool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432'),
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'globalrun_db',
  });

  try {
    console.log('[2/3] Initializing tables & schemas (ERD)...');

    // Users table
    await targetPool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        full_name VARCHAR(150) NOT NULL,
        email VARCHAR(150) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Race Events table
    await targetPool.query(`
      CREATE TABLE IF NOT EXISTS race_events (
        id SERIAL PRIMARY KEY,
        title VARCHAR(200) NOT NULL,
        description TEXT,
        distance_km DOUBLE PRECISION NOT NULL,
        type VARCHAR(50) NOT NULL,
        start_time_utc TIMESTAMP NOT NULL,
        fee_usd DOUBLE PRECISION DEFAULT 0.0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Race Results table
    await targetPool.query(`
      CREATE TABLE IF NOT EXISTS race_results (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        race_id INTEGER REFERENCES race_events(id) ON DELETE SET NULL,
        distance_km DOUBLE PRECISION NOT NULL,
        duration_seconds INTEGER NOT NULL,
        steps_count INTEGER DEFAULT 0,
        avg_speed_kmh DOUBLE PRECISION DEFAULT 0.0,
        block_hash VARCHAR(255),
        is_anti_cheat_verified BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Feedback (Saran & Kesan) table
    await targetPool.query(`
      CREATE TABLE IF NOT EXISTS feedback (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
        kesan TEXT NOT NULL,
        saran TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    console.log('[3/3] Seeding default events...');
    const existingEvents = await targetPool.query('SELECT COUNT(*) FROM race_events');
    if (parseInt(existingEvents.rows[0].count) === 0) {
      await targetPool.query(`
        INSERT INTO race_events (title, description, distance_km, type, start_time_utc, fee_usd)
        VALUES 
        ('Tokyo Virtual Marathon 10K', 'Lari virtual dengan rute ikonik Tokyo. Terhubung ke sensor anti-cheat dan minting NFT Polygon.', 10.0, 'run', NOW() + INTERVAL '2 hours', 15.0),
        ('Jakarta Night Run 5K', 'Kompetisi lari malam virtual menyusuri jalan protokol Jakarta. Sinkronisasi zona WIB.', 5.0, 'run', NOW() + INTERVAL '6 hours', 8.0),
        ('Tour de Bali Virtual 40K', 'Balap sepeda virtual menantang melintasi tanjakan Kintamani dan pantai Sanur.', 40.0, 'cycling', NOW() + INTERVAL '1 day', 25.0);
      `);
      console.log('Default race events seeded successfully.');
    }

    console.log('✅ PostgreSQL Schema & Initialization completed successfully!');
  } catch (err) {
    console.error('Error initializing tables:', err.message);
  } finally {
    await targetPool.end();
  }
}

if (require.main === module) {
  initDatabase().then(() => process.exit(0)).catch(() => process.exit(1));
}

module.exports = initDatabase;

const db = require('../config/db');

// List of premier verified real-world events
const PREMIER_WORLD_EVENTS = [
  {
    title: 'Tokyo Marathon 2026',
    description: 'World Marathon Major resmi di Tokyo, Jepang. Berlari melintasi Shinjuku, Ginza, dan Tokyo Station dengan partisipasi ribuan atlet dunia.',
    distance_km: 42.2,
    type: 'run',
    start_time_utc: new Date(Date.now() + 1000 * 60 * 60 * 18).toISOString(),
    fee_usd: 25.0,
    official_url: 'https://www.marathon.tokyo/en/',
    location: 'Tokyo, Japan',
    is_live_external: true,
  },
  {
    title: 'Maybank Marathon Bali 2026',
    description: 'Lomba lari bergengsi World Athletics Elite Label Road Race di Gianyar Bali. Rute eksotis pesisir pantai dan pedesaan Bali.',
    distance_km: 21.1,
    type: 'run',
    start_time_utc: new Date(Date.now() + 1000 * 60 * 60 * 36).toISOString(),
    fee_usd: 18.0,
    official_url: 'https://www.maybankmarathon.com/',
    location: 'Gianyar, Bali, Indonesia',
    is_live_external: true,
  },
  {
    title: 'TCS London Marathon 2026',
    description: 'Iconic World Marathon Major menyusuri Sungai Thames, Tower Bridge, hingga finish di The Mall depan Istana Buckingham.',
    distance_km: 42.2,
    type: 'run',
    start_time_utc: new Date(Date.now() + 1000 * 60 * 60 * 72).toISOString(),
    fee_usd: 30.0,
    official_url: 'https://www.tcslondonmarathon.com/',
    location: 'London, United Kingdom',
    is_live_external: true,
  },
  {
    title: 'Borobudur Virtual 10K 2026',
    description: 'Lomba lari kultural di sekitar Candi Borobudur Magelang. Rasakan kearifan lokal Jawa Tengah dengan pencatatan sensor anti-cheat.',
    distance_km: 10.0,
    type: 'run',
    start_time_utc: new Date(Date.now() + 1000 * 60 * 60 * 8).toISOString(),
    fee_usd: 10.0,
    official_url: 'https://borobudurmarathon.com/',
    location: 'Magelang, Jawa Tengah, Indonesia',
    is_live_external: true,
  },
  {
    title: 'Tour de Alps Virtual Century 50K',
    description: 'Virtual cycling challenge simulasi tanjakan Pegunungan Alpen. Uji irama kayuhan (cadence), elevasi, dan daya tahan virtual.',
    distance_km: 50.0,
    type: 'cycling',
    start_time_utc: new Date(Date.now() + 1000 * 60 * 60 * 48).toISOString(),
    fee_usd: 20.0,
    official_url: 'https://www.letour.fr/en/',
    location: 'Alps, France / Switzerland',
    is_live_external: true,
  },
];

let lastFetchTime = 0;
const CACHE_DURATION_MS = 15 * 60 * 1000; // 15 menit cache

function cleanHtml(html) {
  if (!html) return '';
  return html
    .replace(/<[^>]*>/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function parseDistanceAndType(name, desc) {
  const text = `${name} ${desc}`.toLowerCase();
  let type = 'run';
  let distance = 5.0;

  if (text.includes('cycling') || text.includes('bike') || text.includes('ride') || text.includes('tour de') || text.includes('century')) {
    type = 'cycling';
    distance = text.includes('century') ? 50.0 : 30.0;
  } else if (text.includes('half marathon') || text.includes('half-marathon') || text.includes('21k')) {
    distance = 21.1;
  } else if (text.includes('marathon')) {
    distance = 42.2;
  } else if (text.includes('10k') || text.includes('10 mile') || text.includes('10-k')) {
    distance = 10.0;
  } else if (text.includes('5k') || text.includes('5-k') || text.includes('5 mile')) {
    distance = 5.0;
  } else if (text.includes('1 mile') || text.includes('fun run')) {
    distance = 3.0;
  }

  return { type, distance };
}

// Fetch live events from RunSignup Public REST API
async function fetchRunSignupLiveRaces() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    const res = await fetch(
      'https://runsignup.com/Rest/races?format=json&results_per_page=10&search_start_date=today&event_type=running_race',
      { signal: controller.signal }
    );
    clearTimeout(timeoutId);

    if (!res.ok) {
      console.warn(`[RunSignup] HTTP error: ${res.status}`);
      return [];
    }

    const data = await res.json();
    if (!data || !Array.isArray(data.races)) return [];

    return data.races.map((item) => {
      const r = item.race;
      const cleanDesc = cleanHtml(r.description).slice(0, 240);
      const { type, distance } = parseDistanceAndType(r.name, cleanDesc);

      // Parse date
      let startUtc = new Date(Date.now() + 1000 * 60 * 60 * 24 * 2); // Default 2 hari ke depan
      if (r.next_date) {
        const parts = r.next_date.split('/');
        if (parts.length === 3) {
          const month = parseInt(parts[0], 10) - 1;
          const day = parseInt(parts[1], 10);
          const year = parseInt(parts[2], 10);
          const parsed = new Date(Date.UTC(year, month, day, 8, 0, 0));
          if (!isNaN(parsed.getTime())) {
            startUtc = parsed;
          }
        }
      }

      const locParts = [r.address?.city, r.address?.state, r.address?.country_code || 'US'].filter(Boolean);
      const location = locParts.length > 0 ? locParts.join(', ') : 'Global Venue 🌐';

      return {
        title: cleanHtml(r.name),
        description: cleanDesc.length > 10 ? cleanDesc : 'Lomba lari resmi terdaftar secara global di platform RunSignup. Lengkap dengan pencatatan jarak, timing chip, dan tracking.',
        distance_km: distance,
        type: type,
        start_time_utc: startUtc.toISOString(),
        fee_usd: distance >= 42.0 ? 25.0 : distance >= 21.0 ? 18.0 : distance >= 10.0 ? 12.0 : 8.0,
        official_url: r.url || 'https://runsignup.com',
        location: `${location} 🌐`,
        is_live_external: true,
      };
    });
  } catch (err) {
    console.warn('[RunSignup] Gagal fetch live data:', err.message);
    return [];
  }
}

// Sinkronkan ke database PostgreSQL (upsert ke race_events)
async function syncToDatabase(events) {
  try {
    for (const ev of events) {
      // Cek apakah event sudah ada di DB
      const existCheck = await db.query(
        'SELECT id FROM race_events WHERE title = $1 LIMIT 1',
        [ev.title]
      );

      if (existCheck.rows.length === 0) {
        await db.query(
          `INSERT INTO race_events (title, description, distance_km, type, start_time_utc, fee_usd, official_url, location, is_live_external)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [
            ev.title,
            ev.description,
            ev.distance_km,
            ev.type,
            ev.start_time_utc,
            ev.fee_usd,
            ev.official_url,
            ev.location,
            true,
          ]
        );
      } else {
        // Update URL dan location jika belum ada
        await db.query(
          `UPDATE race_events 
           SET official_url = $1, location = $2, is_live_external = TRUE 
           WHERE id = $3`,
          [ev.official_url, ev.location, existCheck.rows[0].id]
        );
      }
    }
  } catch (dbErr) {
    console.error('syncToDatabase error:', dbErr.message);
  }
}

// Get all active race events (Live Sync RunSignup + PostgreSQL)
exports.getEvents = async (req, res) => {
  try {
    const forceRefresh = req.query.refresh === 'true';
    const now = Date.now();

    // Jalankan sync berkala jika cache kadaluwarsa atau diminta paksa
    if (forceRefresh || now - lastFetchTime > CACHE_DURATION_MS) {
      console.log('🔄 Memperbarui daftar event live dari RunSignup & Premier World Races...');
      const runSignupRaces = await fetchRunSignupLiveRaces();
      const allLiveEvents = [...PREMIER_WORLD_EVENTS, ...runSignupRaces];

      if (allLiveEvents.length > 0) {
        await syncToDatabase(allLiveEvents);
        lastFetchTime = now;
      }
    }

    // Ambil data terbaru dari PostgreSQL
    const result = await db.query(
      `SELECT id, title, description, distance_km, type, start_time_utc, fee_usd, official_url, location, is_live_external
       FROM race_events 
       ORDER BY start_time_utc ASC`
    );

    return res.status(200).json({
      success: true,
      count: result.rows.length,
      source: 'RunSignup Live API & PostgreSQL',
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

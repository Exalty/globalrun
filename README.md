# GlobalRun — Global Virtual Race Platform

Platform kompetisi atletik virtual global berbasis mobile yang menghubungkan pelari dari seluruh dunia dalam ajang perlombaan lari dan bersepeda virtual terverifikasi.

---

## 🌟 Fitur Utama

1. **Katalog Lomba Global & Multi-Zona/Kurs:**
   - Perlombaan 5K, 10K, Half Marathon (21.1K), dan Full Marathon (42.2K).
   - Sinkronisasi waktu start otomatis lintas zona waktu (WIB, UTC, JST, EST, CET) via TimeAPI.
   - Konversi biaya registrasi lomba dinamis (USD, IDR, EUR, JPY, GBP) via ExchangeRate API.
2. **Pelacakan Lari Real-Time & Sensor Anti-Cheat:**
   - Pelacakan koordinat GPS rute, kecepatan rata-rata, elevasi, dan durasi lari.
   - Algoritma **Anti-Cheat** berbasis akselerometer fisik untuk mendeteksi irama langkah kaki (*cadence*) guna mencegah kecurangan berkendara.
3. **Papan Klasemen & Komparasi Atlet:**
   - Klasemen peringkat lomba dengan podium 3D Olimpiade untuk Juara 1 (Gold 👑), Juara 2 (Silver), dan Juara 3 (Bronze).
   - **Head-to-Head Athlete Comparison:** Membandingkan waktu tempuh, pace, cadence, dan status verifikasi anti-cheat antar-atlet.
4. **Sertifikat & Medali NFT Web3 (Polygon Amoy Blockchain):**
   - Pencetakan sertifikat finisher lari sebagai NFT ERC-721 on-chain anti-pemalsuan.
   - Hash transaksi permanen dapat diverifikasi secara publik di penjelajah blok Polygonscan.
5. **Coach Rani — AI Sport Assistant (Google Gemini):**
   - Asisten konsultasi strategi lomba, nutrisi, hidrasi, dan pencegahan cedera berbasis Google Gemini AI.
   - Menganalisis akumulasi riwayat lari atlet untuk memberikan rekomendasi event yang paling sesuai.
6. **Keamanan & Autentikasi:**
   - Login & Registrasi dengan enkripsi password Bcrypt dan session JWT Bearer Token.
   - Fitur login instan menggunakan sensor biometrik sidik jari (*fingerprint*).
7. **Gamifikasi & Tema:**
   - Mini-game pelari 2D yang dikendalikan dengan memiringkan HP (sensor giroskop fisik).
   - Antarmuka playful 3D (*DuoTheme*) dengan dukungan penuh Dark Mode dan Light Mode.

---

## 🏗️ Arsitektur Teknologi

- **Mobile Framework:** Flutter (Dart 3.x)
- **State Management:** Provider
- **Local Storage:** SharedPreferences (Offline Cache)
- **Backend REST API:** Node.js, Express.js (Deployed di Vercel)
- **Database:** PostgreSQL (Supabase Cloud + Node-Postgres Connection Pooling)
- **Blockchain:** Polygon Amoy Testnet (Chain ID 80002, ethers.js, Smart Contract ERC-721)
- **AI Engine:** Google Gemini (Generative Language API v1beta)

---

## 🚀 Cara Menjalankan Aplikasi

### Persyaratan:
- Flutter SDK (>= 3.13.0)
- Android SDK / Perangkat Android fisik

### Langkah Instalasi:
```bash
# 1. Clone repositori
git clone https://github.com/Exalty/globalrun.git
cd globalrun

# 2. Pasang dependensi
flutter pub get

# 3. Jalankan aplikasi pada perangkat
flutter run
```

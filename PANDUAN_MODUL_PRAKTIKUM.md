# PANDUAN LENGKAP & DETAIL IMPLEMENTASI PRAKTIKUM FLUTTER
**Aplikasi: Global Virtual Race (GlobalRun)**
**Repositori: `Exalty/globalrun`**

Dokumen ini adalah panduan komprehensif untuk persiapan presentasi praktikum, mencakup seluruh materi **Modul II sampai Modul VII** serta seluruh detail teknis tanya-jawab (Arsitektur API, REST API, Session `is_logged_in`, SharedPreferences, Algoritma LBS GPS, Sensor Akselerometer Pedometer, dan Push Notification).

---

## 📌 DAFTAR ISI
1. [Modul II – Widget & Layout Hierarki](#1-modul-ii--widget--layout-hierarki)
2. [Modul III – State Management & Pemrosesan Data](#2-modul-iii--state-management--pemrosesan-data)
3. [Modul IV – Navigation & Multi-Screen Routing](#3-modul-iv--navigation--multi-screen-routing)
4. [Modul V – HTTP Request & REST API Integration](#4-modul-v--http-request--rest-api-integration)
5. [Modul VI – Local Storage & Session Management](#5-modul-vi--local-storage--session-management)
6. [Modul VII – Location Based Service (LBS), Sensor Akselerometer, & Notifikasi](#6-modul-vii--location-based-service-lbs-sensor-akselerometer--notifikasi)
7. [Daftar Lengkap Seluruh API di Aplikasi (Internal & Cloud)](#7-daftar-lengkap-seluruh-api-di-aplikasi-internal--cloud)
8. [Panduan Alur Live Demo Aplikasi saat Presentasi](#8-panduan-alur-live-demo-aplikasi-saat-presentasi)
9. [Tanya Jawab Kritis Penguji / Dosen (FAQ)](#9-tanya-jawab-kritis-penguji--dosen-faq)

---

## 1. Modul II – Widget & Layout Hierarki

### A. Konsep Teori
Flutter adalah *framework UI berbasis pohon widget (Widget Tree)*:
- **`StatelessWidget`**: Widget statis (imutabel) tanpa state internal yang berubah setelah dirender. Hanya menerima input parameter/props dari parent.
- **`StatefulWidget`**: Widget dinamis yang memiliki objek `State` terpisah yang dapat memicu re-render tampilan saat data internalnya dimodifikasi sepanjang siklus hidup widget.
- **Layouting Primitives**:
  - `Column` & `Row`: Layout linear satu dimensi (vertikal & horizontal).
  - `Stack`: Layout bertumpuk secara sumbu Z (misal menaruh HUD timer di atas peta live GPS).
  - `ListView.builder`: Rendering daftar elemen secara *lazy loading* / on-demand untuk menghemat alokasi memori RAM.
  - `Card`, `Container`, `Padding`, `SizedBox`: Dekorasi, elevasi bayangan, border radius, dan spasi antar komponen.

### B. Bukti & Lokasi File di Project
1. **StatelessWidget**:
   - File: `lib/widgets/athlete_comparison_dialog.dart` (Baris 9)
   - *Alasan*: Komponen dialog perbandingan atlet ini murni menerima data props lalu menampilkan tabel komparasi tanpa ada state yang berubah sendiri.
2. **StatefulWidget**:
   - File: `lib/screens/active_race_screen.dart` (Baris 13)
   - *Alasan*: Layar pelacakan lari yang secara terus-menerus memperbarui stopwatch waktu, akumulasi jarak GPS, live pace, dan grafik elevasi.
3. **Penyusunan Layout Kompleks (Column, Row, Card, Stack)**:
   - File: `lib/screens/home_screen.dart` (Baris 240-350)
   - *Alasan*: Mengombinasikan `Column` untuk menyusun banner dan daftar lomba secara vertikal, `Row` untuk status info jarak & tanggal, serta `Card` berelevasi modern.
4. **ListView.builder (Optimasi Memori)**:
   - File: `lib/screens/home_screen.dart` (Baris 398) & `lib/screens/run_history_screen.dart`
   - *Alasan*: Memastikan kartu-kartu event hanya digambar saat masuk ke area pandang (viewport) layar HP pengguna.

### C. Potongan Kode Penting
```dart
// lib/screens/home_screen.dart
ListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: _events.length,
  itemBuilder: (context, index) {
    final event = _events[index];
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: Theme.of(context).textTheme.titleMedium),
                  Text('${event.targetDistanceKm} KM • ${event.category}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
)
```

### D. Naskah Presentasi:
> *"Pada Modul II mengenai Widget dan Layout, aplikasi GlobalRun memisahkan arsitektur antarmuka menjadi StatelessWidget untuk dialog data statis seperti AthleteComparisonDialog dan StatefulWidget untuk layar dinamis seperti ActiveRaceScreen yang metrik larinya berubah setiap detik. Untuk tata letak UI, kami menyusun tampilan menggunakan kombinasi Column, Row, dan Stack, serta mengoptimalkan performa rendering daftar lomba menggunakan ListView.builder agar hanya me-render elemen yang tampak di layar sehingga menghemat penggunaan memori HP."*

---

## 2. Modul III – State Management & Pemrosesan Data

### A. Konsep Teori
- **Ephemeral / Local State (`setState`)**: State yang hanya relevan untuk satu widget lokal. Pemanggilan `setState((){})` memberitahu Flutter engine bahwa data internal telah berubah dan memicu metode `build()` dijalankan ulang.
- **Model Data OOP**: Penerapan konsep enkapsulasi objek (POJO / Plain Old Dart Object) dengan atribut bertipe data kuat (*type-safe*), konstruktor, serta fungsi serialisasi (`fromJson` dan `toJson`).
- **Global App State (Provider)**: Pengelolaan state global lintas layar (misal tema aplikasi dan otentikasi global).

### B. Bukti & Lokasi File di Project
1. **Reaktif State Update dengan `setState()`**:
   - File: `lib/screens/active_race_screen.dart` (Baris 180-210)
   - *Implementasi*: Setiap detak waktu `Timer.periodic(1 detik)`, fungsi memanggil `setState()` untuk menambah durasi `_secondsElapsed++`, mengkalkulasi ulang *current pace* (menit/km), dan merefresh speedometer.
2. **Model Data Berorientasi Objek (OOP Data Classes)**:
   - File: `lib/models/race_event.dart` (Model Event Lomba)
   - File: `lib/models/run_record.dart` (Model Riwayat Aktivitas Lari)
   - File: `lib/models/app_notification.dart` (Model Notifikasi)
   - *Implementasi*: Memiliki atribut `final`, factory `RaceEvent.fromJson(Map<String, dynamic> json)`, dan `Map<String, dynamic> toJson()`.
3. **Provider State Management**:
   - File: `lib/services/theme_service.dart` & `lib/main.dart`
   - *Implementasi*: Menggunakan `ChangeNotifierProvider` untuk mengubah tema gelap/terang secara global tanpa me-reload aplikasi.

### C. Potongan Kode Penting
```dart
// lib/screens/active_race_screen.dart
void _startTimer() {
  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (!_isRunning) return;
    setState(() {
      _secondsElapsed++;
      // Hitung live pace secara reaktif
      if (_totalDistanceKm > 0.05) {
        _currentPaceMinPerKm = (_secondsElapsed / 60) / _totalDistanceKm;
      }
    });
  });
}
```

### D. Naskah Presentasi:
> *"Di Modul III tentang State dan Data, kami menerapkan pembaruan state reaktif menggunakan `setState()` pada modul lari aktif. Setiap kali sensor GPS atau timer mencatat detik baru, `setState` dipicu untuk mengkalkulasi ulang kecepatan rata-rata (pace) dan merefresh tampilan odometer. Selain itu, seluruh entitas bisnis seperti event lomba dan riwayat aktivitas lari dipetakan ke dalam Data Model OOP class yang memiliki parser `fromJson` dan serializer `toJson`."*

---

## 3. Modul IV – Navigation & Multi-Screen Routing

### A. Konsep Teori Mendalam
Flutter mengelola perpindahan layar menggunakan struktur data **Stack (LIFO: Last In, First Out)** melalui class `Navigator`:
1. **Stack Routing Model**:
   - `Navigator.push(context, route)`: Menambahkan (*push*) halaman baru ke atas tumpukan layar. Halaman sebelumnya tetap hidup di bawahnya.
   - `Navigator.pop(context, [result])`: Mengeluarkan (*pop*) halaman teratas dari tumpukan untuk kembali ke halaman sebelumnya. Dapat mengembalikan nilai (*result*) ke halaman pemanggil.
   - `Navigator.pushReplacement(context, route)`: Mengganti halaman aktif saat ini dengan halaman baru (menghapus halaman aktif dari stack lalu menaruh halaman baru). Digunakan pada transisi **Active Race -> Run Summary** agar saat user menekan tombol 'Back' HP, mereka tidak kembali lagi ke sesi lari yang sudah selesai.
2. **MaterialPageRoute**:
   - Class penyedia transisi animasi native (slide/fade) dan mengelola lifecycle layar baru.
3. **Passing Data Objek via Constructor**:
   - Mekanisme mengirim objek data (seperti model `RaceEvent` atau `RunRecord`) dari halaman asal ke konstruktor halaman tujuan.
4. **Returning Data & Callback (then)**:
   - Menunggu halaman tujuan di-pop untuk mengeksekusi refresh data di halaman asal menggunakan `.then((_) { ... })`.
5. **Tab Navigation (BottomNavigationBar + IndexedStack)**:
   - Pola navigasi berpindah menu tanpa menumpuk rute stack, mempertahankan *scroll position* dan *state* di masing-masing tab menggunakan `IndexedStack`.

### B. Bedah File & Lokasi Kode Asli
1. **Tab Navigasi Utama: BottomNavigationBar & IndexedStack**:
   - File: `lib/screens/main_navigation_wrapper.dart` (Baris 35 - 75)
   - Kodingan: Menggunakan `IndexedStack` untuk menampilkan 5 tab menu (Home, AI Coach, Game, Feedback, Profile) agar form atau chat tidak reset saat berganti menu.
2. **Passing Data Antar Halaman via Constructor**:
   - File: `lib/screens/home_screen.dart` (Baris 175 - 190)
   - Kodingan: `Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveRaceScreen(event: event)))` mem-passing objek model lomba langsung ke tracker lari.
3. **Mengganti Layar Tanpa Bisa Back**:
   - File: `lib/screens/active_race_screen.dart` (Baris 270 - 282)
   - Kodingan: `Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RunSummaryScreen(...)))`.
4. **Menutup Dialog & Mengembalikan Nilai**:
   - File: `lib/screens/active_race_screen.dart` (Baris 155 - 165)
   - Kodingan: `Navigator.pop(ctx, false)` (batal) dan `Navigator.pop(ctx, true)` (berhenti).

---

## 4. Modul V – HTTP Request & REST API Integration

### A. Konsep Teori
**Apa itu REST API?**
REST API (*Representational State Transfer Application Programming Interface*) adalah aturan standar jembatan komunikasi antara aplikasi frontend di HP dengan server database backend melalui protokol web HTTP:
- **`HTTP GET`**: Meminta / mengambil data dari server (contoh: mengambil daftar lomba).
- **`HTTP POST`**: Mengirimkan data baru ke server (contoh: mengirim kredensial login atau mencatat hasil finish lari).
- **Format JSON**: Bahasa universal pertukaran data. Di Flutter, `jsonEncode()` digunakan untuk membungkus data menjadi string JSON saat dikirim, dan `jsonDecode()` digunakan untuk mengurai string respons dari server menjadi objek Dart.
- **Asynchronous (`Future`, `async`, `await`)**: Menjalankan transfer data jaringan di background thread agar antarmuka aplikasi tidak membeku (*freeze*).

### B. File & Kode Implementasi Nyata
1. **HTTP GET (Mengambil Data Event Lomba)**:
   - File: `lib/services/event_service.dart` (Baris 86-96)
   - Kode:
     ```dart
     final response = await http.get(Uri.parse('$baseUrl/api/events')).timeout(const Duration(seconds: 4));
     if (response.statusCode == 200) {
       final data = jsonDecode(response.body);
       final List<dynamic> list = data['events'];
       _events = list.map((item) => RaceEvent.fromJson(item)).toList();
       notifyListeners();
     }
     ```
2. **HTTP POST (Mengirim Kredensial Login)**:
   - File: `lib/services/auth_service.dart` (Baris 330-345)
   - Kode:
     ```dart
     final response = await http.post(
       Uri.parse('$url/api/auth/login'),
       headers: {'Content-Type': 'application/json'},
       body: jsonEncode({'email': cleanEmail, 'password': password}),
     ).timeout(const Duration(milliseconds: 1200));
     ```
3. **Penyedia Data Publik Eksternal: RunSignup REST API**:
   - File: `lib/services/event_service.dart` (Baris 26 & 113)
   - URL: `https://runsignup.com/Rest/races?format=json&results_per_page=16&event_type=running_race`
   - Berfungsi menyuplai data live jadwal lomba maraton dunia secara langsung.

---

## 5. Modul VI – Local Storage & Session Management

### A. Konsep Teori & Teknologi
Local Storage di aplikasi ini menggunakan plugin resmi **`shared_preferences`**. Data disimpan dalam bentuk **Key-Value** di memori flash internal smartphone secara persisten:
- **Persisten**: Data tetap ada meskipun aplikasi ditutup, HP direstart, atau koneksi internet mati.
- **Session Management (`is_logged_in` & `jwt_token`)**: Menjaga sesi login pengguna agar tidak perlu memasukkan email & password setiap kali aplikasi dibuka (*auto-login*).

### B. Penjelasan `is_logged_in`:
`is_logged_in` adalah flag boolean yang disimpan di SharedPreferences. 
- Saat login berhasil: `await prefs.setBool('is_logged_in', true)`.
- Di `lib/main.dart` (Baris 135-150), aplikasi mengecek:
  ```dart
  home: _isLoggedIn ? MainNavigationWrapper(...) : LoginScreen(...)
  ```
  Jika bernilai `true`, aplikasi langsung membuka `MainNavigationWrapper` (Home). Jika `false`, diarahkan ke `LoginScreen`.
- Saat logout: `await prefs.setBool('is_logged_in', false)`.

### C. Pembagian Penggunaan SharedPreferences di Proyek:
1. **Manajemen Sesi**: Menyimpan `'is_logged_in'`, `'jwt_token'`, dan `'user_email'` di `lib/services/auth_service.dart`.
2. **User-Isolated Wallet**: Menyimpan saldo secara spesifik per akun (`user_wallet_balance_<email/uid>`) di `lib/services/auth_service.dart` agar saldo tidak hilang saat logout-login.
3. **Cache Offline Riwayat Lari**: Menyimpan riwayat lari ke string JSON di `lib/services/run_history_service.dart` sehingga data lari tetap terbaca saat offline.
4. **Preferensi Pengguna**: Menyimpan preferensi dark mode (`theme_service.dart`), zona waktu (`timezone_service.dart`), dan API Key Gemini (`ai_coach_screen.dart`).

---

## 6. Modul VII – Location Based Service (LBS), Sensor Akselerometer, & Notifikasi

### A. Location Based Service (LBS / GPS Tracking)
* **Package**: `geolocator` & `latlong2`
* **File**: `lib/services/location_service.dart` & `lib/screens/active_race_screen.dart`
* **Cara Kerja**:
  1. **Permission Check**: Mengecek apakah GPS aktif via `Geolocator.isLocationServiceEnabled()` dan meminta izin lokasi via `Geolocator.requestPermission()`.
  2. **Position Stream**: Mendengarkan perubahan koordinat secara real-time via `Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2))`.
  3. **Akumulasi Jarak (Distance Accumulation)**: Dihitung menggunakan rumus geodesi Haversine:
     ```dart
     final d = _distance.as(LengthUnit.Meter, last.position, newPosition);
     _totalDistanceMeters += d; // Akumulasi jarak lari
     ```
  4. **Jitter & Anti-Cheat Filter**: Gerakan < 2 meter saat diam diabaikan, dan kecepatan > 43 km/jam (12 m/s) diabaikan agar tidak ada kecurangan naik kendaraan bermotor.

### B. Sensor Akselerometer (Akselerasi & Pedometer Langkah Kaki)
* **Package**: `sensors_plus`
* **File**: `lib/services/sensor_service.dart`
* **Cara Kerja**:
  1. Sensor membaca getaran fisik HP pada 3 sumbu kartesian: X, Y, dan Z melalui stream `userAccelerometerEventStream()`.
  2. **Menghitung Magnitudo Akselerasi**:
     ```dart
     final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
     ```
  3. **Menentukan Status Gerakan**:
     - `magnitude < 1.2` ➡️ "Santai / Diam"
     - `magnitude 1.2 - 3.5` ➡️ "Berjalan Santai"
     - `magnitude 3.5 - 8.0` ➡️ "Berlari (Running)"
     - `magnitude > 8.0` ➡️ "Sprint Cepat!"
  4. **Algoritma Peak Detection (Menghitung Langkah)**:
     Jika hentakan `magnitude > 2.4` dan jeda waktu langkah melebihi 260 milidetik, counter langkah `_stepCount++` bertambah.

### C. Sistem Notifikasi (Push Notification & In-App Alerts)
* **Package**: `flutter_local_notifications`
* **File**: `lib/services/notification_service.dart` & `lib/screens/notification_screen.dart`
* **Cara Kerja**:
  1. **Android Notification Channel**: Menginisialisasi channel dengan `importance: Importance.max` dan `priority: Priority.high` agar notifikasi muncul sebagai *heads-up banner pop-up* serta membunyikan getar/suara di HP.
  2. **Pemicu Notifikasi (Triggers)**:
     - Saat **Mulai Lari**: Muncul notifikasi *"Race Berlangsung: [Nama Lomba]"*.
     - Saat **Finish**: Muncul notifikasi *"Finish Terverifikasi: [Nama Lomba]"*.
  3. **In-App Notification Center**: Notifikasi disimpan ke SharedPreferences dan dapat dibaca ulang melalui ikon lonceng di layar Home.

---

## 7. Daftar Lengkap Seluruh API di Aplikasi (Internal & Cloud)

### A. Backend REST API Internal (Node.js & Express - `backend/src/`)
Dijalankan menggunakan `npm start` di port `5000`:
- **Auth Routes (`backend/src/routes/authRoutes.js`)**:
  - `POST /api/auth/register` : Mendaftarkan akun baru (hashing Bcrypt).
  - `POST /api/auth/login` : Login user & menerbitkan JWT Token.
  - `POST /api/auth/send-otp` : Mengirim kode verifikasi OTP.
  - `POST /api/auth/verify-otp` : Validasi kode OTP.
  - `GET /api/auth/profile` : Mengambil data akun terautentikasi (Bearer JWT).
- **Event Routes (`backend/src/routes/eventRoutes.js`)**:
  - `GET /api/events` : Menampilkan katalog lomba lari dari database PostgreSQL.
  - `POST /api/events/results` : Mencatat hasil finish lari pelari (terproteksi JWT).
- **Feedback Routes (`backend/src/routes/feedbackRoutes.js`)**:
  - `GET /api/feedback` : Mengambil daftar ulasan dan bintang rating dari pelari lain.
  - `POST /api/feedback` : Mengirim review dan rating baru.
- **Blockchain Routes (`backend/src/routes/blockchainRoutes.js`)**:
  - `GET /api/blockchain/wallet-info` : Memeriksa status smart contract Web3.
  - `POST /api/blockchain/mint` : Menerbitkan hash sertifikat/medali finisher ke blockchain.

### B. Third-Party & Cloud APIs
1. **RunSignup REST API** (`https://runsignup.com/Rest/races`): Mengambil feed jadwal maraton global live.
2. **Supabase Cloud API & GoTrue Auth** (`https://<project-id>.supabase.co`): Sinkronisasi tabel profiles, race_events, dan autentikasi cloud.
3. **Google Gemini Generative AI API**: Asisten cerdas virtual AI Coach Rani di `lib/services/ai_coach_service.dart`.
4. **Currency Exchange Rate API** (`https://open.er-api.com/v6/latest/USD`): Mengambil kurs live mata uang USD/IDR di `lib/services/currency_service.dart`.
5. **TimeAPI Timezone Service** (`https://timeapi.io`): Mengambil sinkronisasi jam dunia akurat di `lib/services/timezone_service.dart`.

---

## 8. Panduan Alur Live Demo Aplikasi saat Presentasi

| Urutan Langkah | Layar Aplikasi | Hal yang Ditunjukkan & Diterangkan | Modul Terkait |
|---|---|---|---|
| **Langkah 1** | **Halaman Login** | Tunjukkan input email & password. Saat login berhasil, terbitkan JWT & simpan flag `is_logged_in`. | **Modul V (HTTP POST)** & **Modul VI (Local Storage)** |
| **Langkah 2** | **Halaman Home** | Tunjukkan `BottomNavigationBar` 5 tab. Scroll daftar event lomba yang di-render secara efisien. | **Modul II (Layout/ListView)** & **Modul IV (Navigation)** |
| **Langkah 3** | **Pilih Event** | Klik kartu event. Tunjukkan perpindahan rute membawa objek lomba via constructor argument. | **Modul IV (Passing Data Argument)** |
| **Langkah 4** | **Active Race** | Tekan "Mulai Lari". Tunjukkan GPS live berjalan, timer & pace ter-update per detik, sensor akselerometer mendeteksi langkah kaki. | **Modul III (setState)** & **Modul VII (LBS & Akselerometer)** |
| **Langkah 5** | **Finish Lomba** | Tekan Finish. Muncul banner push notifikasi di status bar HP, lalu `pushReplacement` menuju layar summary hasil lari. | **Modul VII (Notification)** & **Modul IV (Navigator PushReplacement)** |

---

## 9. Tanya Jawab Kritis Penguji / Dosen (FAQ)

### Q1: Mengapa menggunakan `ListView.builder` dan bukan `ListView(children: [...])`?
> **Jawaban**: `ListView(children: [...])` akan me-render seluruh widget anak ke dalam RAM secara bersamaan saat layar dibuka, yang berisiko membuat aplikasi lag jika daftar datanya banyak. Sedangkan `ListView.builder` menggunakan konsep daur ulang elemen (*recycling*) yang hanya me-render item yang saat itu terlihat di viewport layar pengguna (*lazy loading*), sehingga sangat hemat memori.

### Q2: Mengapa transisi dari Active Race ke Run Summary menggunakan `Navigator.pushReplacement`?
> **Jawaban**: Jika menggunakan `Navigator.push` biasa, layar pelacak GPS (`ActiveRaceScreen`) masih tertinggal di bawah tumpukan stack navigasi. Akibatnya, jika pelari berada di layar ringkasan lalu menekan tombol Back fisik smartphone, mereka akan kembali ke layar pelacakan lari yang sesungguhnya sudah selesai. Dengan `pushReplacement`, layar tracker dikeluarkan dan digantikan oleh layar ringkasan.

### Q3: Bagaimana cara kerja auto-login di aplikasi ini?
> **Jawaban**: Aplikasi memanfaatkan `SharedPreferences` untuk menyimpan key `is_logged_in = true` dan `jwt_token`. Pada file `main.dart`, sebelum antarmuka pertama kali digambar, fungsi `isLoggedIn()` mengecek apakah nilai tersebut ada. Jika ada, aplikasi langsung mengarahkan rute utama ke `MainNavigationWrapper` tanpa harus melewati layar login.

### Q4: Bagaimana cara sensor akselerometer membedakan orang diam, berjalan, dan berlari?
> **Jawaban**: Kami menghitung total magnitudo akselerasi dari 3 sumbu menggunakan rumus vektor Euclidean $\sqrt{x^2 + y^2 + z^2}$. Nilai magnitudo tersebut kemudian dikategorikan: di bawah 1.2 berarti diam, 1.2–3.5 berjalan, dan di atas 3.5 dikategorikan sebagai berlari. Langkah kaki dihitung menggunakan algoritma *Peak Detection* saat hentakan magnitudo melewati threshold 2.4 dengan jeda waktu minimal 260 milidetik.

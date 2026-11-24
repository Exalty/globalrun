# PANDUAN LENGKAP IMPLEMENTASI MODUL PRAKTIKUM FLUTTER
**Aplikasi: Global Virtual Race (GlobalRun)**

Dokumen ini memetakan seluruh materi dari **Modul II sampai Modul VII** ke dalam kode program aplikasi `GlobalRun`. Setiap modul dijelaskan secara mendalam mencakup:
1. **Konsep Teori Modul**
2. **File & Lokasi Baris Kodingan Asli**
3. **Analisis Potongan Kode (Code Snippet)**
4. **Naskah Presentasi Siap Pakai di Depan Dosen / Penguji**
5. **Kemungkinan Pertanyaan Dosen & Cara Menjawabnya**

---

## DAFTAR ISI MODUL
- [Modul II: Widget & Layout](#1-modul-ii--widget--layout)
- [Modul III: State Management & Data Processing](#2-modul-iii--state-management--data-processing)
- [Modul IV: Navigation & Multi-Screen Routing](#3-modul-iv--navigation--multi-screen-routing)
- [Modul V: HTTP Request & REST API Integration](#4-modul-v--http-request--rest-api-integration)
- [Modul VI: Local Storage & Offline Persistence](#5-modul-vi--local-storage--offline-persistence)
- [Modul VII: Notification & Location Based Service (LBS)](#6-modul-vii--notification--location-based-service-lbs)
- [Alur Live Demo Step-by-Step](#7-panduan-alur-demo-aplikasi-saat-presentasi)

---

## 1. Modul II – Widget & Layout

### A. Konsep Teori
Flutter adalah *framework UI berbasis pohon widget (Widget Tree)*. Terdapat dua jenis widget fundamental:
- **`StatelessWidget`**: Widget statis / imutabel yang tidak memiliki state internal yang berubah setelah di-*build*. UI murni bergantung pada konfigurasi awal/parameter yang diterima dari parent.
- **`StatefulWidget`**: Widget dinamis yang memiliki objek `State` terpisah. Widget ini dapat me-render ulang tampilannya saat data internalnya berubah sepanjang daur hidupnya.
- **Layout Widgets**: Widget untuk mengatur posisi dan tata letak hierarki antarmuka:
  - `Column` & `Row`: Layout linear satu dimensi (vertikal & horizontal).
  - `Stack`: Layout berlapis (menumpuk widget di atas widget lain secara sumbu Z).
  - `ListView.builder`: Rendering daftar secara *lazy loading* / on-demand untuk efisiensi alokasi memori RAM.
  - `Card`, `Container`, `Padding`, `SizedBox`: Pengaturan dekorasi, radius, padding, dan jarak.

### B. Bukti & Lokasi File di Project
1. **StatelessWidget**:
   - File: `lib/widgets/athlete_comparison_dialog.dart` (Baris 9)
   - *Penjelasan*: Menampilkan perbandingan data pelari/atlet yang bersifat *read-only* murni dari data yang di-*passing*.
2. **StatefulWidget**:
   - File: `lib/screens/active_race_screen.dart` (Baris 13)
   - *Penjelasan*: Layar tracker lari yang terus berubah metrik waktunya, jarak GPS, kecepatan pace, dan status sensor lari.
3. **Penyusunan Layout Kompleks (Column, Row, Card, Stack)**:
   - File: `lib/screens/home_screen.dart` (Baris 240-350)
   - *Penjelasan*: `Column` menyusun header profil, banner event, dan daftar kategori secara vertikal. `Row` menyusun tombol aksi dan statistik horizontal. `Card` memberikan efek elevasi dan rounded corner modern.
4. **ListView.builder (Efisiensi Memori)**:
   - File: `lib/screens/home_screen.dart` (Baris 398) dan `lib/screens/run_history_screen.dart`
   - *Penjelasan*: Daftar riwayat lari dan event di-render dinamis menggunakan builder agar kartu event hanya digambar saat masuk ke viewport layar HP pengguna.

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
            // Widget Thumbnail & Info disusun rapi
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

### D. Naskah Presentasi (Ucapkan Ini ke Dosen):
> *"Pada Modul II tentang Widget dan Layout, aplikasi GlobalRun memisahkan arsitektur antarmuka menjadi StatelessWidget untuk dialog data statis seperti AthleteComparisonDialog dan StatefulWidget untuk layar dinamis seperti ActiveRaceScreen yang metrik larinya berubah setiap detik. Untuk layouting, kami menyusun tampilan menggunakan kombinasi Column, Row, dan Stack, serta mengoptimalkan performa rendering daftar lomba menggunakan ListView.builder agar hanya me-render elemen yang tampak di layar sehingga menghemat penggunaan memori HP."*

### E. Antisipasi Pertanyaan Dosen:
* **Tanya**: "Kenapa pakai `ListView.builder` bukan `ListView(children: [...])` biasa?"
* **Jawab**: "Karena `ListView(children: [...])` akan langsung memuat seluruh item ke RAM sekaligus saat layar dibuka, yang berisiko membuat aplikasi lag jika datanya puluhan atau ratusan. `ListView.builder` menggunakan konsep daur ulang (*recycling*) yang hanya me-render item yang terlihat di viewport pengguna."

---

## 2. Modul III – State Management & Data Processing

### A. Konsep Teori
State adalah informasi yang dibaca secara sinkron ketika widget di-build dan dapat berubah selama masa hidup widget tersebut:
- **Ephemeral / Local State (`setState`)**: State yang hanya relevan untuk satu widget lokal. Pemanggilan `setState((){})` memberitahu Flutter framework bahwa objek internal telah berubah dan memicu metode `build()` dijalankan ulang.
- **Model Data OOP**: Penerapan konsep enkapsulasi objek (POJO / Plain Old Java/Dart Object) dengan atribut bertipe data kuat (*type-safe*), konstruktor, serta fungsi serialisasi (`fromJson` dan `toJson`).
- **Global App State (Provider)**: Pengelolaan state yang dibagikan ke banyak layar (misal tema aplikasi dan otentikasi global).

### B. Bukti & Lokasi File di Project
1. **Reaktif State Update dengan `setState()`**:
   - File: `lib/screens/active_race_screen.dart` (Baris 180-210)
   - *Implementasi*: Setiap detak waktu `Timer.periodic(1 detik)`, fungsi memanggil `setState()` untuk menambah durasi `_secondsElapsed++`, mengkalkulasi ulang *current pace* (menit/km), dan memperbarui live odometer.
2. **Model Data Berorientasi Objek (OOP Data Classes)**:
   - File: `lib/models/race_event.dart` (Model Event Lomba)
   - File: `lib/models/run_record.dart` (Model Riwayat Aktivitas Lari)
   - File: `lib/models/app_notification.dart` (Model Notifikasi)
   - *Implementasi*: Memiliki atribut `final`, factory `RaceEvent.fromJson(Map<String, dynamic> json)`, dan `Map<String, dynamic> toJson()`.
3. **Provider State Management**:
   - File: `lib/services/theme_service.dart` dan `lib/main.dart`
   - *Implementasi*: Menggunakan `ChangeNotifier` dan `ChangeNotifierProvider` untuk mengubah tema warna aplikasi secara realtime tanpa reload halaman.

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

### D. Naskah Presentasi (Ucapkan Ini ke Dosen):
> *"Pada Modul III mengenai State dan Pengolahan Data, kami menerapkan pembaruan state lokal menggunakan `setState()` pada modul lari aktif. Setiap kali sensor GPS atau timer mencatat detik baru, fungsi setState memicu render ulang widget teks jarak dan pace. Seluruh data mentah yang datang dari backend maupun sensor tidak dibiarkan sebagai generic map, melainkan dipetakan ke dalam Data Model OOP yang type-safe seperti `RaceEvent` dan `RunRecord` lengkap dengan method serialisasi JSON."*

### E. Antisipasi Pertanyaan Dosen:
* **Tanya**: "Apa fungsi `factory fromJson` pada model data Anda?"
* **Jawab**: "Factory constructor `fromJson` berfungsi untuk memetakan key-value dari respons payload REST API atau cache lokal bertipe `Map<String, dynamic>` menjadi objek Dart yang bertipe data jelas (*type-safe*), sehingga terhindar dari error runtime seperti salah pengetikan nama key atau null exception."

---

## 3. Modul IV – Navigation & Multi-Screen Routing

### A. Konsep Teori Mendalam
Flutter mengelola perpindahan layar menggunakan struktur data **Stack (LIFO: Last In, First Out)** melalui class `Navigator`:
1. **Stack Routing Model**:
   - `Navigator.push(context, route)`: Menambahkan (*push*) halaman baru ke atas tumpukan layar. Halaman sebelumnya tetap hidup di memori di bawahnya.
   - `Navigator.pop(context, [result])`: Mengambil dan menghapus (*pop*) halaman teratas dari tumpukan untuk kembali ke halaman sebelumnya. Dapat mengembalikan nilai (*result*) ke halaman pemanggil.
   - `Navigator.pushReplacement(context, route)`: Mengganti halaman aktif saat ini dengan halaman baru (menghapus halaman aktif dari stack lalu menaruh halaman baru). Digunakan pada transisi **Active Race -> Run Summary** agar saat user menekan tombol 'Back' HP, mereka tidak kembali lagi ke sesi lari yang sudah selesai.
2. **MaterialPageRoute**:
   - Class penyedia transisi animasi native (slide/fade) dan mengelola lifecycle layar baru.
3. **Passing Data Objek via Constructor**:
   - Mekanisme mengirim objek data (seperti model `RaceEvent` atau `RunRecord`) dari halaman asal ke konstruktor halaman tujuan.
4. **Returning Data & Callback (then)**:
   - Menunggu halaman tujuan di-pop untuk mengeksekusi refresh data di halaman asal menggunakan `.then((_) { ... })`.
5. **Tab Navigation (BottomNavigationBar + IndexedStack)**:
   - Pola navigasi berpindah menu tanpa menumpuk rute stack, mempertahankan *scroll position* dan *state* di masing-masing tab menggunakan `IndexedStack`.

---

### B. Bedah File & Lokasi Kode Asli

#### 1. Tab Navigasi Utama: BottomNavigationBar & IndexedStack
- **File**: `lib/screens/main_navigation_wrapper.dart` (Baris 35 - 75)
- **Kode Asli**:
```dart
class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // 5 Layar utama aplikasi dimuat ke dalam memori
    _screens = [
      HomeScreen(blockchainService: widget.blockchainService, aiCoachService: widget.aiCoachService),
      AiCoachScreen(coachService: widget.aiCoachService),
      const MiniGameScreen(),
      const FeedbackScreen(),
      ProfileScreen(onLogout: widget.onLogout),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack menjaga agar state halaman yang ditinggalkan tidak reset
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        child: Row(
          children: [
            _buildNavTab(0, Icons.home_rounded, 'Home'),
            _buildNavTab(1, Icons.auto_awesome_rounded, 'AI Coach'),
            _buildNavTab(2, Icons.sports_esports_rounded, 'Game'),
            _buildNavTab(3, Icons.rate_review_rounded, 'Feedback'),
            _buildNavTab(4, Icons.person_rounded, 'Profil'),
          ],
        ),
      ),
    );
  }
}
```
- **Konsepnya**: `IndexedStack` menampilkan widget anak sesuai `_currentIndex`. Ketika user berpindah dari tab Home ke AI Coach lalu kembali ke Home, posisi scroll list dan data event di Home tidak hilang/reset.

---

#### 2. Passing Data Antar Halaman: Navigator.push + MaterialPageRoute
- **File**: `lib/screens/home_screen.dart` (Baris 175 - 190)
- **Kode Asli**:
```dart
void _openRace(RaceEvent event) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ActiveRaceScreen(
        event: event, // <-- PASSING DATA OBJEK LOMBA KE LAYAR TRACKER
        blockchainService: widget.blockchainService,
        aiCoachService: widget.aiCoachService,
      ),
    ),
  ).then((_) {
    // REFRESH CALLBACK: Dijalankan otomatis saat kembali dari ActiveRaceScreen
    _loadCompletedRuns();
    _loadWalletAndPrefs();
  });
}
```
- **Konsepnya**: Ketika pelari memilih kartu lomba di `HomeScreen`, method `Navigator.push` menumpuk `ActiveRaceScreen` ke atas stack navigasi. Objek model `event` dikirimkan secara langsung ke konstruktor. Saat layar lari ditutup, blok `.then((_) { ... })` otomatis memperbarui riwayat lari dan saldo terbaru.

---

#### 3. Mengganti Layar Tanpa Bisa Back: Navigator.pushReplacement
- **File**: `lib/screens/active_race_screen.dart` (Baris 270 - 282)
- **Kode Asli**:
```dart
// Saat pelari menekan tombol FINISH / menyelesaikan target lomba
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => RunSummaryScreen(
      record: record, // <-- MENGIRIM HASIL STATISTIK LARI KE SUMMARY
      blockchainService: widget.blockchainService,
      block: minted,
    ),
  ),
);
```
- **Konsepnya**: Menggunakan `pushReplacement` agar `ActiveRaceScreen` (layar tracker GPS aktif) dihapus dari rute stack dan digantikan oleh `RunSummaryScreen`. Tujuannya mencegah pengguna menekan tombol Back HP dan tidak sengaja masuk kembali ke sesi lomba yang sudah selesai.

---

#### 4. Menutup Dialog & Mengembalikan Nilai: Navigator.pop
- **File**: `lib/screens/active_race_screen.dart` (Baris 155 - 165)
- **Kode Asli**:
```dart
// Dialog Konfirmasi Berhenti Lari
showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Hentikan Lari?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx, false), // Batal: Return false
        child: const Text('Lanjut Lari'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(ctx, true),  // Ya, berhenti: Return true
        child: const Text('Ya, Berhenti'),
      ),
    ],
  ),
);
```
- **Konsepnya**: `Navigator.pop(context, value)` menutup layer pop-up modal/dialog dan mengembalikan nilai boolean (true atau false) ke pemanggil fungsi `showDialog`.

---

### C. Naskah Presentasi (Ucapkan Ini ke Dosen):
> *"Pada Modul IV mengenai Navigasi dan Routing, aplikasi GlobalRun mengimplementasikan pola navigasi multi-layar yang sangat lengkap:*
> *1. Untuk navigasi menu utama, kami menggunakan MainNavigationWrapper dengan IndexedStack dan custom BottomNavigationBar 5 tab (Home, AI Coach, Game, Feedback, Profile) agar state dan posisi scroll tiap halaman tidak hilang saat berpindah menu.*
> *2. Untuk alur lomba, saat pengguna memilih kartu event di HomeScreen, kami menerapkan Navigator.push dengan MaterialPageRoute untuk mem-passing objek model data RaceEvent secara langsung ke ActiveRaceScreen.*
> *3. Kami juga menggunakan fitur callback .then() pada Navigator.push untuk me-refresh data riwayat dan saldo saat kembali ke Home.*
> *4. Ketika pelari menyelesaikan lomba, kami secara sengaja menggunakan Navigator.pushReplacement menuju RunSummaryScreen agar layar tracker GPS dikeluarkan dari navigation stack, sehingga jika pelari menekan tombol kembali di smartphone, mereka tidak akan masuk lagi ke sesi lari yang sudah tuntas.*
> *5. Pada dialog konfirmasi, kami menggunakan Navigator.pop(ctx, boolean) untuk mengembalikan data pilihan pengguna ke controller."*

---

### D. Antisipasi Pertanyaan Dosen & Kunci Jawaban:
- **Tanya**: "Kenapa saat selesai lari pakai Navigator.pushReplacement, bukan Navigator.push biasa?"
- **Jawab**: "Jika menggunakan push biasa, layar ActiveRaceScreen masih tertinggal di bawah stack navigasi. Akibatnya saat pelari berada di layar Ringkasan (RunSummaryScreen) lalu menekan tombol Back di smartphone, mereka akan kembali ke layar pelacakan lari yang sudah selesai, yang mana logikanya sudah tidak valid. Dengan pushReplacement, layar tracker digantikan sepenuhnya sehingga alur navigasi bersih."
- **Tanya**: "Apa perbedaan IndexedStack dengan berpindah halaman via Navigator.push?"
- **Jawab**: "IndexedStack mempertahankan state dari seluruh widget anaknya di memori. Jadi form input di tab Feedback atau percakapan di tab AI Coach tidak ter-reset saat pengguna bolak-balik ke tab Home. Sedangkan Navigator.push menumpuk halaman baru ke tumpukan rute."

---

## 4. Modul V – HTTP Request & REST API Integration

### A. Konsep Teori
Aplikasi modern terhubung ke web service backend melalui HTTP:
- Protokol Request: `GET` (mengambil data), `POST` (mengirim/menyimpan data baru).
- Pemrograman Asinkron (*Asynchronous*): Menggunakan `Future`, `async`, dan `await` agar proses transfer data jaringan tidak membekukan (*freeze*) rendering UI / main thread.
- Serialisasi Payload: `jsonEncode()` untuk mengirim data ke server dan `jsonDecode()` untuk mem-parsing respons JSON.
- Pengaturan Header: `Content-Type: application/json` dan bearer authentication token.

### B. Bukti & Lokasi File di Project
1. **Layanan REST API Autentikasi (POST Login & Register)**:
   - File: `lib/services/auth_service.dart` (Baris 60-120)
   - *Implementasi*: Mengirim HTTP POST request ke server backend Node.js (`/api/auth/login` & `/api/auth/register`) membawa email dan password terenkripsi.
2. **Layanan REST API Event Lomba (GET Events)**:
   - File: `lib/services/event_service.dart` (Baris 30-70)
   - *Implementasi*: Mengambil daftar event lomba dari server secara online dengan metode `http.get`, memeriksa `statusCode == 200`, dan memetakan hasilnya menjadi `List<RaceEvent>`.
3. **Penerjemah Error Ramah Pengguna (*Human Error Handling*)**:
   - File: `lib/utils/human_error.dart`
   - *Implementasi*: Menangkap `SocketException`, `TimeoutException`, atau error 500 dan menerjemahkannya menjadi pesan bahasa Indonesia yang mudah dipahami pengguna.

### C. Potongan Kode Penting
```dart
// lib/services/event_service.dart
Future<List<RaceEvent>> fetchEvents() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/events'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => RaceEvent.fromJson(json)).toList();
    } else {
      throw Exception('Gagal memuat event dari server');
    }
  } catch (e) {
    debugPrint('HTTP Error: $e');
    return []; // Fallback gracefully
  }
}
```

### D. Naskah Presentasi (Ucapkan Ini ke Dosen):
> *"Pada Modul V HTTP Request, aplikasi mengintegrasikan package `http` untuk berkomunikasi dengan REST API backend Node.js. Pemanggilan API dibuat sepenuhnya asynchronous dengan `Future` dan `async/await` agar antarmuka tidak freeze. Data yang dikirim diserialisasi menggunakan `jsonEncode` dan respons server diparsing dengan `jsonDecode`. Selain itu, kami menyertakan timeout handling dan blok try-catch agar jika server atau koneksi internet bermasalah, aplikasi tidak crash dan menampilkan pesan error yang ramah."*

---

## 5. Modul VI – Local Storage & Offline Persistence

### A. Konsep Teori
Menyimpan data di media penyimpanan internal perangkat (*on-device disk storage*):
- **`SharedPreferences`**: Penyimpanan berbasis key-value sederhana yang persisten untuk data seperti token login, konfigurasi user, pengaturan tema, atau cache JSON.
- **Keamanan & Persistensi**: Mencegah pengguna harus login ulang setiap kali aplikasi dibuka (*auto-login session*) dan menyediakan ketersediaan data saat tidak ada koneksi internet (*offline mode*).

### B. Bukti & Lokasi File di Project
1. **Penyimpanan Token Sesi Login (JWT)**:
   - File: `lib/services/auth_service.dart` (Baris 25-40)
   - *Implementasi*: Saat login sukses, token disimpan:
     ```dart
     final prefs = await SharedPreferences.getInstance();
     await prefs.setString('auth_token', token);
     ```
     Ketika aplikasi pertama dibuka, aplikasi membaca token tersebut. Jika ada, pengguna langsung diarahkan ke `HomeScreen` tanpa perlu login lagi.
2. **Penyimpanan Kunci AI Coach Lokal**:
   - File: `lib/screens/ai_coach_screen.dart` (Baris 69 & 195)
   - *Implementasi*: Menyimpan API Key Gemini pengguna secara lokal di memory device menggunakan `prefs.setString('custom_gemini_api_key', key)`.
3. **Penyimpanan Cache Riwayat Lari Offline**:
   - File: `lib/services/run_history_service.dart` (Baris 40-65)
   - *Implementasi*: Menyimpan riwayat lari ke dalam string cache JSON lokal via SharedPreferences, sehingga saat pelari berada di area minim sinyal, riwayat lari tetap tersimpan dan dapat dilihat.

### C. Potongan Kode Penting
```dart
// lib/services/run_history_service.dart
Future<void> save(RunRecord record) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = await _getCurrentUserId() ?? 'guest';
  final key = 'run_history_$userId';

  // Ambil cache lama
  final existingJson = prefs.getString(key);
  List<dynamic> list = existingJson != null ? jsonDecode(existingJson) : [];
  
  // Tambah riwayat baru & simpan kembali
  list.insert(0, record.toJson());
  await prefs.setString(key, jsonEncode(list));
}
```

### D. Naskah Presentasi (Ucapkan Ini ke Dosen):
> *"Pada Modul VI mengenai Local Storage, kami menggunakan plugin `shared_preferences` untuk menyimpan data penting secara persisten di memori lokal smartphone. Pengaplikasiannya ada pada manajemen sesi otentikasi—di mana JWT token disimpan agar mendukung fitur auto-login—serta penyimpanan cache riwayat aktivitas lari secara lokal. Dengan begitu, data aktivitas lari pelari tidak hilang meski aplikasi ditutup atau sedang berada di luar jangkauan internet."*

---

## 6. Modul VII – Notification & Location Based Service (LBS)

### A. Konsep Teori
Memanfaatkan kapabilitas perangkat keras smartphone (*hardware capabilities*):
- **Location Based Service (LBS)**: Mengakses sensor Global Positioning System (GPS) perangkat melalui package `geolocator` untuk memantau koordinat garis lintang (*latitude*) dan garis bujur (*longitude*).
- **Kalkulasi Geodesi**: Menghitung jarak fisik antar titik koordinat secara akurat menggunakan rumus Harversine (`Geolocator.distanceBetween`).
- **Local Notification**: Menggunakan `flutter_local_notifications` untuk memunculkan pemberitahuan sistem (banner/heads-up notification) di bar notifikasi Android/iOS saat kondisi tertentu terpenuhi.

### B. Bukti & Lokasi File di Project
1. **Verifikasi Izin & Live GPS Tracking (LBS)**:
   - File: `lib/services/location_service.dart` (Baris 15-55)
   - *Implementasi*: Meminta izin lokasi runtime (`requestPermission`), memeriksa status GPS HP, dan membuka aliran data stream `Geolocator.getPositionStream` dengan akurasi tinggi (`LocationAccuracy.high`).
2. **Kalkulasi Jarak Real-Time Lari**:
   - File: `lib/screens/active_race_screen.dart` (Baris 200-240)
   - *Implementasi*: Saat pelari bergerak dari posisi A ke B, koordinat dihitung:
     ```dart
     double distanceInMeters = Geolocator.distanceBetween(
       _lastPosition.latitude, _lastPosition.longitude,
       newPosition.latitude, newPosition.longitude,
     );
     ```
3. **Pengiriman Notifikasi Lokal**:
   - File: `lib/services/notification_service.dart` (Baris 20-65)
   - *Implementasi*: Menginisialisasi `AndroidNotificationDetails` dengan channel khusus dan memanggil `flutterLocalNotificationsPlugin.show()` saat pelari mencapai milestone (finish lomba).

### C. Potongan Kode Penting
```dart
// lib/services/location_service.dart
Stream<Position> getPositionStream() {
  const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 3, // Update setiap perpindahan minimal 3 meter
  );
  return Geolocator.getPositionStream(locationSettings: locationSettings);
}
```

### D. Naskah Presentasi (Ucapkan Ini ke Dosen):
> *"Pada Modul VII Notification & LBS, aplikasi mengimplementasikan fitur inti pelacakan lari berbasis lokasi. Kami menggunakan plugin `geolocator` untuk memvalidasi izin akses lokasi dan mendengarkan stream koordinat GPS pelari secara real-time. Jarak tempuh diakumulasi menggunakan rumus jarak geodesi `Geolocator.distanceBetween`. Selain itu, kami menyematkan plugin `flutter_local_notifications` untuk memicu notifikasi lokal secara otomatis di HP pengguna ketika pelari berhasil mencapai target jarak atau menyelesaikan lomba."*

---

## 7. Panduan Alur Demo Aplikasi saat Presentasi

Untuk memberikan demonstrasi yang terstruktur dan mengesankan dosen/asisten penguji, ikuti urutan live demo berikut:

```
[1. Halaman Login] 
   └── Tunjukkan login form -> data dikirim via HTTP POST (Modul V)
   └── Token sesi tersimpan di SharedPreferences (Modul VI)

[2. Halaman Home]
   └── Tunjukkan BottomNavigationBar 4 tab (Modul IV)
   └── Tunjukkan susunan layout Banner, Row status, dan ListView event (Modul II)

[3. Pilih Event Lomba]
   └── Klik salah satu kartu event -> Navigator.push membawa objek event (Modul IV)

[4. Halaman Active Race Tracker]
   └── Tekan "Mulai Lari" -> Sensor GPS LBS aktif (Modul VII)
   └── Tunjukkan timer & pace ter-update setiap detik oleh setState (Modul III)

[5. Selesaikan Lomba / Finish]
   └── Notifikasi pencapaian muncul di status bar HP (Modul VII)
   └── Muncul ringkasan lari dan Navigator.pop kembali ke halaman utama (Modul IV)
```

---

> [!TIP]
> File ini disimpan langsung di folder root project: `D:\code\globalrun\PANDUAN_MODUL_PRAKTIKUM.md`. Anda bisa membukanya kapan saja melalui VS Code saat mempersiapkan materi ujian / presentasi!

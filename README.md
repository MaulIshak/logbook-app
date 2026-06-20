# Smart-Patrol Logbook (Vision & Image Processing)

Aplikasi Flutter ini dirancang sebagai logbook cerdas dengan modul pengenalan visi dan pengolahan citra mendalam menggunakan akselerasi native C++ OpenCV. Fitur utama meliputi tangkapan kamera langsung, manajemen noise, perataan histogram, pemfilteran spasial, serta Transformasi Fourier (Frequency Domain Magnitude Spectrum).

## Prasyarat Lingkungan (Prerequisites)

Sebelum menjalankan project, pastikan environment Anda sudah memiliki:
1.  **Flutter SDK** (Versi 3.19.0 atau lebih baru direkomendasikan).
2.  **Dart SDK** yang ter-bundling dengan instalasi Flutter.
3.  **Android Studio** atau toolchain iOS (Xcode) jika ingin me-run ke simulator/device Apple.
4.  C++ Build Tools (Bawaan NDK/CMake pada Android Studio) untuk mendukung kompilasi native OpenCV binding.

## Langkah Instalasi 🛠️

Ikuti langkah-langkah di bawah ini untuk mengatur dan menjalankan project pada *environment* lokal Anda:

### 1. Clone & Ambil Dependensi
Buka terminal dan arahkan ke direktori proyek, kemudian unduh seluruh dependensi *packages*:
```bash
flutter clean
flutter pub get
```

### 2. Konfigurasi `opencv_dart`
Project ini menggunakan modul `opencv_dart`. Biasanya dependensi native pre-built akan ditangani otomatis oleh Flutter, namun pastikan untuk *build* pertama kalinya memakan waktu lebih lama karena proses kompilasi native binari FFI OpenCV:
```bash
# Menjalankan script build standar flutter akan trigger kompilasi bindings
flutter build apk --debug
```

### 3. Persiapan Device / Emulator
Aplikasi ini mengakses sensor perangkat keras intensif (Kamera). Jadi SANGAT DISARANKAN untuk dieksekusi secara langsung menggunakan **Real Device (Perangkat Fisik Asli)**. 
- Jika menggunakan Emulator Android, pastikan _Virtual Camera_ menyala dan berfungsi. Fitur _image processing_ akan meniru input kamera emulator menjadi data byte `Uint8List`.
- Pastikan pengaturan izin `CAMERA` sudah disetujui (Izin sudah didefinisikan pada `AndroidManifest.xml` aplikasi).

### 4. Menjalankan Aplikasi
Setelah perangkat/emulator terhubung, eksekusi aplikasi menggunakan konfigurasi standard debug:
```bash
flutter run
```

## Troubleshooting (Masalah Umum)

- **Crash ketika membuka halaman kamera:** Pastikan perangkat Anda memberikan hak akses kamera (Permissions "Allow").
- **Error kompilasi `dartcv4` atau `opencv_dart`:** Ini terjadi jika *cache pub* Anda berantakan atau tools C++ Android Studio (NDK CMake) belum terpasang. Jalankan `flutter clean`, cek instalasi Android NDK, lalu jalankan `flutter pub get` ulang.
- **Peringatan Performa/Lag:** Pengolahan Fourier Transform berat untuk *Debug Mode*. Untuk menilai kecepatan komputasi asli dari native OpenCV, jalankan aplikasi di mode rilis: `flutter run --release`.

---
*Ditenagai oleh Flutter & OpenCV 4*

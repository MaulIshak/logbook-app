import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:my_logbook_app/features/vision/detection_result.dart';

/// Controller untuk fitur Smart-Patrol Vision.
///
/// Menerapkan konsep dari materi pengayaan:
/// 1. Performance Budgeting — Frame Dropping untuk menjaga UI 60 FPS.
/// 2. Concurrency — Flag [isProcessing] mencegah buffer bloat.
/// 3. SRP — Menghasilkan [DetectionResult] sebagai DTO, bukan menggambar langsung.
/// 4. Inference-Ready Architecture — Siap dihubungkan ke model YOLO di Modul 7.
class VisionController extends ChangeNotifier with WidgetsBindingObserver {
  CameraController? controller;
  bool isInitialized = false;
  String? errorMessage;

  // === Task 3: Permission denied state ===
  /// Flag khusus untuk membedakan error biasa vs permission denied.
  /// Digunakan oleh VisionView untuk menampilkan tombol "Open Settings".
  bool _isPermissionDenied = false;
  bool get isPermissionDenied => _isPermissionDenied;

  // === Enrichment: Frame Processing Pipeline ===
  /// Flag untuk mencegah penumpukan frame (buffer bloat).
  /// Jika true, frame baru akan di-skip sampai proses selesai.
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// Hasil deteksi terkini dalam koordinat normalisasi (0.0 - 1.0).
  List<DetectionResult> _currentResults = [];
  List<DetectionResult> get currentResults => _currentResults;

  /// Flag untuk mengontrol apakah streaming frame aktif.
  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  // === Task 1: Timer untuk mock detection setiap 3 detik ===
  Timer? _mockDetectionTimer;
  final Random _random = Random();

  // === Task 2: Torch & Overlay toggles ===
  /// Apakah lampu flash (torch) sedang menyala.
  bool _isTorchOn = false;
  bool get isTorchOn => _isTorchOn;

  /// Apakah overlay painter (lapisan deteksi) sedang ditampilkan.
  bool _isOverlayVisible = true;
  bool get isOverlayVisible => _isOverlayVisible;

  VisionController() {
    // Mendaftarkan observer agar bisa memantau status aplikasi (Lifecycle)
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  Future<void> initCamera() async {
    try {
      // === Task 3: Cek permission dulu sebelum inisialisasi ===
      final PermissionStatus cameraStatus = await Permission.camera.request();

      if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
        _isPermissionDenied = true;
        errorMessage = 'Izin kamera ditolak. Aplikasi membutuhkan akses kamera untuk mendeteksi kerusakan jalan.';
        notifyListeners();
        return;
      }

      _isPermissionDenied = false;

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        errorMessage = 'No camera detected on device.';
        notifyListeners();
        return;
      }

      // Memilih Kamera Belakang (Index 0)
      controller = CameraController(
        cameras[0],
        ResolutionPreset.medium, // Keseimbangan antara akurasi AI & performa
        enableAudio: false, // Kita hanya butuh visual untuk deteksi jalan
      );

      await controller!.initialize();
      isInitialized = true;
      errorMessage = null;

      // Mulai stream frame setelah kamera siap
      _startImageStream();

      // === Task 1: Mulai timer mock detection setiap 3 detik ===
      _startMockDetectionTimer();
    } on CameraException catch (e) {
      // === Task 3: Handle CameraException khusus permission ===
      if (e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.code == 'CameraAccessRestricted') {
        _isPermissionDenied = true;
        errorMessage = 'Izin kamera ditolak. Aplikasi membutuhkan akses kamera untuk mendeteksi kerusakan jalan.';
      } else {
        errorMessage = 'Failed to initialize camera: ${e.description}';
      }
    } catch (e) {
      errorMessage = 'Failed to initialize camera: $e';
    }
    notifyListeners();
  }

  // === Task 2: Toggle Torch (lampu flash) ===
  /// Menyalakan/mematikan lampu flash (torch) pada perangkat.
  Future<void> toggleTorch() async {
    if (controller == null || !controller!.value.isInitialized) return;

    try {
      if (_isTorchOn) {
        await controller!.setFlashMode(FlashMode.off);
      } else {
        await controller!.setFlashMode(FlashMode.torch);
      }
      _isTorchOn = !_isTorchOn;
      notifyListeners();
    } catch (e) {
      debugPrint('Torch toggle error: $e');
    }
  }

  // === Task 2: Toggle Overlay Painter ===
  /// Mengaktifkan/menonaktifkan lapisan Overlay Painter secara real-time.
  void toggleOverlay() {
    _isOverlayVisible = !_isOverlayVisible;
    notifyListeners();
  }

  // === Enrichment: Image Stream dengan Frame Dropping ===

  /// Memulai image stream dari kamera.
  /// Frame akan diproses secara asinkron dengan strategi frame-dropping.
  void _startImageStream() {
    if (controller == null || !controller!.value.isInitialized) return;

    _isStreaming = true;
    controller!.startImageStream((CameraImage image) {
      _processFrame(image);
    });
    notifyListeners();
  }

  /// Menghentikan image stream.
  Future<void> _stopImageStream() async {
    if (controller == null || !_isStreaming) return;

    try {
      await controller!.stopImageStream();
    } catch (_) {
      // Stream mungkin sudah berhenti
    }
    _isStreaming = false;
    notifyListeners();
  }

  // === Task 1: Mock Detection Timer ===
  /// Memulai timer yang memperbarui deteksi setiap 3 detik.
  /// Kotak deteksi berpindah ke titik acak di layar (simulasi output YOLO).
  void _startMockDetectionTimer() {
    _mockDetectionTimer?.cancel();
    _mockDetectionTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _generateRandomDetections(),
    );
    // Generate deteksi pertama langsung
    _generateRandomDetections();
  }

  /// Menghentikan timer mock detection.
  void _stopMockDetectionTimer() {
    _mockDetectionTimer?.cancel();
    _mockDetectionTimer = null;
  }

  /// Menghasilkan 1-3 deteksi acak dengan koordinat normalisasi (0.0-1.0).
  ///
  /// Task 1 — Scaling Calibration:
  /// Ukuran kotak proporsional terhadap lebar layar karena menggunakan
  /// koordinat normalisasi. Misal width=0.30 berarti 30% lebar layar,
  /// sehingga pada HP besar maupun kecil, kotak tetap terlihat proporsional.
  void _generateRandomDetections() {
    final List<String> damageTypes = ['D00', 'D10', 'D20', 'D40'];
    final int count = _random.nextInt(3) + 1; // 1 sampai 3 deteksi

    final List<DetectionResult> newResults = [];
    for (int i = 0; i < count; i++) {
      // Ukuran kotak proporsional: 15%-30% dari lebar/tinggi layar
      final double boxWidth = 0.15 + _random.nextDouble() * 0.15;
      final double boxHeight = 0.10 + _random.nextDouble() * 0.15;

      // Posisi acak memastikan kotak tidak keluar layar
      final double x = _random.nextDouble() * (1.0 - boxWidth);
      final double y = _random.nextDouble() * (1.0 - boxHeight);

      newResults.add(DetectionResult(
        box: ui.Rect.fromLTWH(x, y, boxWidth, boxHeight),
        label: damageTypes[_random.nextInt(damageTypes.length)],
        score: 0.60 + _random.nextDouble() * 0.39, // 60%-99%
      ));
    }

    _currentResults = newResults;
    notifyListeners();
  }

  /// Memproses satu frame dari kamera.
  ///
  /// Menerapkan strategi **Frame Dropping**:
  /// - Jika [_isProcessing] == true, frame baru langsung di-skip.
  /// - Ini mencegah buffer bloat dan menjaga UI tetap 60 FPS.
  ///
  /// Saat ini deteksi dikendalikan oleh timer (Task 1).
  /// Di Modul 7, bagian ini akan diganti dengan:
  /// ```dart
  /// final results = await compute(heavyInferenceTask, image);
  /// ```
  Future<void> _processFrame(CameraImage image) async {
    // Frame Dropping: Skip jika masih memproses frame sebelumnya
    if (_isProcessing) return;

    _isProcessing = true;

    try {
      // === PLACEHOLDER: Inference AI ===
      // Di Modul 7, baris ini akan diganti dengan:
      // final results = await compute(runYoloInference, image);
      //
      // Saat ini deteksi dihasilkan oleh _mockDetectionTimer (Task 1)
      // sehingga di sini kita hanya simulasi delay inference.
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      // Log error tanpa menghentikan stream
      debugPrint('Frame processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // === Capture: Untuk fitur Image Processing ===
  /// Hentikan stream & timer sebelum mengambil foto (takePicture).
  Future<void> prepareForCapture() async {
    await _stopImageStream();
    _stopMockDetectionTimer();
  }

  /// Lanjutkan stream & timer setelah selesai capture/proses.
  void resumeAfterCapture() {
    _startImageStream();
    _startMockDetectionTimer();
  }

  // === Task 1: Resource Guard — Auto-Dispose ===
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // Jika controller belum ada atau belum siap, abaikan
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Resource Guard: Matikan semua resource saat app ke background
      _stopMockDetectionTimer();
      _stopImageStream();

      // Matikan torch jika sedang nyala
      if (_isTorchOn) {
        _isTorchOn = false;
      }

      cameraController.dispose();
      isInitialized = false;
      _currentResults = [];
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      // Menginisialisasi ulang saat pengguna kembali ke aplikasi
      initCamera();
    }
  }

  @override
  void dispose() {
    // === Task 1: Resource Guard — Auto-Dispose saat tekan 'Back' ===
    // Menghapus observer agar tidak terjadi memory leak
    WidgetsBinding.instance.removeObserver(this);
    _stopMockDetectionTimer();
    _stopImageStream();
    controller?.dispose();
    super.dispose();
  }
}

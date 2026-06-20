import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:my_logbook_app/features/image_processing/image_processing_view.dart';
import 'package:my_logbook_app/features/vision/damage_painter.dart';
import 'package:my_logbook_app/features/vision/vision_controller.dart';

class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> {
  // Inisialisasi controller secara lokal untuk halaman ini
  late final VisionController _visionController;

  @override
  void initState() {
    super.initState();
    _visionController = VisionController();
  }

  @override
  void dispose() {
    // WAJIB: Memutus akses kamera saat pindah halaman (Task 1 — Resource Guard)
    _visionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart-Patrol Vision'),
        actions: [
          // Indikator status pipeline
          ListenableBuilder(
            listenable: _visionController,
            builder: (context, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status stream
                    Icon(
                      _visionController.isStreaming
                          ? Icons.videocam
                          : Icons.videocam_off,
                      color: _visionController.isStreaming
                          ? Colors.greenAccent
                          : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    // Jumlah deteksi
                    Text(
                      '${_visionController.currentResults.length} det',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _visionController,
        builder: (context, child) {
          // === Task 3: Tampilkan "No Camera Access" jika permission ditolak ===
          if (_visionController.isPermissionDenied) {
            return _buildPermissionDenied();
          }

          // Tampilkan error message jika ada (error non-permission)
          if (_visionController.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _visionController.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _visionController.initCamera(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // === Task 3: Loading kustom dengan teks instruksional ===
          if (!_visionController.isInitialized) {
            return _buildLoadingState();
          }

          // Lanjut ke struktur Stack
          return _buildVisionStack();
        },
      ),
    );
  }

  // === Task 3: Loading State yang Informatif ===
  /// Widget loading dengan CircularProgressIndicator yang dikustomisasi
  /// dan teks instruksional agar pengguna tahu proses yang sedang berjalan.
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated icon kamera
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: child,
                ),
              );
            },
            child: Icon(
              Icons.camera_alt_rounded,
              size: 60,
              color: Colors.blueAccent.withAlpha(178),
            ),
          ),
          const SizedBox(height: 24),
          // CircularProgressIndicator yang dikustomisasi
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.blueAccent.withAlpha(204),
              ),
              backgroundColor: Colors.blueAccent.withAlpha(38),
            ),
          ),
          const SizedBox(height: 20),
          // Teks instruksional utama
          const Text(
            'Menghubungkan ke Sensor Visual...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          // Sub-teks untuk konteks tambahan
          Text(
            'Mempersiapkan kamera untuk deteksi kerusakan jalan',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withAlpha(102),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // === Task 3: Permission Denied State ===
  /// Widget yang tampil ketika izin kamera ditolak.
  /// Menampilkan pesan informatif dan tombol "Open Settings".
  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ikon kamera dengan tanda silang
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_photography_rounded,
                size: 44,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 24),
            // Judul
            const Text(
              'No Camera Access',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            // Deskripsi
            Text(
              'Aplikasi membutuhkan akses kamera untuk melakukan deteksi kerusakan jalan secara real-time.\n\nBuka Settings untuk mengizinkan akses kamera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(153),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            // Tombol Open Settings
            ElevatedButton.icon(
              onPressed: () => openAppSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.settings_rounded),
              label: const Text(
                'Open Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Tombol Retry
            TextButton.icon(
              onPressed: () => _visionController.initCamera(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisionStack() {
    final CameraController camCtrl = _visionController.controller!;
    // Aspect ratio kamera sensor (misal 4:3 = 1.333)
    final double cameraAspectRatio = camCtrl.value.aspectRatio;

    return Column(
      children: [
        // === CAMERA PREVIEW (fixed, tidak stretch) ===
        Expanded(
          child: Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1 / cameraAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // LAYER 1: Camera Preview
                    ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: CameraPreview(camCtrl),
                    ),

                    // LAYER 2: Detection Overlay
                    if (_visionController.isOverlayVisible)
                      CustomPaint(
                        painter: DamagePainter(_visionController.currentResults),
                      ),

                    // LAYER 3: Control Buttons (kanan atas)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: _buildControlButtons(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // === BOTTOM BAR (fixed di bawah, bukan overlay) ===
        Container(
          color: const Color(0xFF1A1A2E),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Info deteksi
                Expanded(child: _buildDetectionInfo()),
                // Capture button
                GestureDetector(
                  onTap: _captureAndProcess,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_rounded,
                      color: Color(0xFF1A1A2E),
                      size: 26,
                    ),
                  ),
                ),
                // Spacer kanan agar capture button di tengah visual
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Info deteksi yang ditampilkan di bar bawah.
  Widget _buildDetectionInfo() {
    final results = _visionController.currentResults;
    if (results.isEmpty) {
      return const Text(
        'Scanning...',
        style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: results.map((res) {
          final Color chipColor = _getChipColor(res.label);
          return Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor.withAlpha(200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              res.displayLabel.trim(),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          );
        }).toList(),
      ),
    );
  }

  // === Task 2: Control Buttons ===
  /// Tombol kontrol untuk Torch dan Overlay toggle.
  Widget _buildControlButtons() {
    return Column(
      children: [
        // Tombol Toggle Torch (lampu flash)
        _buildCircleButton(
          icon: _visionController.isTorchOn
              ? Icons.flash_on_rounded
              : Icons.flash_off_rounded,
          isActive: _visionController.isTorchOn,
          onTap: () => _visionController.toggleTorch(),
          tooltip: 'Flash',
        ),
        const SizedBox(height: 12),
        // Tombol Toggle Overlay Painter
        _buildCircleButton(
          icon: _visionController.isOverlayVisible
              ? Icons.layers_rounded
              : Icons.layers_clear_rounded,
          isActive: _visionController.isOverlayVisible,
          onTap: () => _visionController.toggleOverlay(),
          tooltip: 'Overlay',
        ),
      ],
    );
  }

  /// Widget tombol lingkaran untuk kontrol hardware/UI.
  Widget _buildCircleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.blueAccent.withAlpha(204)
                : Colors.black.withAlpha(127),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withAlpha(51),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.white70,
            size: 22,
          ),
        ),
      ),
    );
  }

  // === Capture untuk Image Processing ===
  Future<void> _captureAndProcess() async {
    try {
      await _visionController.prepareForCapture();
      final photo = await _visionController.controller!.takePicture();
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageProcessingView(imagePath: photo.path),
          ),
        );
        // Resume streaming after returning
        _visionController.resumeAfterCapture();
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      _visionController.resumeAfterCapture();
    }
  }

  /// Warna chip berdasarkan tipe kerusakan (mirror dari DamagePainter)
  Color _getChipColor(String label) {
    switch (label) {
      case 'D40':
        return const Color(0xFFFF1744);
      case 'D20':
        return const Color(0xFFFF6D00);
      case 'D10':
        return const Color(0xFFFFAB00);
      case 'D00':
        return const Color(0xFFFFEA00);
      default:
        return const Color(0xFF00E5FF);
    }
  }
}

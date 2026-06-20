import 'dart:ui';

/// Data Transfer Object (DTO) untuk hasil deteksi kerusakan jalan.
///
/// Mengikuti prinsip Single Responsibility Principle (SRP):
/// - VisionController bertanggung jawab menghasilkan objek ini.
/// - DamagePainter hanya bertanggung jawab menggambarkannya.
///
/// Koordinat [box] menggunakan nilai normalisasi (0.0 - 1.0) agar
/// compatible di berbagai ukuran layar (Spatial Mapping / Scaling Factor).
class DetectionResult {
  /// Koordinat kotak deteksi dalam nilai normalisasi (0.0 - 1.0).
  /// Contoh: Rect(0.2, 0.3, 0.6, 0.7) berarti kotak dimulai dari
  /// 20% lebar layar, 30% tinggi layar, sampai 60% lebar, 70% tinggi.
  final Rect box;

  /// Tipe/label kerusakan berdasarkan standar RDD-2022.
  /// Contoh: 'D00' (Longitudinal Crack), 'D10' (Transverse Crack),
  /// 'D20' (Alligator Crack), 'D40' (Pothole).
  final String label;

  /// Persentase keyakinan AI (confidence score), range 0.0 - 1.0.
  final double score;

  DetectionResult({
    required this.box,
    required this.label,
    required this.score,
  });

  /// Mengembalikan label yang human-readable untuk ditampilkan di overlay.
  String get displayLabel {
    final Map<String, String> labelMap = {
      'D00': 'LONGITUDINAL CRACK',
      'D10': 'TRANSVERSE CRACK',
      'D20': 'ALLIGATOR CRACK',
      'D40': 'POTHOLE',
    };
    final String typeName = labelMap[label] ?? label;
    final int percent = (score * 100).round();
    return ' [$label] $typeName - $percent% ';
  }
}

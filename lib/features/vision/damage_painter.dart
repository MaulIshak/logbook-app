import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:my_logbook_app/features/vision/detection_result.dart';

/// Custom Painter untuk menggambar overlay deteksi kerusakan jalan.
///
/// Menerapkan prinsip dari materi pengayaan:
/// 1. **SRP** — Painter HANYA menggambar, tidak mendeteksi.
///    Data diterima sebagai [List<DetectionResult>] dari VisionController.
/// 2. **Scaling Factor** — Koordinat normalisasi (0.0-1.0) dari AI
///    di-mapping ke ukuran layar aktual menggunakan [size].
///
/// Task 4 — Detection Style & Color Branding:
/// - Warna dinamis berdasarkan severity: Merah (berat) → Kuning (ringan).
/// - Teks label dengan stroke/shadow agar terbaca di semua latar belakang.
///
/// Jika model YOLO diganti, file ini TIDAK perlu diubah.
class DamagePainter extends CustomPainter {
  /// Daftar hasil deteksi dari VisionController.
  final List<DetectionResult> results;

  DamagePainter(this.results);

  @override
  void paint(Canvas canvas, Size size) {
    for (final DetectionResult res in results) {
      // === Scaling Factor: Konversi Koordinat Normalisasi ke Piksel Layar ===
      // res.box berisi nilai 0.0-1.0 (ruang sensor/model AI)
      // size berisi ukuran layar HP aktual (logical pixels)
      final Rect scaledBox = Rect.fromLTWH(
        res.box.left * size.width,    // X: 0.25 * 360px = 90px
        res.box.top * size.height,    // Y: 0.30 * 640px = 192px
        res.box.width * size.width,   // W: 0.50 * 360px = 180px
        res.box.height * size.height, // H: 0.40 * 640px = 256px
      );

      // === Task 4: Warna dinamis berdasarkan severity ===
      final Color detectionColor = _getColorForLabel(res.label);

      // 1. Konfigurasi "Kuas" untuk kotak deteksi
      final Paint boxPaint = Paint()
        ..color = detectionColor
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      // 2. Gambar kotak deteksi yang sudah di-scale
      canvas.drawRect(scaledBox, boxPaint);

      // 3. Gambar background label + teks dengan efek stroke
      _drawLabel(canvas, scaledBox, res.displayLabel, detectionColor);

      // 4. Corner accents untuk visual yang lebih jelas
      _drawCornerAccents(canvas, scaledBox, boxPaint);
    }
  }

  // === Task 4: Skema Warna Dinamis ===
  /// Warna berdasarkan hierarki severity kerusakan jalan (RDD-2022).
  ///
  /// - D40 (Pothole) → **Merah** — kerusakan berat, prioritas tinggi.
  /// - D20 (Alligator Crack) → **Oranye Tua** — kerusakan sedang-berat.
  /// - D10 (Transverse Crack) → **Oranye** — kerusakan sedang.
  /// - D00 (Longitudinal Crack) → **Kuning** — kerusakan ringan.
  ///
  /// Petugas lapangan dapat langsung membedakan severity
  /// berdasarkan warna saat melakukan patroli.
  Color _getColorForLabel(String label) {
    switch (label) {
      case 'D40': // Pothole — kerusakan berat
        return const Color(0xFFFF1744); // Merah terang
      case 'D20': // Alligator Crack — kerusakan sedang-berat
        return const Color(0xFFFF6D00); // Oranye tua
      case 'D10': // Transverse Crack — kerusakan sedang
        return const Color(0xFFFFAB00); // Amber/oranye
      case 'D00': // Longitudinal Crack — kerusakan ringan
        return const Color(0xFFFFEA00); // Kuning terang
      default:
        return const Color(0xFF00E5FF); // Cyan untuk tipe tidak dikenal
    }
  }

  // === Task 4: Teks Label dengan Stroke/Shadow ===
  /// Menggambar label deteksi dengan efek stroke luar agar teks
  /// tetap terbaca jelas meskipun latar belakang jalan memiliki
  /// warna yang serupa dengan teks.
  ///
  /// Teknik: Double-paint (gambar stroke dulu, lalu fill di atasnya).
  void _drawLabel(Canvas canvas, Rect scaledBox, String labelText, Color color) {
    final double labelX = scaledBox.left;
    final double labelY = scaledBox.top;

    // --- Background semi-transparan untuk label ---
    final Paint bgPaint = Paint()
      ..color = color.withAlpha(180);

    // Ukur ukuran teks untuk menentukan ukuran background
    final ui.ParagraphBuilder measureBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    )..addText(labelText);
    final ui.Paragraph measureParagraph = measureBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));

    final double textWidth = measureParagraph.longestLine;
    final double textHeight = measureParagraph.height;

    final Rect bgRect = Rect.fromLTWH(
      labelX,
      labelY - textHeight - 8,
      textWidth + 12,
      textHeight + 8,
    );

    // Gambar background dengan rounded corners
    final RRect roundedBg = RRect.fromRectAndRadius(bgRect, const Radius.circular(4));
    canvas.drawRRect(roundedBg, bgPaint);

    // === Efek Shadow pada teks ===
    // Layer 1: Shadow gelap (offset ke bawah-kanan)
    final ui.ParagraphBuilder shadowBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    )..pushStyle(ui.TextStyle(
        color: const Color(0xCC000000), // Hitam semi-transparan
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ))
      ..addText(labelText);

    final ui.Paragraph shadowParagraph = shadowBuilder.build()
      ..layout(ui.ParagraphConstraints(width: bgRect.width));

    canvas.drawParagraph(
      shadowParagraph,
      Offset(labelX + 7, labelY - textHeight - 3),
    );

    // Layer 2: Stroke (outline hitam tebal)
    final ui.ParagraphBuilder strokeBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    )..pushStyle(ui.TextStyle(
        color: Colors.black,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        // Menggunakan foreground paint untuk stroke effect
      ))
      ..addText(labelText);

    final ui.Paragraph strokeParagraph = strokeBuilder.build()
      ..layout(ui.ParagraphConstraints(width: bgRect.width));

    // Gambar stroke di 4 arah untuk efek outline
    const double strokeOffset = 0.8;
    for (final Offset offset in [
      const Offset(-strokeOffset, 0),
      const Offset(strokeOffset, 0),
      const Offset(0, -strokeOffset),
      const Offset(0, strokeOffset),
    ]) {
      canvas.drawParagraph(
        strokeParagraph,
        Offset(labelX + 6 + offset.dx, labelY - textHeight - 4 + offset.dy),
      );
    }

    // Layer 3: Fill (teks putih utama di atas stroke)
    final ui.ParagraphBuilder fillBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    )..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ))
      ..addText(labelText);

    final ui.Paragraph fillParagraph = fillBuilder.build()
      ..layout(ui.ParagraphConstraints(width: bgRect.width));

    canvas.drawParagraph(
      fillParagraph,
      Offset(labelX + 6, labelY - textHeight - 4),
    );
  }

  /// Menggambar accent di sudut-sudut kotak agar lebih terlihat
  void _drawCornerAccents(Canvas canvas, Rect box, Paint paint) {
    final Paint accentPaint = Paint()
      ..color = paint.color
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double cornerLength = 16.0;

    // Top-left
    canvas.drawLine(
      box.topLeft,
      box.topLeft + const Offset(cornerLength, 0),
      accentPaint,
    );
    canvas.drawLine(
      box.topLeft,
      box.topLeft + const Offset(0, cornerLength),
      accentPaint,
    );

    // Top-right
    canvas.drawLine(
      box.topRight,
      box.topRight + const Offset(-cornerLength, 0),
      accentPaint,
    );
    canvas.drawLine(
      box.topRight,
      box.topRight + const Offset(0, cornerLength),
      accentPaint,
    );

    // Bottom-left
    canvas.drawLine(
      box.bottomLeft,
      box.bottomLeft + const Offset(cornerLength, 0),
      accentPaint,
    );
    canvas.drawLine(
      box.bottomLeft,
      box.bottomLeft + const Offset(0, -cornerLength),
      accentPaint,
    );

    // Bottom-right
    canvas.drawLine(
      box.bottomRight,
      box.bottomRight + const Offset(-cornerLength, 0),
      accentPaint,
    );
    canvas.drawLine(
      box.bottomRight,
      box.bottomRight + const Offset(0, -cornerLength),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant DamagePainter oldDelegate) {
    // Repaint setiap kali data deteksi berubah (reaktif terhadap stream frame)
    return oldDelegate.results != results;
  }
}

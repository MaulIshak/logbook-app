import 'dart:math';

import 'package:flutter/material.dart';

/// Custom Painter untuk menggambar grafik histogram citra (Light Mode).
///
/// Mendukung 1 channel (grayscale) atau 3 channel (RGB).
/// Histogram ditampilkan sebagai bar chart dengan 256 bins (0-255).
class HistogramPainter extends CustomPainter {
  /// Data histogram: 1 list untuk grayscale, 3 list untuk RGB [R, G, B].
  final List<List<int>> histograms;

  /// Warna untuk setiap channel histogram.
  final List<Color> colors;

  /// Judul yang ditampilkan di atas grafik.
  final String title;

  HistogramPainter({
    required this.histograms,
    required this.colors,
    this.title = 'Histogram',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double chartLeft = 40;
    final double chartTop = 28;
    final double chartRight = size.width - 12;
    final double chartBottom = size.height - 28;
    final double chartWidth = chartRight - chartLeft;
    final double chartHeight = chartBottom - chartTop;

    // Background chart area (light)
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ),
      bgPaint,
    );

    // Grid area background
    final gridBgPaint = Paint()..color = const Color(0xFFF8F9FA);
    canvas.drawRect(
      Rect.fromLTRB(chartLeft, chartTop, chartRight, chartBottom),
      gridBgPaint,
    );

    // Border around chart
    final borderPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTRB(chartLeft, chartTop, chartRight, chartBottom),
      borderPaint,
    );

    // Grid lines horizontal
    final gridPaint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      final y = chartTop + (chartHeight * i / 4);
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
    }

    // Grid lines vertical (64, 128, 192)
    for (int i = 1; i < 4; i++) {
      final x = chartLeft + (chartWidth * i / 4);
      canvas.drawLine(Offset(x, chartTop), Offset(x, chartBottom), gridPaint);
    }

    // Cari nilai maksimum untuk normalisasi
    int maxVal = 1;
    for (final hist in histograms) {
      for (final val in hist) {
        if (val > maxVal) maxVal = val;
      }
    }

    // Gambar setiap channel histogram
    final double barWidth = chartWidth / 256;
    for (int ch = 0; ch < histograms.length; ch++) {
      final hist = histograms[ch];
      final color = colors[ch];
      final barPaint = Paint()
        ..color = color.withAlpha(histograms.length > 1 ? 90 : 160)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 256; i++) {
        final double barHeight = (hist[i] / maxVal) * chartHeight;
        final double x = chartLeft + (i * barWidth);
        canvas.drawRect(
          Rect.fromLTWH(x, chartBottom - barHeight, max(barWidth, 1), barHeight),
          barPaint,
        );
      }

      // Envelope line
      if (histograms.length > 1) {
        final linePaint = Paint()
          ..color = color.withAlpha(220)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;

        final path = Path();
        for (int i = 0; i < 256; i++) {
          final double barHeight = (hist[i] / maxVal) * chartHeight;
          final double x = chartLeft + (i * barWidth) + barWidth / 2;
          final double y = chartBottom - barHeight;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, linePaint);
      }
    }

    // Axis labels (dark text for light mode)
    final labelStyle = TextStyle(
      color: Colors.grey.shade600,
      fontSize: 10,
    );

    // X-axis labels
    for (int i = 0; i <= 4; i++) {
      final val = (i * 64).clamp(0, 255);
      _drawText(
        canvas,
        val.toString(),
        Offset(chartLeft + (chartWidth * i / 4) - 8, chartBottom + 4),
        labelStyle,
      );
    }

    // Y-axis labels
    for (int i = 0; i <= 4; i++) {
      final val = ((4 - i) * maxVal / 4).round();
      final label = val > 999 ? '${(val / 1000).toStringAsFixed(1)}k' : '$val';
      _drawText(
        canvas,
        label,
        Offset(2, chartTop + (chartHeight * i / 4) - 6),
        labelStyle,
      );
    }

    // Judul
    _drawText(
      canvas,
      title,
      Offset(chartLeft, 4),
      TextStyle(
        color: Colors.grey.shade800,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant HistogramPainter oldDelegate) {
    return oldDelegate.histograms != histograms ||
        oldDelegate.title != title;
  }
}

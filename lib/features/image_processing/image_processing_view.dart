import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_logbook_app/features/image_processing/histogram_painter.dart';
import 'package:my_logbook_app/features/image_processing/image_processing_utils.dart';

/// Warna tema utama — biru konsisten di seluruh halaman.
const Color _kBlue = Color(0xFF2563EB);
const Color _kBlueDark = Color(0xFF1D4ED8);
const Color _kBlueLight = Color(0xFFDBEAFE);
const Color _kBlueBg = Color(0xFFF0F5FF);

/// Tinggi gambar standar agar semua gambar ukuran seragam.
const double _kImageHeight = 220.0;

class ImageProcessingView extends StatefulWidget {
  final String imagePath;
  const ImageProcessingView({super.key, required this.imagePath});

  @override
  State<ImageProcessingView> createState() => _ImageProcessingViewState();
}

class _ImageProcessingViewState extends State<ImageProcessingView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  Uint8List? _sourceBytes;
  bool _isLoading = true;
  bool _isFilterProcessing = false;

  // All display bytes
  Uint8List? _originalBytes, _grayscaleBytes, _inverseBytes;
  Uint8List? _addBytes, _subtractBytes, _multiplyBytes;
  Uint8List? _equalizedBytes, _matchedBytes, _referenceBytes;
  Uint8List? _noiseSPBytes, _noiseGaussBytes, _noisePeriodicBytes;
  Uint8List? _filterLowpassBytes, _filterHighpassBytes;
  Uint8List? _filterMedianBytes, _filterGaussianBytes, _filterMeanBytes;
  Uint8List? _fourierSpectrumBytes, _periodicNoisyBytes;

  // Histograms
  List<List<int>>? _rgbHist;
  List<int>? _grayHist;
  List<List<int>>? _beforeEqHist, _afterEqHist;
  List<int>? _beforeMatchHist, _afterMatchHist, _refHist;

  // Sliders
  double _addVal = 50, _subVal = 50, _mulFac = 1.5;

  // Filter source
  String _filterSource = 'Original';
  Uint8List? _currentFilterSourceBytes;

  final ImagePicker _picker = ImagePicker();

  static const List<String> _tabLabels = [
    'Gray', 'Arith', 'Inv', 'Hist', 'Equal', 'Match', 'Noise', 'Filter', 'Fourier',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabLabels.length, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      _sourceBytes = bytes; // Asumsi gambar sudah dikompresi standar
      _originalBytes = bytes;
      
      _grayscaleBytes = ImageProcessingUtils.toGrayscale(bytes);
      _inverseBytes = ImageProcessingUtils.inverse(bytes);
      _recomputeArith();

      _rgbHist = ImageProcessingUtils.computeRgbHistogram(bytes);
      _grayHist = ImageProcessingUtils.computeGrayscaleHistogram(bytes);
      _beforeEqHist = ImageProcessingUtils.computeRgbHistogram(bytes);
      final eq = ImageProcessingUtils.histogramEqualization(bytes);
      _equalizedBytes = eq;
      _afterEqHist = ImageProcessingUtils.computeRgbHistogram(eq);

      _noiseSPBytes = ImageProcessingUtils.noiseSaltAndPepper(bytes);
      _noiseGaussBytes = ImageProcessingUtils.noiseGaussian(bytes);
      final periodicNoisy = ImageProcessingUtils.noisePeriodic(bytes);
      _noisePeriodicBytes = periodicNoisy;
      _periodicNoisyBytes = periodicNoisy;

      _currentFilterSourceBytes = bytes;
      _computeFilters(bytes);

      // Fourier dft
      _fourierSpectrumBytes = ImageProcessingUtils.fourierMagnitudeSpectrum(periodicNoisy);
    } catch (e) {
      debugPrint('Load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _recomputeArith() {
    if (_sourceBytes == null) return;
    _addBytes = ImageProcessingUtils.arithmeticAdd(_sourceBytes!, _addVal.round());
    _subtractBytes = ImageProcessingUtils.arithmeticSubtract(_sourceBytes!, _subVal.round());
    _multiplyBytes = ImageProcessingUtils.arithmeticMultiply(_sourceBytes!, _mulFac);
  }

  void _computeFilters(Uint8List sourceBytes) {
    _filterLowpassBytes = ImageProcessingUtils.filterLowpass(sourceBytes);
    _filterHighpassBytes = ImageProcessingUtils.filterHighpass(sourceBytes);
    _filterMedianBytes = ImageProcessingUtils.filterMedian(sourceBytes);
    _filterGaussianBytes = ImageProcessingUtils.filterGaussian(sourceBytes);
    _filterMeanBytes = ImageProcessingUtils.filterMean(sourceBytes);
  }

  void _changeFilterSource(String label, Uint8List sourceBytes) {
    setState(() { _isFilterProcessing = true; _filterSource = label; _currentFilterSourceBytes = sourceBytes; });
    Future.delayed(const Duration(milliseconds: 30), () {
      _computeFilters(sourceBytes);
      if (mounted) setState(() => _isFilterProcessing = false);
    });
  }

  Future<void> _pickReference(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 480);
      if (picked == null) return;
      final bytes = await File(picked.path).readAsBytes();
      _referenceBytes = bytes;
      _beforeMatchHist = ImageProcessingUtils.computeGrayscaleHistogram(_sourceBytes!);
      _refHist = ImageProcessingUtils.computeGrayscaleHistogram(bytes);
      final matched = ImageProcessingUtils.histogramMatchingFromReference(_sourceBytes!, bytes);
      _matchedBytes = matched;
      _afterMatchHist = ImageProcessingUtils.computeGrayscaleHistogram(matched);
      if (mounted) setState(() {});
    } catch (e) { debugPrint('Pick error: $e'); }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBlueBg,
      appBar: AppBar(
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pengolahan Citra', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: _kBlue),
                  const SizedBox(height: 16),
                  Text('Memproses citra...', style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500,
                  )),
                  const SizedBox(height: 6),
                  Text('Menghitung semua operasi pengolahan', style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 12,
                  )),
                ],
              ),
            )
          : _sourceBytes == null
              ? const Center(child: Text('Gagal memuat gambar'))
              : Column(
                  children: [
                    // === FIXED ORIGINAL IMAGE ===
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Citra Original', style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: _kBlueDark,
                          )),
                          const SizedBox(height: 6),
                          _fixedImage(_originalBytes),
                        ],
                      ),
                    ),
                    // === TAB BAR ===
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabCtrl,
                        isScrollable: true,
                        labelColor: _kBlue,
                        unselectedLabelColor: Colors.grey.shade500,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                        indicatorColor: _kBlue,
                        indicatorWeight: 3,
                        tabAlignment: TabAlignment.start,
                        tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),
                    // === TAB VIEWS ===
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _tabGrayscale(),
                          _tabArithmetic(),
                          _tabInverse(),
                          _tabHistogram(),
                          _tabEqualization(),
                          _tabMatching(),
                          _tabNoise(),
                          _tabFilter(),
                          _tabFourier(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ==================== TABS ====================

  Widget _tabGrayscale() => _tabScroll([
    _sectionHeader('Konversi Grayscale'),
    _fixedImage(_grayscaleBytes),
  ]);

  Widget _tabArithmetic() => _tabScroll([
    _sectionHeader('Tambah (+${_addVal.round()})'),
    _fixedImage(_addBytes),
    _blueSlider(_addVal, 0, 200, (v) => setState(() { _addVal = v; _recomputeArith(); })),
    const SizedBox(height: 12),
    _sectionHeader('Kurang (−${_subVal.round()})'),
    _fixedImage(_subtractBytes),
    _blueSlider(_subVal, 0, 200, (v) => setState(() { _subVal = v; _recomputeArith(); })),
    const SizedBox(height: 12),
    _sectionHeader('Kali (×${_mulFac.toStringAsFixed(2)})'),
    _fixedImage(_multiplyBytes),
    _blueSlider(_mulFac, 0.1, 3.0, (v) => setState(() { _mulFac = v; _recomputeArith(); })),
  ]);

  Widget _tabInverse() => _tabScroll([
    _sectionHeader('Operasi Inverse (Negatif)'),
    _fixedImage(_inverseBytes),
  ]);

  Widget _tabHistogram() => _tabScroll([
    _sectionHeader('Histogram RGB (3 Channel)'),
    _histChart(_rgbHist!, [Colors.red, Colors.green, Colors.blue], 'RGB'),
    const SizedBox(height: 16),
    _sectionHeader('Histogram Grayscale (1 Channel)'),
    _histChart([_grayHist!], [Colors.grey.shade700], 'Grayscale'),
  ]);

  Widget _tabEqualization() => _tabScroll([
    _sectionHeader('Sebelum vs Sesudah'),
    _sideBySide(_originalBytes, 'Sebelum', _equalizedBytes, 'Sesudah'),
    const SizedBox(height: 12),
    _sectionHeader('Histogram Sebelum (RGB)'),
    _histChart(_beforeEqHist!, [Colors.red, Colors.green, Colors.blue], 'Sebelum'),
    const SizedBox(height: 8),
    _sectionHeader('Histogram Sesudah (RGB)'),
    _histChart(_afterEqHist!, [Colors.red, Colors.green, Colors.blue], 'Sesudah Equalization'),
  ]);

  Widget _tabMatching() => _tabScroll([
    _sectionHeader('Pilih Gambar Referensi'),
    Row(children: [
      Expanded(child: _blueBtn(Icons.camera_alt_rounded, 'Kamera', () => _pickReference(ImageSource.camera))),
      const SizedBox(width: 8),
      Expanded(child: _blueBtn(Icons.photo_library_rounded, 'Galeri', () => _pickReference(ImageSource.gallery))),
    ]),
    if (_referenceBytes != null) ...[
      const SizedBox(height: 14),
      _sectionHeader('Sumber vs Referensi vs Hasil'),
      Row(children: [
        Expanded(child: _labeledImg(_originalBytes, 'Sumber')),
        const SizedBox(width: 6),
        Expanded(child: _labeledImg(_referenceBytes, 'Referensi')),
        const SizedBox(width: 6),
        Expanded(child: _labeledImg(_matchedBytes, 'Hasil')),
      ]),
      if (_beforeMatchHist != null) ...[
        const SizedBox(height: 12),
        _histChart([_beforeMatchHist!], [Colors.orange.shade700], 'Sumber'),
        const SizedBox(height: 6),
        _histChart([_refHist!], [Colors.purple], 'Referensi'),
        const SizedBox(height: 6),
        _histChart([_afterMatchHist!], [_kBlue], 'Hasil Matching'),
      ],
    ],
  ]);

  Widget _tabNoise() => _tabScroll([
    _sectionHeader('Salt & Pepper Noise'),
    _fixedImage(_noiseSPBytes),
    const SizedBox(height: 14),
    _sectionHeader('Gaussian Noise'),
    _fixedImage(_noiseGaussBytes),
    const SizedBox(height: 14),
    _sectionHeader('Periodic Noise'),
    _fixedImage(_noisePeriodicBytes),
  ]);

  Widget _tabFilter() => _tabScroll([
    _sectionHeader('Sumber Filter'),
    _buildFilterChips(),
    const SizedBox(height: 10),
    if (_isFilterProcessing)
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBlueLight),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(color: _kBlue, strokeWidth: 2.5),
            const SizedBox(height: 12),
            Text('Menerapkan filter pada $_filterSource...', style: TextStyle(
              color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500,
            )),
          ],
        ),
      )
    else ...[
      _sectionHeader('Lowpass (Smoothing)'),
      _fixedImage(_filterLowpassBytes),
      const SizedBox(height: 14),
      _sectionHeader('Highpass (Edge Detection)'),
      _fixedImage(_filterHighpassBytes),
      const SizedBox(height: 14),
      _sectionHeader('Median (Noise Reduction)'),
      _fixedImage(_filterMedianBytes),
      const SizedBox(height: 14),
      _sectionHeader('Gaussian (Smooth Blur)'),
      _fixedImage(_filterGaussianBytes),
      const SizedBox(height: 14),
      _sectionHeader('Mean (Average)'),
      _fixedImage(_filterMeanBytes),
    ],
  ]);

  Widget _tabFourier() => _tabScroll([
    _sectionHeader('Periodic Noise → Fourier Spectrum'),
    _sideBySide(_periodicNoisyBytes, 'Periodic Noise', _fourierSpectrumBytes, 'Magnitude Spectrum'),
  ]);

  // ==================== REUSABLE WIDGETS ====================

  Widget _tabScroll(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text, style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700, color: _kBlueDark,
      )),
    );
  }

  /// Gambar dengan ukuran tetap dan seragam.
  Widget _fixedImage(Uint8List? bytes) {
    return Container(
      height: _kImageHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBlueLight, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true)
            : const Center(child: Icon(Icons.image, color: Colors.grey, size: 32)),
      ),
    );
  }

  /// Dua gambar side-by-side dengan ukuran yang sama.
  Widget _sideBySide(Uint8List? left, String leftLabel, Uint8List? right, String rightLabel) {
    return Row(
      children: [
        Expanded(child: _labeledImg(left, leftLabel)),
        const SizedBox(width: 8),
        Expanded(child: _labeledImg(right, rightLabel)),
      ],
    );
  }

  /// Gambar dengan label, ukuran proporsional dan seragam.
  Widget _labeledImg(Uint8List? bytes, String label) {
    return Column(
      children: [
        Container(
          height: _kImageHeight * 0.7,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBlueLight, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true)
                : const Center(child: Icon(Icons.image, color: Colors.grey)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _blueSlider(double value, double mn, double mx, ValueChanged<double> onChanged) {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: _kBlue,
        inactiveTrackColor: _kBlueLight,
        thumbColor: _kBlue,
        overlayColor: _kBlue.withAlpha(25),
        trackHeight: 3,
      ),
      child: Slider(value: value, min: mn, max: mx, onChanged: onChanged),
    );
  }

  Widget _histChart(List<List<int>> data, List<Color> colors, String title) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 175,
        child: CustomPaint(
          size: const Size(double.infinity, 175),
          painter: HistogramPainter(histograms: data, colors: colors, title: title),
        ),
      ),
    );
  }

  Widget _blueBtn(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: _kBlueLight,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: _kBlue),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: _kBlueDark, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== FILTER CHIPS ====================

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _chip('Original', () => _changeFilterSource('Original', _sourceBytes!)),
        _chip('Salt & Pepper', () => _changeFilterSource('Salt & Pepper', ImageProcessingUtils.noiseSaltAndPepper(_sourceBytes!))),
        _chip('Gaussian', () => _changeFilterSource('Gaussian', ImageProcessingUtils.noiseGaussian(_sourceBytes!))),
        _chip('Periodic', () => _changeFilterSource('Periodic', ImageProcessingUtils.noisePeriodic(_sourceBytes!))),
      ],
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    final bool active = _filterSource == label;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _kBlue : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: active ? Colors.white : Colors.grey.shade700,
        )),
      ),
    );
  }
}

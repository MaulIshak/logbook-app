import 'dart:math' show Random;
import 'dart:typed_data';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Utility class untuk pengolahan citra menggunakan OpenCV (native performance).
/// Semua input dan output adalah Uint8List (representasi byte JPG).
class ImageProcessingUtils {
  static cv.Mat _decode(Uint8List bytes) => cv.imdecode(bytes, cv.IMREAD_COLOR);
  static cv.Mat _decodeGray(Uint8List bytes) =>
      cv.imdecode(bytes, cv.IMREAD_GRAYSCALE);
  static Uint8List _encode(cv.Mat mat) => cv.imencode('.jpg', mat).$2;

  // ==================== 1. GRAYSCALE ====================

  static Uint8List toGrayscale(Uint8List sourceBytes) {
    final mat = _decode(sourceBytes);
    final gray = cv.cvtColor(mat, cv.COLOR_BGR2GRAY);
    return _encode(gray);
  }

  // ==================== 2. ARITMETIKA ====================

  // Menggunakan manipulasi memori langsung untuk aritmetika sederhana agar aman tanpa ribet tipe scalar OpenCV
  static Uint8List arithmeticAdd(Uint8List sourceBytes, int value) {
    final mat = _decode(sourceBytes);
    final data = mat.data;
    for (int i = 0; i < data.length; i++) {
      data[i] = (data[i] + value).clamp(0, 255);
    }
    return _encode(mat);
  }

  static Uint8List arithmeticSubtract(Uint8List sourceBytes, int value) {
    final mat = _decode(sourceBytes);
    final data = mat.data;
    for (int i = 0; i < data.length; i++) {
      data[i] = (data[i] - value).clamp(0, 255);
    }
    return _encode(mat);
  }

  static Uint8List arithmeticMultiply(Uint8List sourceBytes, double factor) {
    final mat = _decode(sourceBytes);
    final data = mat.data;
    for (int i = 0; i < data.length; i++) {
      data[i] = (data[i] * factor).round().clamp(0, 255);
    }
    return _encode(mat);
  }

  // ==================== 3. INVERSE ====================

  static Uint8List inverse(Uint8List sourceBytes) {
    final mat = _decode(sourceBytes);
    final inv = cv.bitwiseNOT(mat);
    return _encode(inv);
  }

  // ==================== 4. HISTOGRAM ====================

  static List<int> computeGrayscaleHistogram(Uint8List sourceBytes) {
    final gray = _decodeGray(sourceBytes);
    final vecMat = cv.VecMat.fromList([gray]);
    final channels = cv.VecI32.fromList([0]);
    final histSize = cv.VecI32.fromList([256]);
    final ranges = cv.VecF32.fromList([0.0, 256.0]);

    final hist = cv.calcHist(
      vecMat,
      channels,
      cv.Mat.empty(),
      histSize,
      ranges,
    );
    final f32Data = hist.data.buffer.asFloat32List();
    return f32Data.map((e) => e.round()).toList();
  }

  static List<List<int>> computeRgbHistogram(Uint8List sourceBytes) {
    final mat = _decode(sourceBytes);
    final vecMat = cv.VecMat.fromList([mat]);
    final histSize = cv.VecI32.fromList([256]);
    final ranges = cv.VecF32.fromList([0.0, 256.0]);

    // OpenCV BGR order
    final bHist = cv.calcHist(
      vecMat,
      cv.VecI32.fromList([0]),
      cv.Mat.empty(),
      histSize,
      ranges,
    );
    final gHist = cv.calcHist(
      vecMat,
      cv.VecI32.fromList([1]),
      cv.Mat.empty(),
      histSize,
      ranges,
    );
    final rHist = cv.calcHist(
      vecMat,
      cv.VecI32.fromList([2]),
      cv.Mat.empty(),
      histSize,
      ranges,
    );

    return [
      rHist.data.buffer.asFloat32List().map((e) => e.round()).toList(),
      gHist.data.buffer.asFloat32List().map((e) => e.round()).toList(),
      bHist.data.buffer.asFloat32List().map((e) => e.round()).toList(),
    ];
  }

  // ==================== 5. HISTOGRAM EQUALIZATION ====================

  static Uint8List histogramEqualization(Uint8List sourceBytes) {
    final mat = _decode(sourceBytes);
    // 1. Ubah ke YCrCb
    final ycrcb = cv.cvtColor(mat, cv.COLOR_BGR2YCrCb);
    // 2. Split channel (Y, Cr, Cb)
    final channels = cv.split(ycrcb);
    // 3. Equalize channel Y (index 0)
    final yEq = cv.equalizeHist(channels[0]);
    channels[0] = yEq;
    // 4. Merge kembali
    final merged = cv.merge(channels);
    // 5. Convert kembali ke BGR
    final result = cv.cvtColor(merged, cv.COLOR_YCrCb2BGR);
    return _encode(result);
  }

  // ==================== 6. HISTOGRAM MATCHING ====================

  static Uint8List histogramMatchingFromReference(
    Uint8List sourceBytes,
    Uint8List refBytes,
  ) {
    // Kita gunakan teknik mapping manual karena OpenCV C++ tidak punya fungsi `matchHist` standar
    final srcGray = _decodeGray(sourceBytes);
    final refGray = _decodeGray(refBytes);

    final srcHistF = cv
        .calcHist(
          cv.VecMat.fromList([srcGray]),
          cv.VecI32.fromList([0]),
          cv.Mat.empty(),
          cv.VecI32.fromList([256]),
          cv.VecF32.fromList([0.0, 256.0]),
        )
        .data
        .buffer
        .asFloat32List();
    final refHistF = cv
        .calcHist(
          cv.VecMat.fromList([refGray]),
          cv.VecI32.fromList([0]),
          cv.Mat.empty(),
          cv.VecI32.fromList([256]),
          cv.VecF32.fromList([0.0, 256.0]),
        )
        .data
        .buffer
        .asFloat32List();

    int srcTotal = srcGray.rows * srcGray.cols;
    int refTotal = refGray.rows * refGray.cols;

    final srcCdf = List<double>.filled(256, 0);
    final refCdf = List<double>.filled(256, 0);

    srcCdf[0] = srcHistF[0] / srcTotal;
    refCdf[0] = refHistF[0] / refTotal;
    for (int i = 1; i < 256; i++) {
      srcCdf[i] = srcCdf[i - 1] + srcHistF[i] / srcTotal;
      refCdf[i] = refCdf[i - 1] + refHistF[i] / refTotal;
    }

    final mapping = List<int>.filled(256, 0);
    for (int r = 0; r < 256; r++) {
      int bestZ = 0;
      double bestDiff = double.infinity;
      for (int z = 0; z < 256; z++) {
        final double diff = (refCdf[z] - srcCdf[r]).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          bestZ = z;
        }
      }
      mapping[r] = bestZ;
    }

    // Apply mapping
    final srcData = srcGray.data;
    for (int i = 0; i < srcData.length; i++) {
      srcData[i] = mapping[srcData[i]];
    }

    return _encode(srcGray);
  }

  // ==================== 7. NOISE ====================

  static Uint8List noiseSaltAndPepper(
    Uint8List sourceBytes, {
    double amount = 0.05,
  }) {
    final mat = _decode(sourceBytes);
    final data = mat.data;
    final int total = (data.length / 3 * amount).round();
    final rng = Random(); // from dart:math
    for (int i = 0; i < total; i++) {
      final int row = rng.nextInt(mat.rows);
      final int col = rng.nextInt(mat.cols);
      final int val = rng.nextInt(2) == 0 ? 0 : 255;
      final int idx = (row * mat.cols + col) * 3;
      data[idx] = val;
      data[idx + 1] = val;
      data[idx + 2] = val;
    }
    return _encode(mat);
  }

  static Uint8List noiseGaussian(Uint8List sourceBytes, {double sigma = 25}) {
    final mat = _decode(sourceBytes);
    // Buat noise dengan mean 0 dan standard deviation = sigma
    final noise = cv.Mat.zeros(mat.rows, mat.cols, mat.type);
    cv.randn(noise, cv.Scalar(0, 0, 0, 0), cv.Scalar(sigma, sigma, sigma, 0));
    final noisy = cv.add(mat, noise);
    return _encode(noisy);
  }

  static Uint8List noisePeriodic(
    Uint8List sourceBytes, {
    int stripeWidth = 8,
    int spacing = 40,
  }) {
    final mat = _decode(sourceBytes);
    final data = mat.data;
    final int period = stripeWidth + spacing;
    final int cols = mat.cols;

    for (int y = 0; y < mat.rows; y++) {
      for (int x = 0; x < cols; x++) {
        if ((x + y) % period < stripeWidth) {
          final int idx = (y * cols + x) * 3;
          data[idx] = (data[idx] * 0.2).round().clamp(0, 255);
          data[idx + 1] = (data[idx + 1] * 0.2).round().clamp(0, 255);
          data[idx + 2] = (data[idx + 2] * 0.2).round().clamp(0, 255);
        }
      }
    }
    return _encode(mat);
  }

  // ==================== 8. FILTER ====================

  static Uint8List filterLowpass(Uint8List sourceBytes) {
    final mat = _decode(sourceBytes);
    // Lowpass = Blur standard
    final blur = cv.blur(mat, (3, 3));
    return _encode(blur);
  }

  static Uint8List filterHighpass(Uint8List sourceBytes) {
    final mat = _decode(sourceBytes);
    // Laplacian edge detection, depth is CV_8U (which is 0)
    final laplacian = cv.laplacian(mat, 0);
    return _encode(laplacian);
  }

  static Uint8List filterMedian(Uint8List sourceBytes) {
    final mat = _decode(sourceBytes);
    final median = cv.medianBlur(mat, 3);
    return _encode(median);
  }

  static Uint8List filterGaussian(Uint8List sourceBytes) {
    final mat = _decode(sourceBytes);
    final gaussian = cv.gaussianBlur(mat, (5, 5), 1.0);
    return _encode(gaussian);
  }

  static Uint8List filterMean(Uint8List sourceBytes) {
    return filterLowpass(sourceBytes);
  }

  // ==================== 9. FOURIER ====================

  static Uint8List fourierMagnitudeSpectrum(Uint8List sourceBytes) {
    final mat = _decode(sourceBytes);
    final gray = cv.cvtColor(mat, cv.COLOR_BGR2GRAY);

    // get optimal dft size
    int m = cv.getOptimalDFTSize(gray.rows);
    int n = cv.getOptimalDFTSize(gray.cols);
    final padded = cv.copyMakeBorder(
      gray,
      0,
      m - gray.rows,
      0,
      n - gray.cols,
      cv.BORDER_CONSTANT,
    );

    // convert to float
    final floatMat = padded.convertTo(cv.MatType.CV_32FC1);

    // perform dft
    final dft = cv.dft(floatMat, flags: cv.DFT_COMPLEX_OUTPUT);

    // split and magnitude
    final planes = cv.split(dft);
    final mag = cv.magnitude(planes[0], planes[1]);

    // mag += 1
    final ones = cv.Mat.ones(mag.rows, mag.cols, cv.MatType.CV_32FC1);
    var logMag = cv.add(mag, ones);
    cv.log(logMag, dst: logMag);

    // shift quadrants
    int cx = logMag.cols ~/ 2;
    int cy = logMag.rows ~/ 2;
    final q0 = logMag.region(cv.Rect(0, 0, cx, cy));
    final q1 = logMag.region(cv.Rect(cx, 0, cx, cy));
    final q2 = logMag.region(cv.Rect(0, cy, cx, cy));
    final q3 = logMag.region(cv.Rect(cx, cy, cx, cy));

    final tmp = cv.Mat.empty();
    q0.copyTo(tmp);
    q3.copyTo(q0);
    tmp.copyTo(q3);

    q1.copyTo(tmp);
    q2.copyTo(q1);
    tmp.copyTo(q2);

    // normalize 0-255
    final norm = cv.normalize(
      logMag,
      logMag,
      alpha: 0,
      beta: 255,
      normType: cv.NORM_MINMAX,
    );
    final result = norm.convertTo(cv.MatType.CV_8UC1);

    return _encode(result);
  }
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:wcag_vision/src/cvd/cvd_type.dart';

// ---------------------------------------------------------------------------
// Transform matrices
//
// Source: G. M. Machado, M. M. Oliveira and M. D. Fairchild,
// "A Physiologically-based Model for Simulation of Color Vision Deficiency",
// IEEE Transactions on Visualization and Computer Graphics, 15(6),
// pp. 1291-1298, 2009. <https://doi.org/10.1109/TVCG.2009.113>
//
// These are the paper's published RGB->RGB matrices at severity 1.0 (full
// dichromacy), stored row-major. They are defined in *linear* RGB, so inputs
// are decoded from gamma-encoded sRGB before the multiply and re-encoded
// after (see simulateCvd). Each row sums to 1.0, which is what makes
// achromatic (grey) colours invariant under all three transforms.
// ---------------------------------------------------------------------------

/// Machado et al. (2009) protanopia matrix, severity 1.0, row-major.
const List<double> _protanopia = [
  0.152286, 1.052583, -0.204868, //
  0.114503, 0.786281, 0.099216, //
  -0.003882, -0.048116, 1.051998,
];

/// Machado et al. (2009) deuteranopia matrix, severity 1.0, row-major.
const List<double> _deuteranopia = [
  0.367322, 0.860646, -0.227968, //
  0.280085, 0.672501, 0.047413, //
  -0.011820, 0.042940, 0.968881,
];

/// Machado et al. (2009) tritanopia matrix, severity 1.0, row-major.
const List<double> _tritanopia = [
  1.255528, -0.076749, -0.178779, //
  -0.078411, 0.930809, 0.147602, //
  0.004733, 0.691367, 0.303900,
];

/// Simulates how [color] is perceived by a viewer with the given colour
/// vision deficiency [type], returning the simulated colour.
///
/// Uses the physiologically-based model of Machado, Oliveira & Fairchild
/// (2009) at full severity — see the citation on the matrix constants in
/// this library. The pipeline is:
///
/// 1. decode the gamma-encoded sRGB channels to linear RGB,
/// 2. multiply by the deficiency matrix (defined in linear space),
/// 3. clamp to `[0, 1]` and re-encode to sRGB.
///
/// Properties that follow from the model:
///
/// * [CvdType.none] is the identity — the input is returned unchanged.
/// * Achromatic colours (black, white, greys) are invariant under every
///   deficiency type, because each matrix row sums to 1.
/// * The alpha channel is preserved untouched; simulation applies to the
///   colour components only.
///
/// The sRGB decode/encode here uses the official sRGB transfer function
/// (IEC 61966-2-1, thresholds 0.04045 / 0.0031308). This intentionally
/// differs from `relativeLuminance` in the contrast module, which follows
/// WCAG 2.x's own published variant of the formula.
Color simulateCvd(Color color, CvdType type) {
  final m = switch (type) {
    CvdType.none => null,
    CvdType.protanopia => _protanopia,
    CvdType.deuteranopia => _deuteranopia,
    CvdType.tritanopia => _tritanopia,
  };
  if (m == null) return color;

  final r = _srgbDecode(color.r);
  final g = _srgbDecode(color.g);
  final b = _srgbDecode(color.b);

  final simR = clampDouble(m[0] * r + m[1] * g + m[2] * b, 0, 1);
  final simG = clampDouble(m[3] * r + m[4] * g + m[5] * b, 0, 1);
  final simB = clampDouble(m[6] * r + m[7] * g + m[8] * b, 0, 1);

  return Color.from(
    alpha: color.a,
    red: _srgbEncode(simR),
    green: _srgbEncode(simG),
    blue: _srgbEncode(simB),
  );
}

/// Decodes a gamma-encoded sRGB [channel] in `[0, 1]` to linear light,
/// per IEC 61966-2-1.
double _srgbDecode(double channel) {
  if (channel <= 0.04045) {
    return channel / 12.92;
  }
  return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

/// Encodes a linear-light [channel] in `[0, 1]` back to gamma-encoded sRGB,
/// per IEC 61966-2-1.
double _srgbEncode(double channel) {
  if (channel <= 0.0031308) {
    return channel * 12.92;
  }
  return 1.055 * math.pow(channel, 1 / 2.4).toDouble() - 0.055;
}

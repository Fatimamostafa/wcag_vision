import 'dart:math' as math;
import 'dart:ui';

/// The sRGB companding threshold below which the transfer function is linear,
/// as specified by WCAG 2.x. (The sRGB standard itself uses 0.04045; WCAG's
/// published formula uses this slightly different value, so we match WCAG.)
const double _srgbLinearThreshold = 0.03928;

/// Computes the WCAG 2.x relative luminance of an opaque [color].
///
/// Relative luminance is the perceived brightness of a colour, normalised so
/// that pure black is `0.0` and pure white is `1.0`. It is the basis of the
/// contrast-ratio calculation (see `contrastRatio`).
///
/// The alpha channel of [color] is **ignored**: relative luminance is only
/// meaningful for an opaque colour. If [color] is semi-transparent, composite
/// it onto an opaque background first with `compositeOver`.
///
/// Reference:
/// <https://www.w3.org/TR/WCAG21/#dfn-relative-luminance>.
double relativeLuminance(Color color) {
  final r = _linearizeChannel(color.r);
  final g = _linearizeChannel(color.g);
  final b = _linearizeChannel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Converts a single gamma-encoded sRGB [channel] value in the range `[0, 1]`
/// into its linear-light equivalent, per the WCAG transfer function.
double _linearizeChannel(double channel) {
  if (channel <= _srgbLinearThreshold) {
    return channel / 12.92;
  }
  return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

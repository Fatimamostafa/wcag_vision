import 'dart:math' as math;
import 'dart:ui';

import 'package:wcag_vision/src/contrast/color_compositing.dart';
import 'package:wcag_vision/src/contrast/relative_luminance.dart';

/// The lowest possible WCAG contrast ratio: `1.0`, when both colours share the
/// same relative luminance.
const double minContrastRatio = 1;

/// The highest possible WCAG contrast ratio: `21.0`, i.e. pure black on pure
/// white (or vice versa).
const double maxContrastRatio = 21;

/// Computes the WCAG 2.x contrast ratio between two **opaque** colours.
///
/// The result lies in the range `[1.0, 21.0]`, where `1.0` means the colours
/// are indistinguishable in luminance and `21.0` is the maximum (black vs
/// white). The calculation is symmetric — argument order does not matter.
///
/// Alpha is ignored. If either colour may be translucent, use
/// `contrastRatioOver` instead, which flattens the foreground first.
///
/// Reference:
/// <https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio>.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Computes the WCAG contrast ratio of a possibly semi-transparent
/// [foreground] against an opaque [background].
///
/// The [foreground] is first alpha-composited over [background] (see
/// `compositeOver`), then the contrast between that flattened colour and the
/// background is measured. This is the correct treatment for translucent text
/// or overlays, where the effective foreground colour depends on what shows
/// through it.
///
/// [background] is expected to be opaque; if it is not, its own alpha is
/// carried through the composite and the resulting ratio should be treated as
/// indicative only.
double contrastRatioOver(Color foreground, Color background) {
  final effectiveForeground = compositeOver(foreground, background);
  return contrastRatio(effectiveForeground, background);
}

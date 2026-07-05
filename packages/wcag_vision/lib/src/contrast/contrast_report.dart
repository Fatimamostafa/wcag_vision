import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:wcag_vision/src/contrast/contrast_ratio.dart';
import 'package:wcag_vision/src/contrast/wcag_thresholds.dart';

/// The result of evaluating a foreground/background colour pair against the
/// WCAG 2.x contrast requirements.
///
/// Obtain one via `evaluateContrast`. The [ratio] is the raw contrast ratio;
/// the pass getters and [passes] interpret it against the WCAG thresholds.
@immutable
class ContrastReport {
  /// Creates a report for a pre-computed contrast [ratio] in `[1.0, 21.0]`.
  const ContrastReport({required this.ratio});

  /// The WCAG contrast ratio between the two colours, in `[1.0, 21.0]`.
  final double ratio;

  /// Whether [ratio] meets the requirement for the given [level] and [size].
  bool passes(WcagConformanceLevel level, WcagTextSize size) =>
      ratio >= wcagThreshold(level, size);

  /// Whether the pair passes AA for normal-size text (ratio >= 4.5).
  bool get passesAaNormal =>
      passes(WcagConformanceLevel.aa, WcagTextSize.normal);

  /// Whether the pair passes AA for large text (ratio >= 3.0).
  bool get passesAaLarge => passes(WcagConformanceLevel.aa, WcagTextSize.large);

  /// Whether the pair passes AAA for normal-size text (ratio >= 7.0).
  bool get passesAaaNormal =>
      passes(WcagConformanceLevel.aaa, WcagTextSize.normal);

  /// Whether the pair passes AAA for large text (ratio >= 4.5).
  bool get passesAaaLarge =>
      passes(WcagConformanceLevel.aaa, WcagTextSize.large);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContrastReport && other.ratio == ratio;

  @override
  int get hashCode => ratio.hashCode;

  @override
  String toString() => 'ContrastReport(ratio: ${ratio.toStringAsFixed(2)})';
}

/// Evaluates the WCAG contrast between a [foreground] and [background] colour,
/// returning a [ContrastReport].
///
/// A possibly semi-transparent [foreground] is alpha-composited over
/// [background] first (see `contrastRatioOver`), so translucent colours are
/// handled correctly. [background] is expected to be opaque.
ContrastReport evaluateContrast(Color foreground, Color background) =>
    ContrastReport(ratio: contrastRatioOver(foreground, background));

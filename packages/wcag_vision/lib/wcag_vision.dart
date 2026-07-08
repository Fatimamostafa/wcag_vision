/// wcag_vision — an offline, algorithmic WCAG accessibility engine.
///
/// A pure-Dart package with no Flutter dependency: it runs anywhere Dart
/// runs (CLI, server, web, and Flutter). Colours are represented with the
/// package's own [WcagColor] rather than `dart:ui`'s `Color` — converting
/// to and from Flutter's `Color` at your app's UI boundary is a one-line,
/// lossless operation (see [WcagColor]'s dartdoc).
///
/// Modules:
///
/// * **Contrast** — relative luminance, WCAG 2.x contrast ratios, alpha
///   compositing for translucent colours, and AA/AAA conformance evaluation.
/// * **CVD simulation** — colour-vision-deficiency simulation (protanopia,
///   deuteranopia, tritanopia) using the Machado, Oliveira & Fairchild
///   (2009) physiologically-based model.
/// * **Colour extraction** — dominant-colour extraction via k-means
///   clustering with deterministic k-means++ seeding, designed for
///   one-shot analysis of a single captured frame.
library;

import 'package:wcag_vision/src/color/wcag_color.dart';

export 'src/color/wcag_color.dart' show WcagColor;
export 'src/color_extraction/extracted_color.dart';
export 'src/color_extraction/k_means_extraction.dart';
export 'src/contrast/color_compositing.dart';
export 'src/contrast/contrast_ratio.dart';
export 'src/contrast/contrast_report.dart';
export 'src/contrast/relative_luminance.dart';
export 'src/contrast/wcag_thresholds.dart';
export 'src/cvd/cvd_simulation.dart';
export 'src/cvd/cvd_type.dart';

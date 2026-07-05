/// wcag_vision — an offline, algorithmic WCAG accessibility engine.
///
/// Modules:
///
/// * **Contrast** — relative luminance, WCAG 2.x contrast ratios, alpha
///   compositing for translucent colours, and AA/AAA conformance evaluation.
/// * **CVD simulation** — colour-vision-deficiency simulation (protanopia,
///   deuteranopia, tritanopia) using the Machado, Oliveira & Fairchild
///   (2009) physiologically-based model.
///
/// K-means colour extraction will be added as a separate module.
library;

export 'src/contrast/color_compositing.dart';
export 'src/contrast/contrast_ratio.dart';
export 'src/contrast/contrast_report.dart';
export 'src/contrast/relative_luminance.dart';
export 'src/contrast/wcag_thresholds.dart';
export 'src/cvd/cvd_simulation.dart';
export 'src/cvd/cvd_type.dart';

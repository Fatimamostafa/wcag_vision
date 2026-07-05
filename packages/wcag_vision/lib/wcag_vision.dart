/// wcag_vision — an offline, algorithmic WCAG accessibility engine.
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

export 'src/color_extraction/extracted_color.dart';
export 'src/color_extraction/k_means_extraction.dart';
export 'src/contrast/color_compositing.dart';
export 'src/contrast/contrast_ratio.dart';
export 'src/contrast/contrast_report.dart';
export 'src/contrast/relative_luminance.dart';
export 'src/contrast/wcag_thresholds.dart';
export 'src/cvd/cvd_simulation.dart';
export 'src/cvd/cvd_type.dart';

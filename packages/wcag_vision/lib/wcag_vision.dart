/// wcag_vision — an offline, algorithmic WCAG accessibility engine.
///
/// This library currently exposes the **colour contrast** module: relative
/// luminance, WCAG 2.x contrast ratios, alpha compositing for translucent
/// colours, and AA/AAA conformance evaluation. CVD simulation and k-means
/// colour extraction will be added as separate modules.
library;

export 'src/contrast/color_compositing.dart';
export 'src/contrast/contrast_ratio.dart';
export 'src/contrast/contrast_report.dart';
export 'src/contrast/relative_luminance.dart';
export 'src/contrast/wcag_thresholds.dart';

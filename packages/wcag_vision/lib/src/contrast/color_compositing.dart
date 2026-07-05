import 'dart:ui';

/// Alpha-composites [foreground] over [background] using the Porter-Duff
/// "source-over" operator, returning the resulting blended colour.
///
/// This is the correct way to resolve a **semi-transparent colour** into a
/// single opaque colour before measuring contrast: WCAG contrast is only
/// defined for opaque colours, so a translucent foreground must first be
/// flattened onto whatever sits behind it.
///
/// Blending is performed in gamma-encoded sRGB space (channel values as
/// stored), which matches the convention used by browsers and mainstream
/// contrast tooling. Alpha is un-premultiplied in the result.
///
/// Behaviour at the edges:
/// * If [foreground] is fully opaque, it is returned unchanged.
/// * If [foreground] is fully transparent, [background] is returned unchanged.
/// * If both are fully transparent, a fully transparent black is returned.
///
/// When [background] is opaque (the usual case) the result is also opaque and
/// ready to pass to `relativeLuminance` / `contrastRatio`.
Color compositeOver(Color foreground, Color background) {
  final fa = foreground.a;
  if (fa >= 1.0) return foreground;
  if (fa <= 0.0) return background;

  final ba = background.a;
  final outA = fa + ba * (1.0 - fa);
  if (outA <= 0.0) return const Color(0x00000000);

  double blend(double f, double b) => (f * fa + b * ba * (1.0 - fa)) / outA;

  return Color.from(
    alpha: outA,
    red: blend(foreground.r, background.r),
    green: blend(foreground.g, background.g),
    blue: blend(foreground.b, background.b),
  );
}

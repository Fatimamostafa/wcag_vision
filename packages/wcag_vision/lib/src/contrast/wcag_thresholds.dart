/// A WCAG 2.x conformance level for text contrast.
///
/// Higher levels demand greater contrast. Success Criterion 1.4.3 defines the
/// [aa] thresholds; the stricter 1.4.6 defines [aaa].
enum WcagConformanceLevel {
  /// WCAG Level AA — the level most legislation and design systems target.
  aa,

  /// WCAG Level AAA — the enhanced level, rarely required site-wide.
  aaa,
}

/// The text-size category a contrast requirement applies to.
///
/// WCAG applies a more lenient threshold to [large] text because bigger glyphs
/// remain legible at lower contrast. "Large" means at least 18pt, or 14pt when
/// bold (roughly 24px / 18.66px at the default zoom). Classifying a given text
/// run is the caller's responsibility.
enum WcagTextSize {
  /// Text below the WCAG "large" size boundary.
  normal,

  /// Text at or above the WCAG "large" size boundary (>= 18pt, or 14pt bold).
  large,
}

/// Returns the minimum contrast ratio required for the given [level] and
/// [size], per WCAG 2.x Success Criteria 1.4.3 (AA) and 1.4.6 (AAA).
///
/// The returned value is the lower bound of a passing ratio, e.g. a ratio of
/// exactly `4.5` passes AA for normal text.
///
/// | Level | Normal | Large |
/// |-------|--------|-------|
/// | AA    | 4.5    | 3.0   |
/// | AAA   | 7.0    | 4.5   |
double wcagThreshold(WcagConformanceLevel level, WcagTextSize size) {
  return switch ((level, size)) {
    (WcagConformanceLevel.aa, WcagTextSize.normal) => 4.5,
    (WcagConformanceLevel.aa, WcagTextSize.large) => 3.0,
    (WcagConformanceLevel.aaa, WcagTextSize.normal) => 7.0,
    (WcagConformanceLevel.aaa, WcagTextSize.large) => 4.5,
  };
}

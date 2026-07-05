# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- CVD (colour vision deficiency) simulation:
  - `CvdType` — `none`, `protanopia`, `deuteranopia`, `tritanopia`.
  - `simulateCvd` — applies the Machado, Oliveira & Fairchild (2009)
    physiologically-based model (severity-1.0 matrices, applied in linear
    RGB with IEC 61966-2-1 sRGB decode/encode) to a `Color`. `CvdType.none`
    is the identity; achromatic colours are invariant; alpha passes through
    untouched.
- Unit tests for CVD simulation: identity, achromatic invariance, hand-
  computed reference values from the published matrices, red–green
  confusion behaviour, clamping, and alpha preservation.

- WCAG 2.x contrast engine:
  - `relativeLuminance` — relative luminance per the WCAG definition,
    including the sRGB linearization transfer function.
  - `contrastRatio` — the `(L1 + 0.05) / (L2 + 0.05)` contrast ratio for
    opaque colour pairs, with `minContrastRatio` / `maxContrastRatio`
    constants.
  - `compositeOver` — Porter–Duff source-over alpha compositing, so
    semi-transparent foregrounds are resolved to their effective colour
    before contrast is measured.
  - `contrastRatioOver` — contrast of a possibly translucent foreground
    against an opaque background.
  - `WcagConformanceLevel` (AA / AAA), `WcagTextSize` (normal / large) and
    `wcagThreshold` — the SC 1.4.3 / 1.4.6 minimum-ratio lookup.
  - `ContrastReport` and `evaluateContrast` — a single-call evaluation
    returning the ratio plus pass/fail against every level/size combination.
- Unit test suite covering luminance reference values, ratio bounds and
  symmetry, threshold boundaries, and alpha-blending edge cases.

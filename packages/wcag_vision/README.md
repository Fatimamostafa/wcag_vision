# wcag_vision

[![CI](https://github.com/Fatimamostafa/wcag_vision/actions/workflows/ci.yml/badge.svg)](https://github.com/Fatimamostafa/wcag_vision/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/wcag_vision.svg)](https://pub.dev/packages/wcag_vision)
[![pub points](https://img.shields.io/pub/points/wcag_vision)](https://pub.dev/packages/wcag_vision/score)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Fatimamostafa/wcag_vision/blob/main/packages/wcag_vision/LICENSE)

wcag_vision helps you build accessible Flutter apps: check color contrast,
preview how colors look under color blindness, and pull the dominant colors
out of any image - no accessibility background needed to get started.

An offline, algorithmic WCAG accessibility engine — **pure Dart, no Flutter
dependency**. It runs anywhere Dart runs (CLI tools, servers, web, and
Flutter apps alike) and computes colour contrast exactly as specified by
[WCAG 2.1](https://www.w3.org/TR/WCAG21/) — no network calls, no heuristics,
just the spec's own math as pure, deterministic functions.

## Using it from Flutter

Because this package has no Flutter dependency, it represents colours with
its own [`WcagColor`](lib/src/color/wcag_color.dart) rather than `dart:ui`'s
`Color`. Converting between the two at your app's UI boundary is a
one-line, lossless operation, since both share the same component model
(straight alpha, each channel a `double` in `[0, 1]`):

```dart
import 'package:flutter/material.dart' as material;
import 'package:wcag_vision/wcag_vision.dart';

WcagColor toWcagColor(material.Color c) =>
    WcagColor.from(alpha: c.a, red: c.r, green: c.g, blue: c.b);

material.Color toFlutterColor(WcagColor c) =>
    material.Color.from(alpha: c.a, red: c.r, green: c.g, blue: c.b);
```

See `example/lib/main.dart` for this conversion used throughout a real
Flutter screen.

## What it implements

The **colour extraction module**:

- **K-means dominant-colour extraction** — `extractDominantColors` runs
  deterministic Lloyd's k-means with seeded
  [k-means++](https://dl.acm.org/doi/10.5555/1283383.1283494) initialisation
  (Arthur & Vassilvitskii, 2007) over sRGB, with configurable cluster count,
  convergence controls, and stratified random downsampling (one seeded draw
  per grid cell — alias-free on periodic patterns, reproducible via the
  seed) for full-resolution photos. Clustering runs in sRGB today; **OKLab**
  is the named target for a future perceptual-clustering refinement.
  `extractDominantColorsAsync` runs the same extraction off the main
  isolate via `Isolate.run` — designed for **one-shot, single-capture**
  analysis (tap → analyse one still frame); continuous per-frame streaming
  is out of scope by design.

The **CVD simulation module**:

- **Colour vision deficiency simulation** — protanopia, deuteranopia, and
  tritanopia via `simulateCvd`, using the physiologically-based model of
  [Machado, Oliveira & Fairchild (2009)](https://doi.org/10.1109/TVCG.2009.113)
  (severity-1.0 matrices, applied in linear RGB). Greys are invariant,
  `CvdType.none` is the identity, and alpha passes through untouched.

The **contrast module**, covering:

- **Relative luminance** — the WCAG 2.x definition
  ([§ relative luminance](https://www.w3.org/TR/WCAG21/#dfn-relative-luminance)),
  including the sRGB linearization transfer function with the spec's published
  `0.03928` threshold.
- **Contrast ratio** — `(L1 + 0.05) / (L2 + 0.05)`
  ([§ contrast ratio](https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio)),
  symmetric, bounded to `[1.0, 21.0]`.
- **AA / AAA conformance** — thresholds from Success Criteria
  [1.4.3 Contrast (Minimum)](https://www.w3.org/TR/WCAG21/#contrast-minimum)
  and [1.4.6 Contrast (Enhanced)](https://www.w3.org/TR/WCAG21/#contrast-enhanced),
  for both normal and large text.
- **Semi-transparent colours** — WCAG contrast is only defined for opaque
  colours, so translucent foregrounds are alpha-composited (Porter–Duff
  source-over) onto the background before measuring, matching browser and
  mainstream-tooling behaviour.

| Level | Normal text | Large text |
|-------|-------------|------------|
| AA    | ≥ 4.5 : 1   | ≥ 3.0 : 1  |
| AAA   | ≥ 7.0 : 1   | ≥ 4.5 : 1  |

## Usage

```dart
import 'package:wcag_vision/wcag_vision.dart';

void main() {
  const foreground = WcagColor(0xFF767676); // mid grey
  const background = WcagColor(0xFFFFFFFF); // white

  final report = evaluateContrast(foreground, background);

  print(report.ratio);           // ~4.54
  print(report.passesAaNormal);  // true  (>= 4.5)
  print(report.passesAaaNormal); // false (< 7.0)

  // Translucent foregrounds are flattened onto the background first:
  const overlay = WcagColor.from(alpha: 0.5, red: 0, green: 0, blue: 0);
  final overlayReport = evaluateContrast(overlay, background);
  print(overlayReport.ratio);    // contrast of the *effective* blended colour
}
```

Lower-level primitives (`relativeLuminance`, `contrastRatio`,
`compositeOver`, `wcagThreshold`) are also exported for callers that need
the raw calculations.

## Design principles

- Fully offline and algorithmic — no data collection, no network access.
- Pure Dart, no Flutter dependency — usable from CLI tools and servers, not
  just Flutter apps.
- Pure functions with deterministic outputs, unit-tested against reference
  values from the WCAG spec.
- Part of a Melos monorepo; consumed by the `a11y_scanner` app the same way
  any external user would consume it.

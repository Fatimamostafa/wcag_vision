import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wcag_vision/wcag_vision.dart';

const Color red = Color(0xFFFF0000);
const Color green = Color(0xFF00FF00);
const Color blue = Color(0xFF0000FF);

/// A synthetic image of [count] pixels of a single [color].
List<Color> solidImage(Color color, int count) => List.filled(count, color);

/// A synthetic image with [redCount] red pixels followed by [blueCount]
/// blue ones.
List<Color> redBlueImage(int redCount, int blueCount) => [
      ...solidImage(red, redCount),
      ...solidImage(blue, blueCount),
    ];

/// A noisy three-blob image: pixels scattered tightly around red, green
/// and blue anchors, generated deterministically from [seed].
List<Color> threeBlobImage(int perBlob, {int seed = 7}) {
  final rng = math.Random(seed);
  double jitter(double v) => (v + (rng.nextDouble() - 0.5) * 0.1).clamp(0, 1);
  Color around(Color anchor) => Color.from(
        alpha: 1,
        red: jitter(anchor.r),
        green: jitter(anchor.g),
        blue: jitter(anchor.b),
      );
  return [
    for (var i = 0; i < perBlob; i++) around(red),
    for (var i = 0; i < perBlob; i++) around(green),
    for (var i = 0; i < perBlob; i++) around(blue),
  ];
}

void expectColorCloseTo(Color actual, Color expected, {double tol = 1e-9}) {
  expect(actual.r, closeTo(expected.r, tol));
  expect(actual.g, closeTo(expected.g, tol));
  expect(actual.b, closeTo(expected.b, tol));
}

void main() {
  group('extractDominantColors — basic clustering', () {
    test('solid-colour image yields a single cluster of that colour', () {
      const olive = Color(0xFF808000);
      final result = extractDominantColors(solidImage(olive, 500));
      expect(result, hasLength(1));
      expectColorCloseTo(result.first.color, olive);
      expect(result.first.share, 1.0);
    });

    test('two-colour image yields two clusters with matching shares', () {
      final result = extractDominantColors(redBlueImage(600, 400), k: 2);
      expect(result, hasLength(2));
      // Sorted by share, largest first.
      expectColorCloseTo(result[0].color, red);
      expect(result[0].share, closeTo(0.6, 1e-9));
      expectColorCloseTo(result[1].color, blue);
      expect(result[1].share, closeTo(0.4, 1e-9));
    });

    test('shares always sum to 1.0', () {
      final result = extractDominantColors(threeBlobImage(300), k: 5);
      final total = result.fold<double>(0, (sum, c) => sum + c.share);
      expect(total, closeTo(1, 1e-9));
    });

    test('returned colours are opaque regardless of input alpha', () {
      const translucent = Color.from(alpha: 0.3, red: 1, green: 0, blue: 0);
      final result = extractDominantColors(solidImage(translucent, 100));
      expect(result.single.color.a, 1.0);
    });
  });

  group('extractDominantColors — degenerate inputs', () {
    test('k larger than the number of distinct colours does not crash', () {
      final result = extractDominantColors(redBlueImage(60, 40), k: 7);
      expect(result, hasLength(2)); // only 2 distinct colours exist
    });

    test('k larger than distinct colours on a solid image', () {
      final result = extractDominantColors(solidImage(red, 10), k: 8);
      expect(result, hasLength(1));
      expect(result.single.share, 1.0);
    });

    test('single-pixel image works', () {
      final result = extractDominantColors([blue]);
      expect(result, hasLength(1));
      expectColorCloseTo(result.single.color, blue);
    });

    test('empty input throws ArgumentError', () {
      expect(() => extractDominantColors([]), throwsArgumentError);
    });

    test('invalid parameters throw ArgumentError', () {
      final pixels = solidImage(red, 4);
      expect(() => extractDominantColors(pixels, k: 0), throwsArgumentError);
      expect(
        () => extractDominantColors(pixels, maxIterations: 0),
        throwsArgumentError,
      );
      expect(
        () => extractDominantColors(pixels, maxSamples: 0),
        throwsArgumentError,
      );
      expect(
        () => extractDominantColors(pixels, convergenceThreshold: -1),
        throwsArgumentError,
      );
    });
  });

  group('extractDominantColors — convergence', () {
    test('converges within the default iteration cap on a noisy image', () {
      // If clustering converged before the cap, granting extra iterations
      // must change nothing. Compare the default cap against a much
      // higher one on the same input and seed.
      final pixels = threeBlobImage(400);
      final capped = extractDominantColors(pixels, k: 3);
      final generous = extractDominantColors(
        pixels,
        k: 3,
        maxIterations: defaultMaxIterations + 50,
      );
      expect(capped, equals(generous));
    });

    test('finds the three blob anchors on the noisy image', () {
      final result = extractDominantColors(threeBlobImage(400), k: 3);
      expect(result, hasLength(3));
      // Jitter is +/-0.05 per channel and zero-mean, so each centroid
      // should sit close to its anchor.
      final anchors = [red, green, blue];
      for (final anchor in anchors) {
        final nearest = result
            .map((c) {
              final dr = c.color.r - anchor.r;
              final dg = c.color.g - anchor.g;
              final db = c.color.b - anchor.b;
              return math.sqrt(dr * dr + dg * dg + db * db);
            })
            .reduce(math.min);
        expect(nearest, lessThan(0.05), reason: 'no centroid near $anchor');
      }
    });
  });

  group('extractDominantColors — determinism', () {
    test('same input and seed produce identical output, run twice', () {
      final pixels = threeBlobImage(500);
      final a = extractDominantColors(pixels, k: 4, seed: 42);
      final b = extractDominantColors(pixels, k: 4, seed: 42);
      expect(a, equals(b));
    });
  });

  group('extractDominantColors — downsampling', () {
    test('maxSamples caps the work while preserving colour proportions', () {
      // 20k pixels, but only 500 samples allowed. Stratified sampling
      // draws one pixel per 40-pixel cell; with two contiguous blocks the
      // cells are single-coloured, so the 60/40 split is recovered almost
      // exactly (the tolerance covers at most one mixed boundary cell).
      final result = extractDominantColors(
        redBlueImage(12000, 8000),
        k: 2,
        maxSamples: 500,
      );
      expect(result, hasLength(2));
      expect(result[0].share, closeTo(0.6, 0.02));
      expect(result[1].share, closeTo(0.4, 0.02));
    });

    test('stratified sampling does not alias against periodic stripes', () {
      // Regression test for the stride-sampling aliasing bug.
      //
      // 500 periods of 16 pixels (8 red then 8 blue) = 8000 pixels, true
      // colour split exactly 50/50. With maxSamples: 500 each sampling
      // cell is exactly one period (8000 / 500 = 16), the pathological
      // phase-locked case: plain stride sampling picks index 0, 16, 32,
      // ... — the first (red) pixel of every period — sees 500 identical
      // red samples, and reports a single 100% red cluster (this exact
      // assertion, hasLength(2), fails under the old implementation).
      // Stratified sampling draws a random position inside each period,
      // making each sample a fair coin flip, and recovers ~50/50.
      final stripes = [
        for (var p = 0; p < 500; p++) ...[
          ...solidImage(red, 8),
          ...solidImage(blue, 8),
        ],
      ];
      final result = extractDominantColors(stripes, k: 2, maxSamples: 500);
      expect(result, hasLength(2));
      // 500 fair draws: sigma ~= 0.022, so 0.08 is a > 3-sigma margin —
      // and the seeded RNG makes the actual value reproducible anyway.
      expect(result[0].share, closeTo(0.5, 0.08));
      expect(result[1].share, closeTo(0.5, 0.08));
      // Every sample is a pure stripe colour, so each centroid must be
      // exactly red or exactly blue (order depends on the random draw).
      final first = result[0].color;
      final second = result[1].color;
      if (first.r > first.b) {
        expectColorCloseTo(first, red);
        expectColorCloseTo(second, blue);
      } else {
        expectColorCloseTo(first, blue);
        expectColorCloseTo(second, red);
      }
    });
  });

  group('extractDominantColorsAsync', () {
    test('returns the same result as the synchronous function', () async {
      final pixels = threeBlobImage(300);
      final sync = extractDominantColors(pixels, k: 3, seed: 1);
      final async = await extractDominantColorsAsync(pixels, k: 3, seed: 1);
      expect(async, equals(sync));
    });
  });
}

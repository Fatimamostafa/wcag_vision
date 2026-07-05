import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:wcag_vision/src/color_extraction/extracted_color.dart';

/// Default number of clusters ([extractDominantColors]'s `k`).
///
/// The product spec calls for 5–8 dominant colours per capture; 6 sits in
/// the middle of that range.
const int defaultClusterCount = 6;

/// Default cap on Lloyd iterations. Dominant-colour extraction on
/// well-separated palettes converges in well under 10 iterations; 25 leaves
/// generous headroom for noisy photographs without risking a long stall.
const int defaultMaxIterations = 25;

/// Default centroid-movement convergence threshold, expressed as Euclidean
/// distance in the RGB unit cube.
///
/// `1/255` is one 8-bit quantisation step — once every centroid moves less
/// than a single displayable colour step per iteration, further refinement
/// cannot change what the user sees.
const double defaultConvergenceThreshold = 1 / 255;

/// Default maximum number of pixels sampled from the input.
///
/// 4096 samples (a 64x64 grid's worth) is plenty to estimate 5–8 dominant
/// colours from a photograph, and keeps the k-means cost independent of
/// capture resolution: a 12 MP still is downsampled ~3000x before
/// clustering.
const int defaultMaxSamples = 4096;

/// Extracts the dominant colours of an image using k-means clustering.
///
/// [pixels] is the image's pixel data in any order (row-major scan order is
/// typical). The return value contains at most [k] clusters, each with its
/// centroid colour and the fraction of sampled pixels it covers, sorted by
/// share, largest first. Fewer than [k] clusters are returned when the
/// input has fewer distinct colours than [k] (the degenerate case is
/// handled, not an error).
///
/// This function is **pure, synchronous and deterministic** — identical
/// inputs (including [seed]) produce identical results. For use from a UI,
/// prefer [extractDominantColorsAsync], which runs this off the main
/// isolate.
///
/// ## Algorithm
///
/// Standard Lloyd's k-means over the gamma-encoded sRGB components
/// (`Color.r/g/b`), initialised with **k-means++** seeding:
///
/// * D. Arthur and S. Vassilvitskii, "k-means++: The Advantages of Careful
///   Seeding", Proc. 18th ACM-SIAM Symposium on Discrete Algorithms
///   (SODA '07), pp. 1027–1035, 2007.
///   <https://dl.acm.org/doi/10.5555/1283383.1283494>
///
/// k-means++ draws its random choices from a `Random` constructed with
/// [seed], so seeding is deterministic *and* retains k-means++'s spread-out
/// initial centroids — reproducible tests without giving up clustering
/// quality. Clustering happens directly in gamma-encoded sRGB (not linear
/// RGB or a perceptual space): for dominant-colour extraction the gamma
/// encoding is closer to perceptual uniformity than linear light, and the
/// simplicity keeps this KISS. **OKLab** is the named target for a future
/// perceptual-clustering refinement, which can be layered on later
/// without changing this API.
///
/// ## Parameters
///
/// * [k] — maximum number of clusters (default [defaultClusterCount]).
/// * [seed] — seed for the k-means++ random draws; same seed, same result.
/// * [maxIterations] — hard cap on Lloyd iterations
///   (default [defaultMaxIterations]).
/// * [convergenceThreshold] — stop once no centroid moves further than
///   this Euclidean distance in the RGB unit cube in one iteration
///   (default [defaultConvergenceThreshold], one 8-bit step).
/// * [maxSamples] — at most this many pixels are clustered
///   (default [defaultMaxSamples]). Larger inputs are downsampled by
///   **stratified random sampling**: the image is partitioned into
///   [maxSamples] equal cells and one pixel is drawn from a seeded-random
///   position within each cell. This avoids the aliasing that plain
///   stride sampling suffers against regular, repeating image patterns
///   (which can phase-lock the sampler onto a single colour), while
///   keeping samples spread across the whole image so colour proportions
///   are preserved — and it stays fully reproducible, because the draws
///   come from the same [seed]-derived RNG as the k-means++ step.
///
/// Alpha is ignored; returned colours are fully opaque.
///
/// Throws [ArgumentError] if [pixels] is empty or any numeric parameter is
/// out of range.
List<ExtractedColor> extractDominantColors(
  List<Color> pixels, {
  int k = defaultClusterCount,
  int seed = 0,
  int maxIterations = defaultMaxIterations,
  double convergenceThreshold = defaultConvergenceThreshold,
  int maxSamples = defaultMaxSamples,
}) {
  if (pixels.isEmpty) {
    throw ArgumentError.value(pixels, 'pixels', 'must not be empty');
  }
  if (k < 1) {
    throw ArgumentError.value(k, 'k', 'must be at least 1');
  }
  if (maxIterations < 1) {
    throw ArgumentError.value(maxIterations, 'maxIterations', 'must be >= 1');
  }
  if (convergenceThreshold < 0) {
    throw ArgumentError.value(
      convergenceThreshold,
      'convergenceThreshold',
      'must be >= 0',
    );
  }
  if (maxSamples < 1) {
    throw ArgumentError.value(maxSamples, 'maxSamples', 'must be >= 1');
  }

  // --- Downsample by stratified random sampling (seeded, deterministic).
  //
  // The input is partitioned into `sampleCount` equal cells and one pixel
  // is drawn from a seeded-random position inside each cell. Plain stride
  // sampling (always the first pixel of each cell) phase-locks against
  // regular, repeating patterns whose period divides the stride — striped
  // test cards, UI screenshots with repeating rows — and can collapse
  // them to a single colour. The random within-cell offset breaks that
  // phase lock while keeping samples spread across the whole image, so
  // colour proportions are preserved; and because every draw comes from
  // the same `Random(seed)` reused by k-means++ below, the whole
  // extraction remains fully reproducible.
  final rng = math.Random(seed);
  final sampleCount = math.min(pixels.length, maxSamples);
  final xr = Float64List(sampleCount);
  final xg = Float64List(sampleCount);
  final xb = Float64List(sampleCount);
  if (sampleCount == pixels.length) {
    // No downsampling needed — take every pixel.
    for (var i = 0; i < sampleCount; i++) {
      final pixel = pixels[i];
      xr[i] = pixel.r;
      xg[i] = pixel.g;
      xb[i] = pixel.b;
    }
  } else {
    final stride = pixels.length / sampleCount;
    for (var i = 0; i < sampleCount; i++) {
      final cellStart = (i * stride).floor();
      var cellEnd = math.min(((i + 1) * stride).floor(), pixels.length);
      if (cellEnd <= cellStart) cellEnd = cellStart + 1;
      final pixel = pixels[cellStart + rng.nextInt(cellEnd - cellStart)];
      xr[i] = pixel.r;
      xg[i] = pixel.g;
      xb[i] = pixel.b;
    }
  }

  double dist2(double r1, double g1, double b1, double r2, double g2,
      double b2) {
    final dr = r1 - r2;
    final dg = g1 - g2;
    final db = b1 - b2;
    return dr * dr + dg * dg + db * db;
  }

  // --- k-means++ seeding (Arthur & Vassilvitskii 2007). ---
  // Reuses the same seeded RNG as the sampling step above — one seed
  // governs the entire extraction.
  final cr = <double>[];
  final cg = <double>[];
  final cb = <double>[];

  final first = rng.nextInt(sampleCount);
  cr.add(xr[first]);
  cg.add(xg[first]);
  cb.add(xb[first]);

  // Squared distance from each sample to its nearest chosen centroid.
  final nearestD2 = Float64List(sampleCount);
  for (var i = 0; i < sampleCount; i++) {
    nearestD2[i] = dist2(xr[i], xg[i], xb[i], cr[0], cg[0], cb[0]);
  }

  while (cr.length < k) {
    var total = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      total += nearestD2[i];
    }
    // Every sample coincides with a centroid: fewer distinct colours than
    // k. Stop seeding — the degenerate case returns fewer clusters.
    if (total <= 0) break;

    var target = rng.nextDouble() * total;
    var chosen = sampleCount - 1;
    for (var i = 0; i < sampleCount; i++) {
      target -= nearestD2[i];
      if (target <= 0) {
        chosen = i;
        break;
      }
    }
    cr.add(xr[chosen]);
    cg.add(xg[chosen]);
    cb.add(xb[chosen]);

    final c = cr.length - 1;
    for (var i = 0; i < sampleCount; i++) {
      final d = dist2(xr[i], xg[i], xb[i], cr[c], cg[c], cb[c]);
      if (d < nearestD2[i]) nearestD2[i] = d;
    }
  }

  // --- Lloyd iterations. ---
  final clusterCount = cr.length;
  final assignment = Int32List(sampleCount);
  final sumR = Float64List(clusterCount);
  final sumG = Float64List(clusterCount);
  final sumB = Float64List(clusterCount);
  final counts = Int32List(clusterCount);
  final threshold2 = convergenceThreshold * convergenceThreshold;

  for (var iteration = 0; iteration < maxIterations; iteration++) {
    // Assignment step.
    for (var i = 0; i < sampleCount; i++) {
      var best = 0;
      var bestD2 = dist2(xr[i], xg[i], xb[i], cr[0], cg[0], cb[0]);
      for (var j = 1; j < clusterCount; j++) {
        final d = dist2(xr[i], xg[i], xb[i], cr[j], cg[j], cb[j]);
        if (d < bestD2) {
          bestD2 = d;
          best = j;
        }
      }
      assignment[i] = best;
    }

    // Update step.
    for (var j = 0; j < clusterCount; j++) {
      sumR[j] = 0;
      sumG[j] = 0;
      sumB[j] = 0;
      counts[j] = 0;
    }
    for (var i = 0; i < sampleCount; i++) {
      final j = assignment[i];
      sumR[j] += xr[i];
      sumG[j] += xg[i];
      sumB[j] += xb[i];
      counts[j]++;
    }

    var maxMove2 = 0.0;
    for (var j = 0; j < clusterCount; j++) {
      // An empty cluster keeps its previous centroid; it is dropped from
      // the result if still empty after the final assignment.
      if (counts[j] == 0) continue;
      final newR = sumR[j] / counts[j];
      final newG = sumG[j] / counts[j];
      final newB = sumB[j] / counts[j];
      final move2 = dist2(newR, newG, newB, cr[j], cg[j], cb[j]);
      if (move2 > maxMove2) maxMove2 = move2;
      cr[j] = newR;
      cg[j] = newG;
      cb[j] = newB;
    }
    if (maxMove2 <= threshold2) break;
  }

  // --- Final assignment against the final centroids, then build result. ---
  for (var j = 0; j < clusterCount; j++) {
    counts[j] = 0;
  }
  for (var i = 0; i < sampleCount; i++) {
    var best = 0;
    var bestD2 = dist2(xr[i], xg[i], xb[i], cr[0], cg[0], cb[0]);
    for (var j = 1; j < clusterCount; j++) {
      final d = dist2(xr[i], xg[i], xb[i], cr[j], cg[j], cb[j]);
      if (d < bestD2) {
        bestD2 = d;
        best = j;
      }
    }
    counts[best]++;
  }

  final indices = [
    for (var j = 0; j < clusterCount; j++)
      if (counts[j] > 0) j,
  ]..sort((a, b) {
      final byShare = counts[b].compareTo(counts[a]);
      // Deterministic order for equal populations: seeding order.
      return byShare != 0 ? byShare : a.compareTo(b);
    });

  return [
    for (final j in indices)
      ExtractedColor(
        color: Color.from(
          alpha: 1,
          red: clampDouble(cr[j], 0, 1),
          green: clampDouble(cg[j], 0, 1),
          blue: clampDouble(cb[j], 0, 1),
        ),
        share: counts[j] / sampleCount,
      ),
  ];
}

/// Extracts dominant colours off the main isolate — the entry point UI code
/// should call.
///
/// Runs [extractDominantColors] (same parameters, same deterministic
/// result) inside [Isolate.run], so a full-resolution still can be
/// processed without janking the UI thread. Uses `dart:isolate` directly
/// rather than Flutter's `compute()`, keeping this module free of Flutter
/// imports; note that `Isolate.run` is unavailable on the web, where the
/// synchronous [extractDominantColors] should be called instead.
///
/// ## One-shot by design
///
/// This wrapper is built for **single-capture** use — the user taps, one
/// still frame is analysed, one isolate is spawned and torn down. That
/// matches this product's capture model and keeps the package free of
/// lifecycle concerns. Continuous, per-frame extraction from a live camera
/// feed would need different orchestration — a long-lived isolate with
/// `SendPort`/`ReceivePort` streaming owned by the consuming app's Service
/// layer (see the architecture doc's concurrency rules) — and is
/// deliberately out of scope for this package.
Future<List<ExtractedColor>> extractDominantColorsAsync(
  List<Color> pixels, {
  int k = defaultClusterCount,
  int seed = 0,
  int maxIterations = defaultMaxIterations,
  double convergenceThreshold = defaultConvergenceThreshold,
  int maxSamples = defaultMaxSamples,
}) {
  return Isolate.run(
    () => extractDominantColors(
      pixels,
      k: k,
      seed: seed,
      maxIterations: maxIterations,
      convergenceThreshold: convergenceThreshold,
      maxSamples: maxSamples,
    ),
  );
}

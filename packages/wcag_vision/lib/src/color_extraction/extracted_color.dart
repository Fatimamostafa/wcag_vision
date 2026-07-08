import 'package:meta/meta.dart';
import 'package:wcag_vision/src/color/wcag_color.dart';

/// One dominant colour found by k-means extraction, together with how much
/// of the sampled image it accounts for.
@immutable
class ExtractedColor {
  /// Creates an extracted colour with its population [share].
  const ExtractedColor({required this.color, required this.share});

  /// The cluster's centroid colour. Always fully opaque — extraction
  /// clusters on the RGB components only and ignores alpha.
  final WcagColor color;

  /// The fraction of sampled pixels assigned to this cluster, in `(0, 1]`.
  ///
  /// Shares across a single extraction result sum to 1.0 (within
  /// floating-point noise).
  final double share;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractedColor && other.color == color && other.share == share;

  @override
  int get hashCode => Object.hash(color, share);

  @override
  String toString() =>
      'ExtractedColor(color: $color, share: ${share.toStringAsFixed(4)})';
}

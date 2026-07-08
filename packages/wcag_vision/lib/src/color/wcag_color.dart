import 'package:meta/meta.dart';

/// An RGBA colour with components stored as `double`s in `[0, 1]`.
///
/// `wcag_vision` is a pure-Dart package with no Flutter dependency, so it
/// cannot use `dart:ui`'s `Color` — that type ships with the Flutter
/// engine, not the core Dart SDK. [WcagColor] is a small, dependency-free
/// stand-in with the same component model (straight, un-premultiplied
/// alpha; each channel gamma-encoded sRGB in `[0, 1]`), so the package runs
/// anywhere Dart runs: CLI tools, servers, web, and Flutter alike.
///
/// Converting to and from Flutter's `Color` is a one-line, lossless
/// operation at your app's UI boundary, since both types share the same
/// component model:
///
/// ```dart
/// import 'package:flutter/material.dart' as material;
/// import 'package:wcag_vision/wcag_vision.dart';
///
/// WcagColor toWcagColor(material.Color c) =>
///     WcagColor.from(alpha: c.a, red: c.r, green: c.g, blue: c.b);
///
/// material.Color toFlutterColor(WcagColor c) =>
///     material.Color.from(alpha: c.a, red: c.r, green: c.g, blue: c.b);
/// ```
@immutable
class WcagColor {
  /// Creates a colour from a 32-bit ARGB integer, e.g. `0xFFFF0000` for
  /// opaque red — the same encoding as Flutter's `Color(int)`.
  const WcagColor(int argb)
      : this.from(
          alpha: ((argb >> 24) & 0xff) / 255,
          red: ((argb >> 16) & 0xff) / 255,
          green: ((argb >> 8) & 0xff) / 255,
          blue: (argb & 0xff) / 255,
        );

  /// Creates a colour from its components, each in `[0, 1]`.
  const WcagColor.from({
    required double alpha,
    required double red,
    required double green,
    required double blue,
  })  : a = alpha,
        r = red,
        g = green,
        b = blue;

  /// Creates a colour from 8-bit (`0`-`255`) integer components — the same
  /// convention as Flutter's `Color.fromARGB`.
  const WcagColor.fromARGB(int alpha255, int red255, int green255, int blue255)
      : this.from(
          alpha: alpha255 / 255,
          red: red255 / 255,
          green: green255 / 255,
          blue: blue255 / 255,
        );

  /// Alpha, in `[0, 1]`. `1` is fully opaque, `0` is fully transparent.
  final double a;

  /// Red channel, gamma-encoded sRGB, in `[0, 1]`.
  final double r;

  /// Green channel, gamma-encoded sRGB, in `[0, 1]`.
  final double g;

  /// Blue channel, gamma-encoded sRGB, in `[0, 1]`.
  final double b;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WcagColor &&
          other.a == a &&
          other.r == r &&
          other.g == g &&
          other.b == b;

  @override
  int get hashCode => Object.hash(a, r, g, b);

  @override
  String toString() =>
      'WcagColor(a: ${a.toStringAsFixed(3)}, r: ${r.toStringAsFixed(3)}, '
      'g: ${g.toStringAsFixed(3)}, b: ${b.toStringAsFixed(3)})';
}

/// Clamps [value] to the unit range `[0, 1]`.
///
/// A tiny stand-in for `dart:ui`'s `clampDouble`, kept internal so the
/// colour modules never need a Flutter import just for clamping.
double clampUnit(double value) => value < 0 ? 0 : (value > 1 ? 1 : value);

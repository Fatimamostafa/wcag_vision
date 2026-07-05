import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSVColor;
import 'package:flutter_test/flutter_test.dart';
import 'package:wcag_vision/wcag_vision.dart';

const Color black = Color(0xFF000000);
const Color white = Color(0xFFFFFFFF);
const Color red = Color(0xFFFF0000);
const Color green = Color(0xFF00FF00);
const Color blue = Color(0xFF0000FF);

const List<CvdType> dichromacies = [
  CvdType.protanopia,
  CvdType.deuteranopia,
  CvdType.tritanopia,
];

/// Euclidean distance between two colours in gamma-encoded sRGB space.
double rgbDistance(Color a, Color b) {
  final dr = a.r - b.r;
  final dg = a.g - b.g;
  final db = a.b - b.b;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

void main() {
  group('simulateCvd — CvdType.none', () {
    test('is the identity for arbitrary colours', () {
      const samples = <Color>[
        black,
        white,
        red,
        green,
        blue,
        Color(0xFF123456),
        Color(0x80ABCDEF),
      ];
      for (final color in samples) {
        expect(simulateCvd(color, CvdType.none), color);
      }
    });
  });

  group('simulateCvd — achromatic invariance', () {
    test('greys (including black and white) survive every deficiency', () {
      // Machado matrices have rows summing to 1.0, so r == g == b inputs
      // must map to themselves (within floating-point noise from the
      // decode -> multiply -> encode round trip).
      for (final type in dichromacies) {
        for (var v = 0; v <= 255; v += 51) {
          final grey = Color.fromARGB(255, v, v, v);
          final sim = simulateCvd(grey, type);
          expect(sim.r, closeTo(grey.r, 1e-4), reason: '$type grey $v (r)');
          expect(sim.g, closeTo(grey.g, 1e-4), reason: '$type grey $v (g)');
          expect(sim.b, closeTo(grey.b, 1e-4), reason: '$type grey $v (b)');
        }
      }
    });
  });

  group('simulateCvd — known reference values', () {
    // Expected values computed by hand from the Machado et al. (2009)
    // severity-1.0 matrices: decode sRGB -> multiply -> clamp -> encode,
    // using the IEC 61966-2-1 transfer function.
    test('protanopia turns pure red into a dark yellow-brown', () {
      // Linear red (1, 0, 0) -> matrix column 1 =
      // (0.152286, 0.114503, -0.003882); blue clamps to 0.
      final sim = simulateCvd(red, CvdType.protanopia);
      expect(sim.r, closeTo(0.42661, 1e-3));
      expect(sim.g, closeTo(0.37264, 1e-3));
      expect(sim.b, closeTo(0, 1e-9));
    });

    test('deuteranopia maps pure blue to expected channels', () {
      // Linear blue (0, 0, 1) -> matrix column 3 =
      // (-0.227968, 0.047413, 0.968881); red clamps to 0.
      final sim = simulateCvd(blue, CvdType.deuteranopia);
      expect(sim.r, closeTo(0, 1e-9));
      expect(sim.g, closeTo(0.24117, 1e-3));
      expect(sim.b, closeTo(0.98619, 1e-3));
    });
  });

  group('simulateCvd — qualitative behaviour', () {
    test('red and green collapse to the same hue under red-green '
        'dichromacies', () {
      // Dichromatic confusion is chromatic: protanopia also darkens red, so
      // a plain RGB distance keeps a large *lightness* gap. The defining
      // symptom is that both primaries end up the same yellowish hue.
      double hueOf(Color color) => HSVColor.fromColor(color).hue;

      expect(hueOf(green) - hueOf(red), 120); // sanity: 120 deg apart
      for (final type in [CvdType.protanopia, CvdType.deuteranopia]) {
        final hueDelta =
            (hueOf(simulateCvd(red, type)) - hueOf(simulateCvd(green, type)))
                .abs();
        expect(
          hueDelta,
          lessThan(15),
          reason: '$type should confuse red and green hues',
        );
      }
    });

    test('tritanopia leaves red essentially intact', () {
      // Red-green discrimination is unaffected by an absent S cone: the
      // tritanopia matrix maps linear red to (1.256 -> clamp 1, -0.078 ->
      // clamp 0, 0.005), i.e. still an unmistakable red.
      final sim = simulateCvd(red, CvdType.tritanopia);
      expect(sim.r, closeTo(1, 1e-9));
      expect(sim.g, closeTo(0, 1e-9));
      expect(sim.b, lessThan(0.1));
    });

    test('all outputs stay within [0, 1] (clamping works)', () {
      // Primaries drive matrix entries negative / above 1 before clamping.
      for (final type in dichromacies) {
        for (final color in const [red, green, blue, white, black]) {
          final sim = simulateCvd(color, type);
          for (final channel in [sim.r, sim.g, sim.b]) {
            expect(channel, greaterThanOrEqualTo(0));
            expect(channel, lessThanOrEqualTo(1));
          }
        }
      }
    });
  });

  group('simulateCvd — alpha handling', () {
    test('the alpha channel passes through unchanged', () {
      const translucent = Color.from(alpha: 0.5, red: 1, green: 0.4, blue: 0);
      for (final type in CvdType.values) {
        expect(simulateCvd(translucent, type).a, closeTo(0.5, 1e-9));
      }
    });
  });
}

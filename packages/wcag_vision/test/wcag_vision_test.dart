import 'package:test/test.dart';
import 'package:wcag_vision/wcag_vision.dart';

// Shared opaque test colours.
const WcagColor black = WcagColor(0xFF000000);
const WcagColor white = WcagColor(0xFFFFFFFF);
const WcagColor red = WcagColor(0xFFFF0000);
const WcagColor green = WcagColor(0xFF00FF00);
const WcagColor blue = WcagColor(0xFF0000FF);

void main() {
  group('relativeLuminance', () {
    test('is 0.0 for black and 1.0 for white', () {
      expect(relativeLuminance(black), closeTo(0, 1e-12));
      expect(relativeLuminance(white), closeTo(1, 1e-12));
    });

    test('matches the WCAG channel weights for primaries', () {
      expect(relativeLuminance(red), closeTo(0.2126, 1e-9));
      expect(relativeLuminance(green), closeTo(0.7152, 1e-9));
      expect(relativeLuminance(blue), closeTo(0.0722, 1e-9));
    });

    test('ignores the alpha channel', () {
      const translucentBlack = WcagColor(0x00000000);
      const translucentWhite = WcagColor(0x00FFFFFF);
      expect(
        relativeLuminance(translucentBlack),
        closeTo(relativeLuminance(black), 1e-12),
      );
      expect(
        relativeLuminance(translucentWhite),
        closeTo(relativeLuminance(white), 1e-12),
      );
    });

    test('is monotonic across a grey ramp', () {
      var previous = -1.0;
      for (var v = 0; v <= 255; v += 15) {
        final grey = WcagColor.fromARGB(255, v, v, v);
        final lum = relativeLuminance(grey);
        expect(lum, greaterThanOrEqualTo(previous));
        previous = lum;
      }
    });
  });

  group('contrastRatio', () {
    test('is 21.0 for black on white (the maximum)', () {
      expect(contrastRatio(black, white), closeTo(maxContrastRatio, 1e-9));
    });

    test('is 1.0 for a colour against itself (the minimum)', () {
      expect(contrastRatio(red, red), closeTo(minContrastRatio, 1e-12));
      expect(contrastRatio(white, white), closeTo(minContrastRatio, 1e-12));
    });

    test('is symmetric in its arguments', () {
      expect(
        contrastRatio(red, blue),
        closeTo(contrastRatio(blue, red), 1e-12),
      );
    });

    test('stays within [1.0, 21.0] for arbitrary pairs', () {
      final pairs = <(WcagColor, WcagColor)>[
        (red, green),
        (green, blue),
        (const WcagColor(0xFF777777), white),
        (const WcagColor(0xFF123456), const WcagColor(0xFFABCDEF)),
      ];
      for (final (a, b) in pairs) {
        final ratio = contrastRatio(a, b);
        expect(ratio, greaterThanOrEqualTo(minContrastRatio));
        expect(ratio, lessThanOrEqualTo(maxContrastRatio));
      }
    });

    test('matches a known reference value (#767676 on white ~ 4.54)', () {
      const grey = WcagColor(0xFF767676);
      expect(contrastRatio(grey, white), closeTo(4.54, 0.01));
    });
  });

  group('compositeOver', () {
    test('returns the foreground unchanged when it is opaque', () {
      expect(compositeOver(red, white), red);
    });

    test('returns the background unchanged when foreground is transparent', () {
      const clear = WcagColor(0x00123456);
      expect(compositeOver(clear, white), white);
    });

    test('blends a 50% black foreground over white to mid-grey', () {
      const halfBlack = WcagColor.from(alpha: 0.5, red: 0, green: 0, blue: 0);
      final result = compositeOver(halfBlack, white);
      expect(result.a, closeTo(1, 1e-12));
      expect(result.r, closeTo(0.5, 1e-12));
      expect(result.g, closeTo(0.5, 1e-12));
      expect(result.b, closeTo(0.5, 1e-12));
    });

    test('produces a partially transparent result over a translucent bg', () {
      const halfRed = WcagColor.from(alpha: 0.5, red: 1, green: 0, blue: 0);
      const halfBlue = WcagColor.from(alpha: 0.5, red: 0, green: 0, blue: 1);
      final result = compositeOver(halfRed, halfBlue);
      // outA = 0.5 + 0.5 * 0.5 = 0.75
      expect(result.a, closeTo(0.75, 1e-12));
    });

    test('returns transparent black when both inputs are transparent', () {
      const clearA = WcagColor(0x00FF0000);
      const clearB = WcagColor(0x0000FF00);
      final result = compositeOver(clearA, clearB);
      expect(result.a, closeTo(0, 1e-12));
    });
  });

  group('wcagThreshold', () {
    test('returns the WCAG 2.x minimum ratios', () {
      expect(
        wcagThreshold(WcagConformanceLevel.aa, WcagTextSize.normal),
        4.5,
      );
      expect(
        wcagThreshold(WcagConformanceLevel.aa, WcagTextSize.large),
        3.0,
      );
      expect(
        wcagThreshold(WcagConformanceLevel.aaa, WcagTextSize.normal),
        7.0,
      );
      expect(
        wcagThreshold(WcagConformanceLevel.aaa, WcagTextSize.large),
        4.5,
      );
    });
  });

  group('ContrastReport', () {
    test('applies thresholds exactly at the boundary (inclusive)', () {
      const atAaNormal = ContrastReport(ratio: 4.5);
      expect(atAaNormal.passesAaNormal, isTrue);
      expect(atAaNormal.passesAaLarge, isTrue);
      expect(atAaNormal.passesAaaNormal, isFalse);
      expect(atAaNormal.passesAaaLarge, isTrue);
    });

    test('fails just below a boundary', () {
      const justUnder = ContrastReport(ratio: 4.49);
      expect(justUnder.passesAaNormal, isFalse);
      expect(justUnder.passesAaLarge, isTrue);
    });

    test('the maximum ratio passes every level', () {
      const best = ContrastReport(ratio: maxContrastRatio);
      expect(best.passesAaNormal, isTrue);
      expect(best.passesAaLarge, isTrue);
      expect(best.passesAaaNormal, isTrue);
      expect(best.passesAaaLarge, isTrue);
    });

    test('the minimum ratio fails every level', () {
      const worst = ContrastReport(ratio: minContrastRatio);
      expect(worst.passesAaNormal, isFalse);
      expect(worst.passesAaLarge, isFalse);
      expect(worst.passesAaaNormal, isFalse);
      expect(worst.passesAaaLarge, isFalse);
    });

    test('supports value equality and a readable toString', () {
      const a = ContrastReport(ratio: 4.5);
      const b = ContrastReport(ratio: 4.5);
      const c = ContrastReport(ratio: 7);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a.toString(), 'ContrastReport(ratio: 4.50)');
    });
  });

  group('evaluateContrast', () {
    test('reports the maximum for black text on white', () {
      final report = evaluateContrast(black, white);
      expect(report.ratio, closeTo(maxContrastRatio, 1e-9));
      expect(report.passesAaaNormal, isTrue);
    });

    test('flattens a translucent foreground before measuring', () {
      const halfBlack = WcagColor.from(alpha: 0.5, red: 0, green: 0, blue: 0);
      final translucent = evaluateContrast(halfBlack, white);
      final opaqueGrey = evaluateContrast(
        const WcagColor.from(alpha: 1, red: 0.5, green: 0.5, blue: 0.5),
        white,
      );
      // A 50% black over white is exactly mid-grey, so the ratios match.
      expect(translucent.ratio, closeTo(opaqueGrey.ratio, 1e-9));
      // And it is a weaker contrast than solid black on white.
      expect(translucent.ratio, lessThan(maxContrastRatio));
    });
  });
}

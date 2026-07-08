// wcag_vision example
//
// A single-screen demo of the package's three capabilities:
//
// 1. CONTRAST — `evaluateContrast` on two hardcoded colour pairs: dark
//    body text on white (a realistic pass) and light placeholder grey on
//    white (a realistic fail). Shows the computed ratio and AA/AAA
//    pass/fail badges for normal and large text.
//
// 2. CVD SIMULATION — a small fixed palette rendered as swatches, with a
//    dropdown that re-renders every swatch through `simulateCvd` for the
//    selected deficiency (none / protanopia / deuteranopia / tritanopia).
//
// 3. EXTRACTION — decodes the bundled `assets/sample.png` (an original,
//    programmatically generated 64x64 image of four flat colour bars —
//    see the comment on _extractFromSampleAsset) into pixels and runs
//    `extractDominantColorsAsync` on them, displaying the dominant
//    colours with their share percentages.
//
// The UI is intentionally plain Material — this is a functional demo of
// the package API for pub.dev's example tab, not a product.
//
// wcag_vision is a pure-Dart package with no Flutter dependency (see its
// README), so it has its own WcagColor type rather than using dart:ui's
// Color. This example imports the package with a `wcag` prefix and
// converts between the two colour types at the UI boundary with
// _toWcagColor/_toFlutterColor below — exactly the one-line conversion a
// consuming Flutter app is expected to do.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:wcag_vision/wcag_vision.dart' as wcag;

void main() => runApp(const WcagVisionExampleApp());

/// Converts a Flutter [Color] to the package's [wcag.WcagColor].
wcag.WcagColor _toWcagColor(Color color) => wcag.WcagColor.from(
      alpha: color.a,
      red: color.r,
      green: color.g,
      blue: color.b,
    );

/// Converts a [wcag.WcagColor] to a Flutter [Color].
Color _toFlutterColor(wcag.WcagColor color) => Color.from(
      alpha: color.a,
      red: color.r,
      green: color.g,
      blue: color.b,
    );

/// Root widget of the example app.
class WcagVisionExampleApp extends StatelessWidget {
  /// Creates the example app.
  const WcagVisionExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'wcag_vision example',
      home: DemoScreen(),
    );
  }
}

/// The single screen hosting the three demo sections.
class DemoScreen extends StatefulWidget {
  /// Creates the demo screen.
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  // Local, presentation-only state: which deficiency the CVD section
  // renders. No business logic lives here, so plain setState is fine.
  wcag.CvdType _cvdType = wcag.CvdType.none;

  late final Future<List<wcag.ExtractedColor>> _extraction =
      _extractFromSampleAsset();

  /// Decodes the bundled sample image into pixels and extracts its
  /// dominant colours off the main isolate.
  ///
  /// `assets/sample.png` is an original asset generated programmatically
  /// for this example (a Python stdlib script in the repo's history — no
  /// external image source): a 64x64 PNG of four vertical flat-colour
  /// bars (navy / teal / amber / cream) with deliberately unequal widths,
  /// so the extracted shares are visibly different.
  Future<List<wcag.ExtractedColor>> _extractFromSampleAsset() async {
    final data = await rootBundle.load('assets/sample.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(); // defaults to raw RGBA 8888
    frame.image.dispose();
    final rgba = byteData!;
    final pixels = <wcag.WcagColor>[
      for (var i = 0; i < rgba.lengthInBytes; i += 4)
        _toWcagColor(
          Color.fromARGB(
            rgba.getUint8(i + 3),
            rgba.getUint8(i),
            rgba.getUint8(i + 1),
            rgba.getUint8(i + 2),
          ),
        ),
    ];
    return wcag.extractDominantColorsAsync(pixels, k: 4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('wcag_vision example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('1. Contrast (evaluateContrast)'),
          const _ContrastDemo(
            label: 'Dark text on white',
            foreground: Color(0xFF1F2937),
            background: Color(0xFFFFFFFF),
          ),
          const SizedBox(height: 8),
          const _ContrastDemo(
            label: 'Light grey placeholder on white',
            foreground: Color(0xFF9CA3AF),
            background: Color(0xFFFFFFFF),
          ),
          const Divider(height: 32),
          const _SectionTitle('2. CVD simulation (simulateCvd)'),
          DropdownButton<wcag.CvdType>(
            value: _cvdType,
            onChanged: (type) =>
                setState(() => _cvdType = type ?? wcag.CvdType.none),
            items: [
              for (final type in wcag.CvdType.values)
                DropdownMenuItem(value: type, child: Text(type.name)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final color in _palette) ...[
                _Swatch(
                  color: _toFlutterColor(
                    wcag.simulateCvd(_toWcagColor(color), _cvdType),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const Divider(height: 32),
          const _SectionTitle(
            '3. Dominant colours (extractDominantColorsAsync)',
          ),
          Row(
            children: [
              Image.asset(
                'assets/sample.png',
                width: 64,
                height: 64,
                filterQuality: FilterQuality.none,
              ),
              const SizedBox(width: 16),
              const Text('sample.png (64x64)'),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<wcag.ExtractedColor>>(
            future: _extraction,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Extraction failed: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Row(
                children: [
                  for (final extracted in snapshot.data!) ...[
                    Column(
                      children: [
                        _Swatch(color: _toFlutterColor(extracted.color)),
                        Text(
                          '${(extracted.share * 100).toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A fixed demo palette for the CVD section: colours chosen so red–green
/// and blue–yellow deficiencies each produce a visible change.
const List<Color> _palette = [
  Color(0xFFE53935), // red
  Color(0xFFFB8C00), // orange
  Color(0xFF43A047), // green
  Color(0xFF1E88E5), // blue
  Color(0xFF8E24AA), // purple
];

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// One contrast check row: colour preview, computed ratio, and pass/fail
/// badges for the AA/AAA thresholds.
class _ContrastDemo extends StatelessWidget {
  const _ContrastDemo({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final report = wcag.evaluateContrast(
      _toWcagColor(foreground),
      _toWcagColor(background),
    );
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: Colors.black26),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Aa', style: TextStyle(color: foreground)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label — ${report.ratio.toStringAsFixed(2)}:1'),
              Wrap(
                spacing: 6,
                children: [
                  _PassBadge('AA', passes: report.passesAaNormal),
                  _PassBadge('AA large', passes: report.passesAaLarge),
                  _PassBadge('AAA', passes: report.passesAaaNormal),
                  _PassBadge('AAA large', passes: report.passesAaaLarge),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small pass/fail chip, e.g. "AA ✓" in green or "AAA ✗" in red.
class _PassBadge extends StatelessWidget {
  const _PassBadge(this.label, {required this.passes});

  final String label;
  final bool passes;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: passes ? Colors.green.shade100 : Colors.red.shade100,
      label: Text('$label ${passes ? '✓' : '✗'}'),
    );
  }
}

/// A fixed-size colour square.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: ColoredBox(color: color),
    );
  }
}

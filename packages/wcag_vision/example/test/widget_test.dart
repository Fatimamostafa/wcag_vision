import 'package:flutter_test/flutter_test.dart';
import 'package:wcag_vision_example/main.dart';

void main() {
  testWidgets('renders all three demo sections without throwing',
      (tester) async {
    await tester.pumpWidget(const WcagVisionExampleApp());

    // The extraction section spawns a real isolate (Isolate.run); Flutter's
    // synchronous pump cycle doesn't drive genuine async I/O like that
    // (and the indeterminate CircularProgressIndicator it shows while
    // waiting would make pumpAndSettle spin forever), so wait for it via
    // runAsync before pumping the resulting frame.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.text('1. Contrast (evaluateContrast)'), findsOneWidget);
    expect(find.text('2. CVD simulation (simulateCvd)'), findsOneWidget);
    expect(
      find.text('3. Dominant colours (extractDominantColorsAsync)'),
      findsOneWidget,
    );
  });
}

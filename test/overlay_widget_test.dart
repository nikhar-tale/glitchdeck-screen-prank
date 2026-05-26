import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_prank_app/overlay_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PrankOverlayWidget rendering and dynamic config stream updates', (WidgetTester tester) async {
    // Set a portrait screen size for overlay verification
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          color: Colors.transparent,
          child: PrankOverlayWidget(),
        ),
      ),
    );
    await tester.pump();

    // 1. Assert initial state renders the components (custom painters & assets)
    // CustomPaint is used for: flicker overlay, stuck pixels, green lines, fallback crack (if asset missing)
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(2));
    
    // OLED Crack image (Image.asset) should be present
    expect(find.byType(Image), findsOneWidget);

    // 2. Simulate sending configuration updates from the dashboard via basic message channel
    const codec = JSONMessageCodec();
    final messageData = codec.encodeMessage({
      'crack': false,
      'greenLines': false,
      'flicker': true,
      'deadPixels': true,
    });

    // Send platform message to the background engine basic message channel
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      'x-slayer/overlay_messenger',
      messageData,
      (ByteData? data) {},
    );

    // Re-pump widget to trigger build updates from state changes
    await tester.pump();

    // 3. Verify that the crack image and green lines have been removed
    expect(find.byType(Image), findsNothing);
    
    // Flicker & Dead pixels CustomPaint layers should still remain
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });
}

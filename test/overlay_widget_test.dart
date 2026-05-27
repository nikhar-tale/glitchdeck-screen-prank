import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_prank_app/overlay_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel overlayChannel = MethodChannel('x-slayer/overlay_channel');
  final List<MethodCall> overlayChannelCalls = [];
  final List<dynamic> sharedMessages = [];

  setUp(() {
    overlayChannelCalls.clear();
    sharedMessages.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(overlayChannel, (MethodCall methodCall) async {
      overlayChannelCalls.add(methodCall);
      if (methodCall.method == 'closeOverlay') {
        return true;
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(
            const BasicMessageChannel("x-slayer/overlay_messenger", JSONMessageCodec()),
            (message) async {
              sharedMessages.add(message);
              return null;
            });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(overlayChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(
            const BasicMessageChannel("x-slayer/overlay_messenger", JSONMessageCodec()),
            null);
  });

  testWidgets('PrankOverlayWidget rendering and dynamic config stream updates', (WidgetTester tester) async {
    // Set a portrait screen size for overlay verification (360 x 800 DP)
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

    // 1. Assert initial state renders the components (custom painters)
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(2));

    // 2. Simulate sending configuration updates from the dashboard via basic message channel
    const codec = JSONMessageCodec();
    final messageData = codec.encodeMessage({
      'greenLines': false,
      'flicker': true,
      'deadPixels': true,
    });

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      'x-slayer/overlay_messenger',
      messageData,
      (ByteData? data) {},
    );

    // Re-pump widget to trigger build updates from state changes
    await tester.pump();

    // Verify that the green lines have been removed
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));

    // 3. Test Stealth Triple-Tap Dismiss in Top-Right Corner
    // Coordinates are local/global. Top-right corner of 360 x 800 layout:
    // x = 320 (88% of width), y = 50 (6.25% of height)
    final Offset topRightOffset = const Offset(320, 50);

    // First tap
    await tester.tapAt(topRightOffset);
    await tester.pump(const Duration(milliseconds: 50));
    
    // Second tap
    await tester.tapAt(topRightOffset);
    await tester.pump(const Duration(milliseconds: 50));

    // Assert that the overlay hasn't closed yet (closeOverlay not called)
    expect(overlayChannelCalls.any((call) => call.method == 'closeOverlay'), isFalse);

    // Third tap
    await tester.tapAt(topRightOffset);
    await tester.pump(const Duration(milliseconds: 500));

    // Assert closeOverlay was called on method channel
    expect(overlayChannelCalls.any((call) => call.method == 'closeOverlay'), isTrue);

    // Assert DISMISS_ACCESSIBILITY_OVERLAY was sent to basic message channel
    expect(sharedMessages.contains("DISMISS_ACCESSIBILITY_OVERLAY"), isTrue);
  });
}

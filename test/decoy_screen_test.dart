import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_prank_app/decoy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel overlayChannel = MethodChannel('x-slayer/overlay_channel');
  const MethodChannel accessibilityChannel = MethodChannel('com.prank.screen/accessibility');
  const MethodChannel platformChannel = SystemChannels.platform;

  final List<MethodCall> platformChannelCalls = [];

  setUp(() {
    platformChannelCalls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(overlayChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'checkPermission':
          return false;
        case 'isOverlayActive':
          return false;
        default:
          return null;
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(accessibilityChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'isAccessibilityEnabled':
          return false;
        case 'isOverlayActive':
          return false;
        default:
          return null;
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (MethodCall methodCall) async {
      platformChannelCalls.add(methodCall);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(overlayChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(accessibilityChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, null);
  });

  testWidgets('Part 4: Decoy Screen Interactive Digitizer and Stress Test Sweeps', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DecoyScreen(),
      ),
    );
    await tester.pump();

    // 1. Verify SMPTE Color bar calibration elements are present
    expect(find.text('SMPTE Color Bar Calibration Pattern'), findsOneWidget);
    expect(find.text('HARDWARE DISPLAY SPECS'), findsOneWidget);

    // 2. Interactive Digitizer Touch Grid Test
    final ch3Finder = find.text('CH 3');
    expect(ch3Finder, findsOneWidget);
    
    // Tap the digitizer cell
    await tester.ensureVisible(ch3Finder);
    await tester.tap(ch3Finder);
    await tester.pump();

    // Verify selectionClick haptic is called
    expect(
      platformChannelCalls.any(
        (call) => call.method == 'HapticFeedback.vibrate' && call.arguments == 'HapticFeedbackType.selectionClick',
      ),
      isTrue,
    );
    platformChannelCalls.clear();

    // 3. Refresh Rate Stress Test
    expect(find.text('STRESS TEST STANDBY'), findsOneWidget);
    
    final stressButtonFinder = find.text('START STRESS TEST');
    expect(stressButtonFinder, findsOneWidget);

    // Start Stress Test
    await tester.ensureVisible(stressButtonFinder);
    await tester.tap(stressButtonFinder);
    await tester.pump();

    // Verify mediumImpact haptic is called
    expect(
      platformChannelCalls.any(
        (call) => call.method == 'HapticFeedback.vibrate' && call.arguments == 'HapticFeedbackType.mediumImpact',
      ),
      isTrue,
    );
    platformChannelCalls.clear();

    expect(find.text('STRESS TESTING IN PROGRESS...'), findsOneWidget);
    expect(find.text('STOP STRESS TEST'), findsOneWidget);

    // Check timer ticking shifts offset
    await tester.pump(const Duration(milliseconds: 32));

    // Stop Stress Test
    final stopButtonFinder = find.text('STOP STRESS TEST');
    await tester.ensureVisible(stopButtonFinder);
    await tester.tap(stopButtonFinder);
    await tester.pump();

    // Verify mediumImpact haptic is called again on stop
    expect(
      platformChannelCalls.any(
        (call) => call.method == 'HapticFeedback.vibrate' && call.arguments == 'HapticFeedbackType.mediumImpact',
      ),
      isTrue,
    );

    expect(find.text('STRESS TEST STANDBY'), findsOneWidget);
    expect(find.text('START STRESS TEST'), findsOneWidget);
  });

  testWidgets('Part 4: Decoy Title Tap Reset Timeout Logic', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DecoyScreen(),
      ),
    );
    await tester.pump();

    final titleFinder = find.text('DISPLAY CALIBRATOR');

    // 1. Tap 3 times (less than the required 5)
    for (int i = 0; i < 3; i++) {
      await tester.tap(titleFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 2. Wait for 3.5 seconds (the reset timer is set to 3 seconds)
    await tester.pump(const Duration(milliseconds: 3500));

    // 3. Tap 2 more times (total 5 taps, but split by timeout)
    for (int i = 0; i < 2; i++) {
      await tester.tap(titleFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 4. Assert we are still on the Decoy screen and NOT navigated to GlitchDeck
    expect(find.text('DISPLAY CALIBRATOR'), findsOneWidget);
    expect(find.text('GLITCHDECK'), findsNothing);

    // 5. Pump a clean DecoyScreen instance to reset state
    await tester.pumpWidget(
      const MaterialApp(
        home: DecoyScreen(),
      ),
    );
    await tester.pump();
    platformChannelCalls.clear();

    // 6. Tap 5 times within time limit (without long delay) on clean state
    final cleanTitleFinder = find.text('DISPLAY CALIBRATOR');
    for (int i = 0; i < 5; i++) {
      await tester.tap(cleanTitleFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
    }
    
    // Wait for route navigation animation to settle
    await tester.pump(const Duration(milliseconds: 500));

    // Verify haptics were triggered
    expect(
      platformChannelCalls.any(
        (call) => call.method == 'HapticFeedback.vibrate' && call.arguments == 'HapticFeedbackType.lightImpact',
      ),
      isTrue,
    );
    expect(
      platformChannelCalls.any(
        (call) => call.method == 'HapticFeedback.vibrate' && call.arguments == null,
      ),
      isTrue,
    );

    // 7. Assert we have navigated to the Dashboard
    expect(find.text('GLITCHDECK'), findsOneWidget);
  });
}

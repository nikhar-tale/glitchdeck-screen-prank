import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_prank_app/decoy_screen.dart';
import 'package:screen_prank_app/dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel overlayChannel = MethodChannel('x-slayer/overlay_channel');
  const MethodChannel accessibilityChannel = MethodChannel('com.prank.screen/accessibility');
  const MethodChannel platformChannel = SystemChannels.platform;

  final List<MethodCall> overlayChannelCalls = [];
  final List<MethodCall> accessibilityChannelCalls = [];
  final List<MethodCall> platformChannelCalls = [];

  bool isOverlayPermissionGranted = false;
  bool isOverlayActive = false;
  bool isAccessibilityEnabled = false;
  bool isAccessibilityOverlayActive = false;

  // Track shared data messages
  final List<dynamic> sharedDataMessages = [];

  setUp(() {
    overlayChannelCalls.clear();
    accessibilityChannelCalls.clear();
    platformChannelCalls.clear();
    sharedDataMessages.clear();

    isOverlayPermissionGranted = false;
    isOverlayActive = false;
    isAccessibilityEnabled = false;
    isAccessibilityOverlayActive = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(overlayChannel, (MethodCall methodCall) async {
      overlayChannelCalls.add(methodCall);
      switch (methodCall.method) {
        case 'checkPermission':
          return isOverlayPermissionGranted;
        case 'isOverlayActive':
          return isOverlayActive;
        case 'requestPermission':
          isOverlayPermissionGranted = true;
          return null;
        case 'showOverlay':
          isOverlayActive = true;
          return null;
        case 'closeOverlay':
          isOverlayActive = false;
          return null;
        default:
          return null;
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(accessibilityChannel, (MethodCall methodCall) async {
      accessibilityChannelCalls.add(methodCall);
      switch (methodCall.method) {
        case 'isAccessibilityEnabled':
          return isAccessibilityEnabled;
        case 'isOverlayActive':
          return isAccessibilityOverlayActive;
        case 'openAccessibilitySettings':
          isAccessibilityEnabled = true;
          return true;
        case 'startAccessibilityOverlay':
          isAccessibilityOverlayActive = true;
          return true;
        case 'stopAccessibilityOverlay':
          isAccessibilityOverlayActive = false;
          return true;
        default:
          return null;
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (MethodCall methodCall) async {
      platformChannelCalls.add(methodCall);
      return null;
    });

    // Mock BasicMessageChannel for shareData
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(
            const BasicMessageChannel("x-slayer/overlay_messenger", JSONMessageCodec()),
            (message) async {
              sharedDataMessages.add(message);
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(
            const BasicMessageChannel("x-slayer/overlay_messenger", JSONMessageCodec()),
            null);
  });

  testWidgets('Decoy Screen flows and hidden title-tap navigation to GlitchDeck', (WidgetTester tester) async {
    // Set virtual screen size to typical portrait mobile device dimensions
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            debugPrint("TEST LOGICAL SCREEN SIZE: ${MediaQuery.of(context).size}");
            return const DecoyScreen();
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Verify Decoy screen title and elements render correctly
    expect(find.text('DISPLAY CALIBRATOR'), findsOneWidget);
    expect(find.text('SMPTE Color Bar Calibration Pattern'), findsOneWidget);
    expect(find.text('AMOLED / OLED Active Matrix'), findsOneWidget);

    // 2. Perform 5 taps on the title to unlock the console
    final titleFinder = find.text('DISPLAY CALIBRATOR');
    for (int i = 0; i < 5; i++) {
      await tester.tap(titleFinder);
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Wait for route transition animation to finish
    await tester.pump(const Duration(milliseconds: 500));

    // 3. Verify we have navigated to the secret GLITCHDECK dashboard
    expect(find.text('GLITCHDECK'), findsOneWidget);
    expect(find.text('GLITCH ENGINE PROTOCOL // v1.0.4'), findsOneWidget);

    // 4. Verify initial permission warning box is shown (since disabled initially)
    expect(find.textContaining('Draw-over permission required'), findsOneWidget);

    // 5. Verify Phone Preview Mockup is rendered
    expect(find.byType(PhonePreviewMockup), findsOneWidget);

    // Tap GRANT ACCESS / AUTHORIZE SYSTEM DRAW button (triggers mock settings grant)
    await tester.tap(find.text('AUTHORIZE SYSTEM DRAW'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify warning banner disappears
    expect(find.textContaining('Draw-over permission required'), findsNothing);

    debugPrint("=== ACTIVE WIDGET TREE DUMP ===");
    debugPrint(tester.binding.renderViewElement?.toStringDeep());
    debugPrint("===============================");

    // 6. Select delay option "3 Seconds Delay"
    final dropdownFinder = find.byKey(const Key('delay_dropdown'));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(dropdownFinder);
    await tester.pump(const Duration(milliseconds: 500));
    platformChannelCalls.clear();
    await tester.tap(find.text('3 Seconds Delay').last);
    await tester.pump(const Duration(milliseconds: 500));
    // Verify selectionClick haptic is called when selecting dropdown option
    expect(
      platformChannelCalls.any(
        (call) => call.method == 'HapticFeedback.vibrate' && call.arguments == 'HapticFeedbackType.selectionClick',
      ),
      isTrue,
    );
    expect(find.text('3 Seconds Delay'), findsOneWidget);

    // 7. Verify Standard Mode triggers standard overlay showOverlay after delay
    platformChannelCalls.clear();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(); // Start countdown

    // Verify heavyImpact haptic on execute trigger
    expect(
      platformChannelCalls.any(
        (call) => call.method == 'HapticFeedback.vibrate' && call.arguments == 'HapticFeedbackType.heavyImpact',
      ),
      isTrue,
    );
    platformChannelCalls.clear();

    // Verify countdown ticks down
    expect(find.text('DISRUPT IN: 3 SECONDS'), findsOneWidget);
    expect(overlayChannelCalls.any((call) => call.method == 'showOverlay'), isFalse);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('DISRUPT IN: 2 SECONDS'), findsOneWidget);
    // Verify tick vibrate
    expect(
      platformChannelCalls.any(
        (call) => call.method == 'HapticFeedback.vibrate' && call.arguments == null,
      ),
      isTrue,
    );
    platformChannelCalls.clear();

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('DISRUPT IN: 1 SECONDS'), findsOneWidget);

    // Final second tick launches overlay
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(overlayChannelCalls.any((call) => call.method == 'showOverlay'), isTrue);
    expect(find.text('DISMISS GLITCH'), findsOneWidget);

    // Tap DISMISS GLITCH
    platformChannelCalls.clear();
    await tester.tap(find.text('DISMISS GLITCH'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(overlayChannelCalls.any((call) => call.method == 'closeOverlay'), isTrue);
    // Verify selectionClick haptic is called when stopping prank
    expect(
      platformChannelCalls.any(
        (call) => call.method == 'HapticFeedback.vibrate' && call.arguments == 'HapticFeedbackType.selectionClick',
      ),
      isTrue,
    );

    // 8. Test cancel countdown
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.text('DISRUPT IN: 3 SECONDS'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('DISRUPT IN: 2 SECONDS'), findsOneWidget);

    platformChannelCalls.clear();
    await tester.tap(find.text('ABORT LAUNCH'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('DISRUPT IN'), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    // Verify selectionClick haptic is called when aborting
    expect(
      platformChannelCalls.any(
        (call) => call.method == 'HapticFeedback.vibrate' && call.arguments == 'HapticFeedbackType.selectionClick',
      ),
      isTrue,
    );

    // 9. Switch to Advanced Mode
    platformChannelCalls.clear();
    await tester.tap(find.text('ADVANCED MODE'));
    await tester.pump(const Duration(milliseconds: 500));
    // Verify selectionClick haptic is called when switching modes
    expect(
      platformChannelCalls.any(
        (call) => call.method == 'HapticFeedback.vibrate' && call.arguments == 'HapticFeedbackType.selectionClick',
      ),
      isTrue,
    );

    // Verify accessibility permission warning is shown
    expect(find.textContaining('Accessibility permission required'), findsOneWidget);

    // Tap GRANT ACCESS
    platformChannelCalls.clear();
    await tester.tap(find.text('GRANT ACCESS'));
    await tester.pump(const Duration(milliseconds: 500));
    // Verify mediumImpact haptic is called when requesting permission
    expect(
      platformChannelCalls.any(
        (call) => call.method == 'HapticFeedback.vibrate' && call.arguments == 'HapticFeedbackType.mediumImpact',
      ),
      isTrue,
    );
    expect(find.textContaining('Accessibility permission required'), findsNothing);

    // 10. Test Switch toggles state updates
    accessibilityChannelCalls.clear();

    // Toggle off "Green OLED Lines"
    final greenLinesSwitchRow = find.ancestor(
      of: find.text('Green OLED Lines'),
      matching: find.byType(Row),
    );
    final greenLinesSwitch = find.descendant(
      of: greenLinesSwitchRow,
      matching: find.byType(Switch),
    );
    await tester.tap(greenLinesSwitch);
    await tester.pump(const Duration(milliseconds: 500));

    // Switch delay back to "Instant (Disrupt Now)"
    final dropdownFinder2 = find.byKey(const Key('delay_dropdown'));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(dropdownFinder2);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Instant (Disrupt Now)').last);
    await tester.pump(const Duration(milliseconds: 500));

    // Tap EXECUTE DISRUPTION
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify startAccessibilityOverlay is called with config
    expect(accessibilityChannelCalls.any((call) => call.method == 'startAccessibilityOverlay'), isTrue);
    final startCall = accessibilityChannelCalls.firstWhere((call) => call.method == 'startAccessibilityOverlay');
    expect(startCall.arguments['greenLines'], isFalse);
    expect(startCall.arguments['flicker'], isTrue);
    expect(startCall.arguments['deadPixels'], isTrue);

    // Tap DISMISS GLITCH
    await tester.tap(find.text('DISMISS GLITCH'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(accessibilityChannelCalls.any((call) => call.method == 'stopAccessibilityOverlay'), isTrue);
  });

  testWidgets('Part 6: App Lifecycle Permission State Syncing', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    isOverlayPermissionGranted = false;
    isAccessibilityEnabled = false;

    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Verify warning box is shown initially
    expect(find.textContaining('Draw-over permission required'), findsOneWidget);

    // 2. Change permission mock to granted (as if user enabled it in system settings)
    isOverlayPermissionGranted = true;

    // 3. Trigger app lifecycle state change to resumed
    overlayChannelCalls.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));

    // 4. Verify checkPermission was invoked and warning banner is gone
    expect(overlayChannelCalls.any((call) => call.method == 'checkPermission'), isTrue);
    expect(find.textContaining('Draw-over permission required'), findsNothing);

    // 5. Switch to Advanced Mode
    await tester.tap(find.text('ADVANCED MODE'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Accessibility permission required'), findsOneWidget);

    // 6. Change accessibility permission mock to enabled
    isAccessibilityEnabled = true;

    // 7. Trigger app lifecycle state change to resumed again
    accessibilityChannelCalls.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));

    // 8. Verify isAccessibilityEnabled was checked and warning banner is gone
    expect(accessibilityChannelCalls.any((call) => call.method == 'isAccessibilityEnabled'), isTrue);
    expect(find.textContaining('Accessibility permission required'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_prank_app/dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel overlayChannel = MethodChannel('x-slayer/overlay_channel');
  const MethodChannel accessibilityChannel = MethodChannel('com.prank.screen/accessibility');

  final List<MethodCall> overlayChannelCalls = [];
  final List<MethodCall> accessibilityChannelCalls = [];

  // Start with permissions disabled to verify dynamic UI warnings
  bool isOverlayPermissionGranted = false;
  bool isOverlayActive = false;
  bool isAccessibilityEnabled = false;
  bool isAccessibilityOverlayActive = false;

  setUp(() {
    overlayChannelCalls.clear();
    accessibilityChannelCalls.clear();

    // Setup MethodChannel mock handler
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
          return true;
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
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(overlayChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(accessibilityChannel, null);
  });

  testWidgets('Dashboard UI flows and platform channel verification', (WidgetTester tester) async {
    // Set virtual screen size to typical portrait mobile device dimensions
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify header title and toggles render correctly
    expect(find.text('SCREEN PRANK'), findsOneWidget);
    expect(find.text('STANDARD MODE'), findsOneWidget);
    expect(find.text('ADVANCED MODE'), findsOneWidget);
    expect(find.text('OLED Crack & Ink Bleed'), findsOneWidget);
    expect(find.text('Green OLED Lines'), findsOneWidget);

    // 2. Verify standard permission warning box is shown initially
    expect(find.textContaining('Overlay permission is required'), findsOneWidget);

    // Tap GRANT PERMISSION (triggers mock settings grant)
    await tester.tap(find.text('GRANT PERMISSION'));
    await tester.pumpAndSettle();

    // Verify warning banner disappears
    expect(find.textContaining('Overlay permission is required'), findsNothing);

    // 3. Select instant delay (value 0)
    await tester.tap(find.text('5 Seconds Delay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Instant (Activate Now)').last);
    await tester.pumpAndSettle();
    expect(find.text('Instant (Activate Now)'), findsOneWidget);

    // 4. Verify Standard Mode triggers standard overlay
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    // Verify showOverlay method is called on platform channel
    expect(overlayChannelCalls.any((call) => call.method == 'showOverlay'), isTrue);
    expect(find.text('STOP PRANK'), findsOneWidget);

    // Tap STOP PRANK
    await tester.tap(find.text('STOP PRANK'));
    await tester.pumpAndSettle();

    // Verify closeOverlay method is called
    expect(overlayChannelCalls.any((call) => call.method == 'closeOverlay'), isTrue);

    // 5. Switch to Advanced Mode
    await tester.tap(find.text('ADVANCED MODE'));
    await tester.pumpAndSettle();

    // Verify accessibility permission warning is shown
    expect(find.textContaining('Accessibility service permission is required'), findsOneWidget);

    // Tap ENABLE ACCESSIBILITY (triggers mock settings grant)
    await tester.tap(find.text('ENABLE ACCESSIBILITY'));
    await tester.pumpAndSettle();

    // Verify warning banner disappears
    expect(find.textContaining('Accessibility service permission is required'), findsNothing);

    // Tap ACTIVATE PRANK in Advanced Mode
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    // Verify startAccessibilityOverlay is called on custom channel
    expect(accessibilityChannelCalls.any((call) => call.method == 'startAccessibilityOverlay'), isTrue);

    // Verify arguments passed to accessibility service
    final startCall = accessibilityChannelCalls.firstWhere((call) => call.method == 'startAccessibilityOverlay');
    expect(startCall.arguments['crack'], isTrue);
    expect(startCall.arguments['greenLines'], isTrue);

    // Tap STOP PRANK in Advanced Mode
    await tester.tap(find.text('STOP PRANK'));
    await tester.pumpAndSettle();

    // Verify stopAccessibilityOverlay is called
    expect(accessibilityChannelCalls.any((call) => call.method == 'stopAccessibilityOverlay'), isTrue);

    // ==========================================
    // PART 3: Advanced Test Cases (Toggles, Countdown, and Cancel)
    // ==========================================

    // 1. Test Switch toggles state updates and configurations propagation
    accessibilityChannelCalls.clear();

    // Find and toggle off "OLED Crack & Ink Bleed"
    final crackSwitchRow = find.ancestor(
      of: find.text('OLED Crack & Ink Bleed'),
      matching: find.byType(Row),
    );
    final crackSwitch = find.descendant(
      of: crackSwitchRow,
      matching: find.byType(Switch),
    );
    await tester.tap(crackSwitch);
    await tester.pumpAndSettle();

    // Find and toggle off "Green OLED Lines"
    final greenLinesSwitchRow = find.ancestor(
      of: find.text('Green OLED Lines'),
      matching: find.byType(Row),
    );
    final greenLinesSwitch = find.descendant(
      of: greenLinesSwitchRow,
      matching: find.byType(Switch),
    );
    await tester.tap(greenLinesSwitch);
    await tester.pumpAndSettle();

    // Tap ACTIVATE PRANK in Advanced Mode with toggled settings
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    // Verify startAccessibilityOverlay is called with crack: false and greenLines: false
    expect(accessibilityChannelCalls.any((call) => call.method == 'startAccessibilityOverlay'), isTrue);
    final customStartCall = accessibilityChannelCalls.firstWhere((call) => call.method == 'startAccessibilityOverlay');
    expect(customStartCall.arguments['crack'], isFalse);
    expect(customStartCall.arguments['greenLines'], isFalse);
    expect(customStartCall.arguments['flicker'], isTrue);
    expect(customStartCall.arguments['deadPixels'], isTrue);

    // Tap STOP PRANK
    await tester.tap(find.text('STOP PRANK'));
    await tester.pumpAndSettle();

    // Toggle them back on to restore defaults for the next test steps
    await tester.tap(crackSwitch);
    await tester.pumpAndSettle();
    await tester.tap(greenLinesSwitch);
    await tester.pumpAndSettle();

    // 2. Test Countdown delay timer ticking sequentially
    // Select "3 Seconds Delay" from dropdown
    await tester.tap(find.text('Instant (Activate Now)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 Seconds Delay').last);
    await tester.pumpAndSettle();
    expect(find.text('3 Seconds Delay'), findsOneWidget);

    accessibilityChannelCalls.clear();

    // Tap ACTIVATE PRANK
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(); // Advance to start the countdown

    // Verify countdown UI shows 3 seconds remaining and overlay not active
    expect(find.text('Prank starts in: 3'), findsOneWidget);
    expect(accessibilityChannelCalls.any((call) => call.method == 'startAccessibilityOverlay'), isFalse);

    // Pump 1 second -> 2 seconds remaining
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Prank starts in: 2'), findsOneWidget);
    expect(accessibilityChannelCalls.any((call) => call.method == 'startAccessibilityOverlay'), isFalse);

    // Pump 1 second -> 1 second remaining
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Prank starts in: 1'), findsOneWidget);
    expect(accessibilityChannelCalls.any((call) => call.method == 'startAccessibilityOverlay'), isFalse);

    // Pump 1 second -> Countdown finished, overlay should launch
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(accessibilityChannelCalls.any((call) => call.method == 'startAccessibilityOverlay'), isTrue);
    expect(find.text('STOP PRANK'), findsOneWidget);

    // Tap STOP PRANK
    await tester.tap(find.text('STOP PRANK'));
    await tester.pumpAndSettle();

    // 3. Test Cancelling active countdown timer
    accessibilityChannelCalls.clear();

    // Tap ACTIVATE PRANK (starts countdown with the selected 3 seconds delay)
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(find.text('Prank starts in: 3'), findsOneWidget);

    // Pump 1 second -> 2 seconds remaining
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Prank starts in: 2'), findsOneWidget);

    // Tap CANCEL TIMER
    await tester.tap(find.text('CANCEL TIMER'));
    await tester.pumpAndSettle();

    // Verify timer is canceled, UI returns to main controls, and overlay is not shown
    expect(find.textContaining('Prank starts in'), findsNothing);
    expect(accessibilityChannelCalls.any((call) => call.method == 'startAccessibilityOverlay'), isFalse);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  static const _accessibilityChannel = MethodChannel('com.prank.screen/accessibility');

  // Prank state variables
  bool _crackEnabled = true;
  bool _greenLinesEnabled = true;
  bool _flickerEnabled = true;
  bool _deadPixelsEnabled = true;

  // Mode state
  bool _advancedMode = false; // False = Standard, True = Accessibility (locks & quick settings persistent)

  // System states
  bool _permissionGranted = false;
  bool _overlayActive = false;
  bool _isCountingDown = false;
  int _countdownSeconds = 5; // Default delay
  int _secondsRemaining = 0;
  Timer? _countdownTimer;
  StreamSubscription? _listenerSubscription;

  // Selected timer options
  final List<int> _delayOptions = [0, 3, 5, 10, 20, 30];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionAndState();

    // Listen to messages from the overlay (e.g. handshake requests)
    _listenerSubscription = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == "OVERLAY_READY") {
        // Send initial configurations when overlay announces it is running
        _syncConfigToOverlay();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-verify permission status when returning to the app
      _checkPermissionAndState();
    }
  }

  Future<void> _checkPermissionAndState() async {
    try {
      if (_advancedMode) {
        final enabled = await _accessibilityChannel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
        final active = await _accessibilityChannel.invokeMethod<bool>('isOverlayActive') ?? false;
        setState(() {
          _permissionGranted = enabled;
          _overlayActive = active;
        });
      } else {
        final granted = await FlutterOverlayWindow.isPermissionGranted();
        final active = await FlutterOverlayWindow.isActive();
        setState(() {
          _permissionGranted = granted;
          _overlayActive = active;
        });
      }
    } catch (e) {
      debugPrint("Error checking permission/state: $e");
    }
  }

  Future<void> _requestPermission() async {
    try {
      if (_advancedMode) {
        await _accessibilityChannel.invokeMethod('openAccessibilitySettings');
      } else {
        await FlutterOverlayWindow.requestPermission();
      }
    } catch (e) {
      debugPrint("Error requesting permission: $e");
    }
    await _checkPermissionAndState();
  }

  void _syncConfigToOverlay() {
    FlutterOverlayWindow.shareData({
      'crack': _crackEnabled,
      'greenLines': _greenLinesEnabled,
      'flicker': _flickerEnabled,
      'deadPixels': _deadPixelsEnabled,
    });
  }

  void _startPrankWorkflow() async {
    // 1. Re-verify the permission status dynamically right now
    await _checkPermissionAndState();

    if (!_permissionGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_advancedMode 
            ? "Please enable the Accessibility Service for 'screen_prank_app' first." 
            : "Please grant the 'Draw over other apps' permission first."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_countdownSeconds == 0) {
      _launchOverlay();
    } else {
      setState(() {
        _isCountingDown = true;
        _secondsRemaining = _countdownSeconds;
      });

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining <= 1) {
          timer.cancel();
          setState(() {
            _isCountingDown = false;
          });
          _launchOverlay();
        } else {
          setState(() {
            _secondsRemaining--;
          });
        }
      });
    }
  }

  Future<void> _launchOverlay() async {
    try {
      if (_advancedMode) {
        final active = await _accessibilityChannel.invokeMethod<bool>('isOverlayActive') ?? false;
        if (!active) {
          await _accessibilityChannel.invokeMethod('startAccessibilityOverlay', {
            'crack': _crackEnabled,
            'greenLines': _greenLinesEnabled,
            'flicker': _flickerEnabled,
            'deadPixels': _deadPixelsEnabled,
          });
          setState(() {
            _overlayActive = true;
          });
        }
      } else {
        final active = await FlutterOverlayWindow.isActive();
        if (!active) {
          await FlutterOverlayWindow.showOverlay(
            enableDrag: false,
            flag: OverlayFlag.clickThrough, // Pass touch events directly through
            overlayTitle: "System Integrity Compromised",
            overlayContent: "Fatal visual rendering pipeline failure",
            visibility: NotificationVisibility.visibilityPublic,
            height: -1999,
            width: WindowSize.matchParent,
          );
          setState(() {
            _overlayActive = true;
          });
          // Sync our configuration parameters immediately
          _syncConfigToOverlay();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error launching overlay: $e")),
      );
    }
  }

  Future<void> _stopPrank() async {
    _countdownTimer?.cancel();
    try {
      if (_advancedMode) {
        await _accessibilityChannel.invokeMethod('stopAccessibilityOverlay');
      } else {
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
        }
      }
    } catch (e) {
      debugPrint("Error stopping overlay: $e");
    }
    setState(() {
      _overlayActive = false;
      _isCountingDown = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _listenerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cyberpunk themed dark palette
    const darkBg = Color(0xFF0F0E17);
    const textLight = Color(0xFFFFFFFE);
    const neonPink = Color(0xFFFF8906); // Accent 1
    const neonGreen = Color(0xFF39FF14); // Accent 2
    const cardBg = Color(0xFF2E2F3E);

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SCREEN PRANK",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: textLight,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(color: neonPink.withOpacity(0.5), offset: const Offset(2, 2), blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "OLED Damage Simulator (Advanced)",
                          style: TextStyle(color: Colors.white60, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.bug_report_outlined,
                    color: _overlayActive ? neonGreen : neonPink,
                    size: 32,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Overlay Active Status Panel
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _overlayActive ? neonGreen.withOpacity(0.5) : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _overlayActive ? neonGreen : Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_overlayActive ? neonGreen : Colors.red).withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _overlayActive ? "OVERLAY ACTIVE" : "OVERLAY STANDBY",
                      style: TextStyle(
                        color: textLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Prank Mode Toggle
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_overlayActive) return;
                        setState(() {
                          _advancedMode = false;
                        });
                        _checkPermissionAndState();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_advancedMode ? neonPink.withOpacity(0.15) : cardBg.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !_advancedMode ? neonPink : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "STANDARD MODE",
                            style: TextStyle(
                              color: !_advancedMode ? neonPink : Colors.white60,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_overlayActive) return;
                        setState(() {
                          _advancedMode = true;
                        });
                        _checkPermissionAndState();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _advancedMode ? neonGreen.withOpacity(0.15) : cardBg.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _advancedMode ? neonGreen : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "ADVANCED MODE",
                            style: TextStyle(
                              color: _advancedMode ? neonGreen : Colors.white60,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Countdown display if counting down
              if (_isCountingDown)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "LOCK DEVICE OR EXIT APP NOW!",
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Prank starts in: $_secondsRemaining",
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _stopPrank,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                        child: const Text("CANCEL TIMER", style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                )
              else ...[
                // Settings List
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "PRANK EFFECTS",
                          style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 12),

                        // Switch 1: Crack
                        _buildEffectSwitch(
                          title: "OLED Crack & Ink Bleed",
                          subtitle: "Simulate glass fracture & liquid ink bleed",
                          value: _crackEnabled,
                          onChanged: (val) {
                            setState(() => _crackEnabled = val);
                            if (_overlayActive) _syncConfigToOverlay();
                          },
                        ),

                        // Switch 2: Green Lines
                        _buildEffectSwitch(
                          title: "Green OLED Lines",
                          subtitle: "Flickering bright vertical matrix lines",
                          value: _greenLinesEnabled,
                          onChanged: (val) {
                            setState(() => _greenLinesEnabled = val);
                            if (_overlayActive) _syncConfigToOverlay();
                          },
                        ),

                        // Switch 3: Screen Flicker
                        _buildEffectSwitch(
                          title: "Backlight Flicker & Scan Lines",
                          subtitle: "Rapid vertical brightness shifts",
                          value: _flickerEnabled,
                          onChanged: (val) {
                            setState(() => _flickerEnabled = val);
                            if (_overlayActive) _syncConfigToOverlay();
                          },
                        ),

                        // Switch 4: Dead Pixels
                        _buildEffectSwitch(
                          title: "Twinkling Stuck Pixels",
                          subtitle: "Red, blue & green microscopic dots",
                          value: _deadPixelsEnabled,
                          onChanged: (val) {
                            setState(() => _deadPixelsEnabled = val);
                            if (_overlayActive) _syncConfigToOverlay();
                          },
                        ),

                        const SizedBox(height: 24),
                        const Text(
                          "TRIGGER DELAY",
                          style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 12),

                        // Delay Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _countdownSeconds,
                              dropdownColor: cardBg,
                              isExpanded: true,
                              items: _delayOptions.map((seconds) {
                                return DropdownMenuItem<int>(
                                  value: seconds,
                                  child: Text(
                                    seconds == 0 ? "Instant (Activate Now)" : "$seconds Seconds Delay",
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _countdownSeconds = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Permission Checker Button
                if (!_permissionGranted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.3), width: 1),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _advancedMode
                                      ? "Accessibility service permission is required to persistent overlay (draws over Quick Settings and Lock Screen)."
                                      : "Overlay permission is required to draw the glitch over other apps.",
                                  style: const TextStyle(color: Colors.amber, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _requestPermission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              _advancedMode ? "ENABLE ACCESSIBILITY" : "GRANT PERMISSION",
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Primary Start / Stop buttons
                if (_overlayActive)
                  ElevatedButton.icon(
                    onPressed: _stopPrank,
                    icon: const Icon(Icons.stop, color: Colors.white),
                    label: const Text("STOP PRANK", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _startPrankWorkflow,
                    icon: const Icon(Icons.play_arrow, color: Colors.black),
                    label: const Text("ACTIVATE PRANK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _advancedMode ? neonGreen : neonPink,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEffectSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    const cardBg = Color(0xFF2E2F3E);
    const neonPink = Color(0xFFFF8906);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: neonPink,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

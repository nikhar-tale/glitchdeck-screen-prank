import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _accessibilityChannel = MethodChannel('com.prank.screen/accessibility');

  // Prank state variables
  bool _greenLinesEnabled = true;
  bool _flickerEnabled = true;
  bool _deadPixelsEnabled = true;

  // Mode state
  bool _advancedMode = false; // False = Standard, True = Accessibility

  // System states
  bool _permissionGranted = false;
  bool _overlayActive = false;
  bool _isCountingDown = false;
  int _countdownSeconds = 5; // Default delay
  int _secondsRemaining = 0;
  Timer? _countdownTimer;
  StreamSubscription? _listenerSubscription;

  // Animation controller for pulsing status LED & preview synchronization
  late AnimationController _pulseController;

  // Selected timer options
  final List<int> _delayOptions = [0, 3, 5, 10, 20, 30];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionAndState();

    // 1. Setup pulsing LED controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    // 2. Listen to messages from the overlay (e.g. handshake requests)
    try {
      _listenerSubscription = FlutterOverlayWindow.overlayListener.listen((event) {
        if (event == "OVERLAY_READY") {
          _syncConfigToOverlay();
        }
      });
    } catch (e) {
      debugPrint("Warning: overlayListener stream already listened to: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndState();
    }
  }

  Future<void> _checkPermissionAndState() async {
    try {
      if (_advancedMode) {
        final enabled = await _accessibilityChannel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
        final active = await _accessibilityChannel.invokeMethod<bool>('isOverlayActive') ?? false;
        if (mounted) {
          setState(() {
            _permissionGranted = enabled;
            _overlayActive = active;
          });
        }
      } else {
        final granted = await FlutterOverlayWindow.isPermissionGranted();
        final active = await FlutterOverlayWindow.isActive();
        if (mounted) {
          setState(() {
            _permissionGranted = granted;
            _overlayActive = active;
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking permission/state: $e");
    }
  }

  Future<void> _requestPermission() async {
    HapticFeedback.mediumImpact();
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
      'greenLines': _greenLinesEnabled,
      'flicker': _flickerEnabled,
      'deadPixels': _deadPixelsEnabled,
    });
  }

  void _startPrankWorkflow() async {
    HapticFeedback.heavyImpact();
    await _checkPermissionAndState();

    if (!_permissionGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _advancedMode 
              ? "Please enable the Accessibility Service for 'Display Calibrator' first." 
              : "Please grant the 'Draw over other apps' permission first.",
            style: const TextStyle(fontFamily: 'monospace'),
          ),
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
        HapticFeedback.vibrate(); // Physical mechanical tick
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
            'greenLines': _greenLinesEnabled,
            'flicker': _flickerEnabled,
            'deadPixels': _deadPixelsEnabled,
          });
          if (mounted) {
            setState(() {
              _overlayActive = true;
            });
          }
        }
      } else {
        final active = await FlutterOverlayWindow.isActive();
        if (!active) {
          await FlutterOverlayWindow.showOverlay(
            enableDrag: false,
            flag: OverlayFlag.clickThrough,
            overlayTitle: "System Diagnostics Running",
            overlayContent: "Screen calibration thread active.",
            visibility: NotificationVisibility.visibilityPublic,
            height: -1999,
            width: WindowSize.matchParent,
          );
          if (mounted) {
            setState(() {
              _overlayActive = true;
            });
          }
          _syncConfigToOverlay();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error launching overlay: $e", style: const TextStyle(fontFamily: 'monospace')),
        ),
      );
    }
  }

  Future<void> _stopPrank() async {
    HapticFeedback.selectionClick();
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
    if (mounted) {
      setState(() {
        _overlayActive = false;
        _isCountingDown = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _listenerSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cyberpunk Glassmorphic styling
    const darkBg = Color(0xFF06060E);
    const textLight = Color(0xFFF1F1F8);
    const neonPink = Color(0xFFFF0055); 
    const neonGreen = Color(0xFF39FF14);
    const cardBg = Color(0xFF12131C);
    const borderAccent = Color(0xFF22232E);

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
                          "GLITCHDECK",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: textLight,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(color: neonPink.withOpacity(0.6), offset: const Offset(2, 2), blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "GLITCH ENGINE PROTOCOL // v1.0.4",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white54),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Overlay Active Status Panel with Pulsing LED
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBg.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _overlayActive ? neonGreen.withOpacity(0.3) : borderAccent,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _overlayActive 
                                ? neonGreen.withOpacity(0.3 + (_pulseController.value * 0.7)) 
                                : Colors.red.withOpacity(0.3 + (_pulseController.value * 0.7)),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_overlayActive ? neonGreen : Colors.red).withOpacity(0.3),
                                blurRadius: 4 + (_pulseController.value * 6),
                                spreadRadius: 1 + (_pulseController.value * 2),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _overlayActive ? "SYSTEM STATUS: GLITCH_ACTIVE" : "SYSTEM STATUS: STANDBY_READY",
                        style: TextStyle(
                          color: _overlayActive ? neonGreen : textLight.withOpacity(0.7),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Interactive Phone Preview Mockup
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return PhonePreviewMockup(
                      greenLines: _greenLinesEnabled,
                      flicker: _flickerEnabled,
                      deadPixels: _deadPixelsEnabled,
                      pulseValue: _pulseController.value,
                    );
                  },
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
                        HapticFeedback.selectionClick();
                        setState(() {
                          _advancedMode = false;
                        });
                        _checkPermissionAndState();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_advancedMode ? neonPink.withOpacity(0.12) : cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !_advancedMode ? neonPink.withOpacity(0.7) : borderAccent,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "STANDARD MODE",
                            style: TextStyle(
                              color: !_advancedMode ? neonPink : Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              fontFamily: 'monospace',
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
                        HapticFeedback.selectionClick();
                        setState(() {
                          _advancedMode = true;
                        });
                        _checkPermissionAndState();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _advancedMode ? neonGreen.withOpacity(0.12) : cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _advancedMode ? neonGreen.withOpacity(0.7) : borderAccent,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "ADVANCED MODE",
                            style: TextStyle(
                              color: _advancedMode ? neonGreen : Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Countdown display if active
              if (_isCountingDown)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "// STAGE TARGET DEVICE IMMEDIATELY",
                        style: TextStyle(
                          color: Colors.redAccent, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "DISRUPT IN: $_secondsRemaining SECONDS",
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 16, 
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _stopPrank,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          "ABORT LAUNCH", 
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      )
                    ],
                  ),
                )
              else ...[
                // Settings List
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const Text(
                        "PAYLOAD CONFIGURATORS",
                        style: TextStyle(
                          color: Colors.white38, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 10,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _buildEffectSwitch(
                        title: "Green OLED Lines",
                        subtitle: "Constant vertical striping",
                        value: _greenLinesEnabled,
                        onChanged: (val) {
                          setState(() => _greenLinesEnabled = val);
                          if (_overlayActive) _syncConfigToOverlay();
                        },
                      ),

                      _buildEffectSwitch(
                        title: "Backlight Flicker",
                        subtitle: "High frequency brightness sweep",
                        value: _flickerEnabled,
                        onChanged: (val) {
                          setState(() => _flickerEnabled = val);
                          if (_overlayActive) _syncConfigToOverlay();
                        },
                      ),

                      _buildEffectSwitch(
                        title: "Dead Pixel Cluster",
                        subtitle: "Twinkling microscopic stuck subpixels",
                        value: _deadPixelsEnabled,
                        onChanged: (val) {
                          setState(() => _deadPixelsEnabled = val);
                          if (_overlayActive) _syncConfigToOverlay();
                        },
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        "DISRUPT DELAY",
                        style: TextStyle(
                          color: Colors.white38, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 10,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Delay Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderAccent, width: 1),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            key: const Key('delay_dropdown'),
                            value: _countdownSeconds,
                            dropdownColor: cardBg,
                            isExpanded: true,
                            items: _delayOptions.map((seconds) {
                              return DropdownMenuItem<int>(
                                value: seconds,
                                child: Text(
                                  seconds == 0 ? "Instant (Disrupt Now)" : "$seconds Seconds Delay",
                                  style: const TextStyle(
                                    color: Colors.white, 
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                HapticFeedback.selectionClick();
                                setState(() => _countdownSeconds = value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Permission Warning Bar
                if (!_permissionGranted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.2), width: 1),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _advancedMode
                                      ? "Accessibility permission required to draw over Lock Screen and system menus."
                                      : "Draw-over permission required to render visual glitches on overlay layer.",
                                  style: const TextStyle(
                                    color: Colors.amberAccent, 
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _requestPermission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              minimumSize: const Size.fromHeight(36),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              _advancedMode ? "GRANT ACCESS" : "AUTHORIZE SYSTEM DRAW",
                              style: const TextStyle(
                                color: Colors.black, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Start / Stop Trigger
                if (_overlayActive)
                  ElevatedButton.icon(
                    onPressed: _stopPrank,
                    icon: const Icon(Icons.stop, color: Colors.white, size: 20),
                    label: const Text(
                      "DISMISS GLITCH", 
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontFamily: 'monospace'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _startPrankWorkflow,
                    icon: const Icon(Icons.play_arrow, color: Colors.black, size: 20),
                    label: const Text(
                      "EXECUTE DISRUPTION", 
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontFamily: 'monospace'),
                    ),
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
    const cardBg = Color(0xFF12131C);
    const neonPink = Color(0xFFFF0055);
    const borderAccent = Color(0xFF22232E);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderAccent, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: const TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle, 
                  style: const TextStyle(
                    color: Colors.white38, 
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: neonPink,
            onChanged: (val) {
              HapticFeedback.lightImpact();
              onChanged(val);
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Live Phone Mockup Preview Components
// =============================================================================

class PhonePreviewMockup extends StatelessWidget {
  final bool greenLines;
  final bool flicker;
  final bool deadPixels;
  final double pulseValue;

  const PhonePreviewMockup({
    super.key,
    required this.greenLines,
    required this.flicker,
    required this.deadPixels,
    required this.pulseValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0E17),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background representing normal OS
          Container(
            color: const Color(0xFF0B0A11),
          ),
          
          // Faux apps layout to make standard screen preview look real
          Center(
            child: Opacity(
              opacity: 0.12,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.grid_view_rounded, size: 32, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(width: 45, height: 4, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(width: 25, height: 4, color: Colors.white),
                ],
              ),
            ),
          ),

          // Flicker Overlay Preview
          if (flicker)
            Container(
              color: Colors.white.withOpacity(0.01 + (pulseValue * 0.04)),
              child: CustomPaint(
                painter: MiniScanLinePainter(pulseValue),
                size: Size.infinite,
              ),
            ),

          // Green Lines Preview
          if (greenLines)
            Positioned.fill(
              child: CustomPaint(
                painter: MiniGreenLinesPainter(),
              ),
            ),

          // Dead Pixels Preview
          if (deadPixels)
            Positioned.fill(
              child: CustomPaint(
                painter: MiniDeadPixelsPainter(),
              ),
            ),

          // Smartphone Notch Speaker
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              width: 32,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MiniScanLinePainter extends CustomPainter {
  final double animValue;
  MiniScanLinePainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += 5.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MiniGreenLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF39FF14)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), paint);
    
    final paintMagenta = Paint()
      ..color = const Color(0xFFFF0055).withOpacity(0.7)
      ..strokeWidth = 0.6;
    canvas.drawLine(Offset(size.width * 0.72, 0), Offset(size.width * 0.72, size.height), paintMagenta);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MiniDeadPixelsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintRed = Paint()..color = Colors.red..style = PaintingStyle.fill;
    final paintGreen = Paint()..color = Colors.green..style = PaintingStyle.fill;
    final paintBlue = Paint()..color = Colors.blue..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(size.width * 0.25, size.height * 0.25, 1.8, 1.8), paintRed);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.58, size.height * 0.65, 1.8, 1.8), paintGreen);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.8, size.height * 0.18, 1.5, 1.5), paintBlue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



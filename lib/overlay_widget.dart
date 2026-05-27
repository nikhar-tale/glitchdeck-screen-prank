import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class PrankOverlayWidget extends StatefulWidget {
  const PrankOverlayWidget({super.key});

  @override
  State<PrankOverlayWidget> createState() => _PrankOverlayWidgetState();
}

class _PrankOverlayWidgetState extends State<PrankOverlayWidget> with TickerProviderStateMixin {
  // Configurable options
  bool showGreenLines = true;
  bool showFlicker = true;
  bool showDeadPixels = true;

  late AnimationController _flickerController;
  late AnimationController _glitchLineController;
  late AnimationController _deadPixelController;

  final List<DeadPixel> _deadPixelsList = [];
  final math.Random _random = math.Random();
  StreamSubscription? _listenerSubscription;

  @override
  void initState() {
    super.initState();

    // 1. Setup Animation Controllers
    // High-frequency controller for screen flickering and scan lines
    _flickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);

    // Dynamic movement controller for glitch lines
    _glitchLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Twinkling animation for dead/stuck pixels
    _deadPixelController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // 2. Generate static coordinates for dead pixels
    _generateDeadPixels();

    // 3. Start communication listener for runtime settings update
    _listenerSubscription = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        setState(() {
          showGreenLines = event['greenLines'] ?? true;
          showFlicker = event['flicker'] ?? true;
          showDeadPixels = event['deadPixels'] ?? true;
        });
      }
    });

    // 4. Send handshake signal to main app to fetch current configuration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendHandshake();
    });
  }

  void _sendHandshake() async {
    // Send a message to tell the dashboard we are ready to receive configurations
    await FlutterOverlayWindow.shareData("OVERLAY_READY");
  }

  void _generateDeadPixels() {
    // Generate about 15-20 random dead pixels scattered across the display
    for (int i = 0; i < 25; i++) {
      _deadPixelsList.add(
        DeadPixel(
          xPercent: _random.nextDouble(),
          yPercent: _random.nextDouble(),
          color: _random.nextBool() 
              ? Colors.red 
              : (_random.nextBool() ? Colors.green : Colors.blue),
          size: _random.nextDouble() * 2.5 + 1.0,
        ),
      );
    }
  }

  int _tapCount = 0;
  Timer? _tapResetTimer;

  void _dismissOverlay() async {
    try {
      // 1. Tell the main app to close accessibility overlay if advanced mode is active
      await FlutterOverlayWindow.shareData("DISMISS_ACCESSIBILITY_OVERLAY");
      // 2. Call standard overlay close directly
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint("Error dismissing overlay: $e");
    }
  }

  @override
  void dispose() {
    _flickerController.dispose();
    _glitchLineController.dispose();
    _deadPixelController.dispose();
    _listenerSubscription?.cancel();
    _tapResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    debugPrint('🔍 [OVERLAY DEBUG] Screen size: ${mq.size}');
    debugPrint('🔍 [OVERLAY DEBUG] Padding: ${mq.padding}');
    debugPrint('🔍 [OVERLAY DEBUG] ViewPadding: ${mq.viewPadding}');
    debugPrint('🔍 [OVERLAY DEBUG] ViewInsets: ${mq.viewInsets}');
    debugPrint('🔍 [OVERLAY DEBUG] DevicePixelRatio: ${mq.devicePixelRatio}');

    return LayoutBuilder(
      builder: (context, constraints) {
        debugPrint('🔍 [OVERLAY DEBUG] LayoutBuilder constraints: $constraints');
        final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            final x = details.globalPosition.dx;
            final y = details.globalPosition.dy;
            if (x > screenSize.width * 0.8 && y < screenSize.height * 0.2) {
              _tapCount++;
              _tapResetTimer?.cancel();
              _tapResetTimer = Timer(const Duration(milliseconds: 600), () {
                _tapCount = 0;
              });
              if (_tapCount >= 3) {
                _tapResetTimer?.cancel();
                _tapCount = 0;
                _dismissOverlay();
              }
            } else {
              _tapCount = 0;
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
        // 1. Flickering Scan Line & Screen Distortion Overlay
        if (showFlicker)
          AnimatedBuilder(
            animation: _flickerController,
            builder: (context, child) {
              final val = _flickerController.value;
              // Randomly inject high distortion frames
              final isGlitchFrame = _random.nextDouble() > 0.96;
              
              return Container(
                color: Colors.black.withOpacity(
                  isGlitchFrame 
                      ? 0.12 
                      : (0.01 + (val * 0.015)), // subtle flickering overlay
                ),
                child: CustomPaint(
                  painter: ScanLinePainter(
                    flickerVal: val,
                    isGlitchFrame: isGlitchFrame,
                  ),
                ),
              );
            },
          ),

        // 2. Dead / Stuck Pixel Overlay
        if (showDeadPixels)
          AnimatedBuilder(
            animation: _deadPixelController,
            builder: (context, child) {
              return CustomPaint(
                painter: DeadPixelsPainter(
                  pixels: _deadPixelsList,
                  twinkleVal: _deadPixelController.value,
                ),
              );
            },
          ),

        // 3. Green Vertical / Horizontal Glitch Lines
        if (showGreenLines)
          AnimatedBuilder(
            animation: _glitchLineController,
            builder: (context, child) {
              return CustomPaint(
                painter: GlitchLinePainter(
                  animationVal: _glitchLineController.value,
                  random: _random,
                ),
              );
            },
          ),

      ],
    ),
   );
      },
    );
  }
}

// Dead Pixel helper model
class DeadPixel {
  final double xPercent;
  final double yPercent;
  final Color color;
  final double size;

  DeadPixel({
    required this.xPercent,
    required this.yPercent,
    required this.color,
    required this.size,
  });
}

// Custom Painter to render Dead Pixels
class DeadPixelsPainter extends CustomPainter {
  final List<DeadPixel> pixels;
  final double twinkleVal;

  DeadPixelsPainter({required this.pixels, required this.twinkleVal});

  @override
  void paint(Canvas canvas, Size size) {
    for (var pixel in pixels) {
      // Create some variance in blinking
      final opacity = (0.3 + (twinkleVal * 0.7)).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = pixel.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(
          pixel.xPercent * size.width,
          pixel.yPercent * size.height,
          pixel.size,
          pixel.size,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DeadPixelsPainter oldDelegate) => true;
}

// Custom Painter to draw green glitch vertical and horizontal lines
class GlitchLinePainter extends CustomPainter {
  final double animationVal;
  final math.Random random;

  GlitchLinePainter({required this.animationVal, required this.random});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Green line (Constant bright green OLED bleed line)
    // Draw one distinct, always-on ultra-bright green vertical line (typical of damaged OLEDs)
    final brightGreenPaint = Paint()
      ..color = const Color(0xFF00FF33)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    
    // Position it at 1/3 of the screen width
    canvas.drawLine(
      Offset(size.width * 0.35, 0),
      Offset(size.width * 0.35, size.height),
      brightGreenPaint,
    );

    // Another magenta line at 0.75 width
    final magentaPaint = Paint()
      ..color = const Color(0xFFFF0055).withOpacity(0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.78, 0),
      Offset(size.width * 0.78, size.height),
      magentaPaint,
    );

    // 2. Animated glitch lines (vertical lines shifting and flickering)
    final glitchPaint = Paint()
      ..color = const Color(0xFF39FF14) // Neon green
      ..style = PaintingStyle.stroke;

    // Draw 3-5 random flickering vertical line structures
    for (int i = 0; i < 4; i++) {
      // Calculate a shifting X coordinate
      double baseX = (i * 0.25 + 0.1) * size.width;
      // Inject some drift animation
      double xOffset = math.sin(animationVal * math.pi * 2 + i) * 6;
      double finalX = (baseX + xOffset).clamp(0, size.width);

      // Randomize opacity to create flickering behavior
      double opacity = random.nextDouble() > 0.4 ? (0.2 + random.nextDouble() * 0.6) : 0.0;
      glitchPaint.color = const Color(0xFF39FF14).withOpacity(opacity);
      glitchPaint.strokeWidth = random.nextDouble() * 1.5 + 0.5;

      canvas.drawLine(
        Offset(finalX, 0),
        Offset(finalX, size.height),
        glitchPaint,
      );
    }

    // 3. Draw rare horizontal short glitches (horizontal signal loss)
    if (random.nextDouble() > 0.85) {
      final horizontalPaint = Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(0.7)
        ..strokeWidth = random.nextDouble() * 4 + 2;
      double y = random.nextDouble() * size.height;
      double startX = random.nextDouble() * (size.width * 0.5);
      double endX = startX + (random.nextDouble() * (size.width * 0.4));
      
      canvas.drawLine(Offset(startX, y), Offset(endX, y), horizontalPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GlitchLinePainter oldDelegate) => true;
}

// Custom Painter to draw scan lines and screen refresh glitches
class ScanLinePainter extends CustomPainter {
  final double flickerVal;
  final bool isGlitchFrame;

  ScanLinePainter({required this.flickerVal, required this.isGlitchFrame});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw horizontal scan line stripes
    final stripePaint = Paint()
      ..color = Colors.black.withOpacity(0.015)
      ..strokeWidth = 1.0;

    double step = 8.0; // Distance between scan lines
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), stripePaint);
    }

    // 2. Draw screen refresh distortion bar (horizontal wave of slight light/dark distortion)
    final barHeight = 40.0;
    final waveY = (flickerVal * size.height * 1.2) - barHeight;
    
    if (waveY > -barHeight && waveY < size.height) {
      final wavePaint = Paint()
        ..color = Colors.white.withOpacity(0.02)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(0, waveY, size.width, barHeight),
        wavePaint,
      );
    }

    // 3. Draw glitch frame horizontal flash block
    if (isGlitchFrame) {
      final flashPaint = Paint()
        ..color = const Color(0x33FF0000) // very faint red block
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.2),
        flashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScanLinePainter oldDelegate) => true;
}



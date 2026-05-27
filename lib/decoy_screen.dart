import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dashboard.dart';

class DecoyScreen extends StatefulWidget {
  const DecoyScreen({super.key});

  @override
  State<DecoyScreen> createState() => _DecoyScreenState();
}

class _DecoyScreenState extends State<DecoyScreen> {
  int _unlockTaps = 0;
  Timer? _unlockResetTimer;

  // Grid calibration selection index
  int? _activeGridIndex;

  // Simple state for Decoy tests
  bool _runningStressTest = false;
  double _stressTestOffset = 0.0;
  Timer? _stressTestTimer;

  @override
  void dispose() {
    _unlockResetTimer?.cancel();
    _stressTestTimer?.cancel();
    super.dispose();
  }

  void _handleTitleTap() {
    HapticFeedback.lightImpact();
    setState(() {
      _unlockTaps++;
    });

    _unlockResetTimer?.cancel();
    _unlockResetTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _unlockTaps = 0;
        });
      }
    });

    if (_unlockTaps >= 5) {
      _unlockResetTimer?.cancel();
      setState(() {
        _unlockTaps = 0;
      });
      HapticFeedback.vibrate();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ),
      );
    }
  }

  void _toggleStressTest() {
    HapticFeedback.mediumImpact();
    setState(() {
      _runningStressTest = !_runningStressTest;
    });

    if (_runningStressTest) {
      _stressTestTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (mounted) {
          setState(() {
            _stressTestOffset = (_stressTestOffset + 4) % 300;
          });
        }
      });
    } else {
      _stressTestTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBg = Color(0xFF121214);
    const cardBg = Color(0xFF1E1E24);
    const borderAccent = Color(0xFF2C2C35);
    const textGrey = Color(0xFFA0A0AB);

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: GestureDetector(
          onTap: _handleTitleTap,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Text(
              "DISPLAY CALIBRATOR",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: textGrey),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: "Display Calibrator",
                applicationVersion: "v1.4.2",
                applicationLegalese: "Professional screen utility.",
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SMPTE Color Bars
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderAccent, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Expanded(child: Container(color: Colors.white)),
                    Expanded(child: Container(color: const Color(0xFFC0C000))), // Yellow
                    Expanded(child: Container(color: const Color(0xFF00C0C0))), // Cyan
                    Expanded(child: Container(color: const Color(0xFF00C000))), // Green
                    Expanded(child: Container(color: const Color(0xFFC000C0))), // Magenta
                    Expanded(child: Container(color: const Color(0xFFC00000))), // Red
                    Expanded(child: Container(color: const Color(0xFF0000C0))), // Blue
                    Expanded(child: Container(color: Colors.black)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "SMPTE Color Bar Calibration Pattern",
                  style: TextStyle(color: textGrey, fontSize: 11, letterSpacing: 0.5),
                ),
              ),

              const SizedBox(height: 24),

              // Device Metrics Section
              const Text(
                "HARDWARE DISPLAY SPECS",
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderAccent, width: 1),
                ),
                child: Column(
                  children: [
                    _buildSpecRow("Panel Interface", "AMOLED / OLED Active Matrix"),
                    const Divider(color: borderAccent, height: 24),
                    _buildSpecRow("Native Resolution", "1080 x 2400 (FHD+)"),
                    const Divider(color: borderAccent, height: 24),
                    _buildSpecRow("Target Refresh Rate", "120 Hz (Dynamic Adaptive)"),
                    const Divider(color: borderAccent, height: 24),
                    _buildSpecRow("GPU Renderer", "Mali-G57 MC2 / Vulkan 1.3"),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Touch Calibration Grid
              const Text(
                "TOUCH SENSITIVITY GRID",
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderAccent, width: 1),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Tap each grid coordinate to verify and calibrate screen touch digitizer latency:",
                      style: TextStyle(color: textGrey, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: 8,
                      itemBuilder: (context, index) {
                        final isDone = _activeGridIndex == index;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _activeGridIndex = index;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isDone ? Colors.blue.withOpacity(0.2) : Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDone ? Colors.blue : borderAccent,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                "CH $index",
                                style: TextStyle(
                                  color: isDone ? Colors.blue : textGrey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Refresh Rate Stress Test
              const Text(
                "REFRESH RATE & FRAME SYNCHRONIZATION",
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderAccent, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Run a dynamic vertical sweep to align V-Sync buffers and test screen frame synchronization:",
                      style: TextStyle(color: textGrey, fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          if (_runningStressTest)
                            Positioned(
                              left: _stressTestOffset,
                              top: 0,
                              bottom: 0,
                              width: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueAccent.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Center(
                            child: Text(
                              _runningStressTest ? "STRESS TESTING IN PROGRESS..." : "STRESS TEST STANDBY",
                              style: TextStyle(
                                color: _runningStressTest ? Colors.blueAccent : textGrey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _toggleStressTest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _runningStressTest ? Colors.redAccent.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                        side: BorderSide(color: _runningStressTest ? Colors.redAccent : Colors.blue, width: 1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        _runningStressTest ? "STOP STRESS TEST" : "START STRESS TEST",
                        style: TextStyle(
                          color: _runningStressTest ? Colors.redAccent : Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

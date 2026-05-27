import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'decoy_screen.dart';
import 'overlay_widget.dart';

// 1. Entry point for the overlay window background service
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // Override MediaQuery to remove all system padding that the native
      // FlutterView's setFitsSystemWindows(true) injects. Without this,
      // the bottom ~20% (navigation bar area) is reserved as padding
      // and our overlay widgets won't render there.
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
          ),
          child: child!,
        );
      },
      home: const Material(
        color: Colors.transparent, // Crucial for transparency to show underlying apps
        child: PrankOverlayWidget(),
      ),
    ),
  );
}

// 2. Default app entry point (Dashboard UI)
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScreenPrankApp());
}

class ScreenPrankApp extends StatelessWidget {
  const ScreenPrankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen Prank Simulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0F0E17),
        useMaterial3: true,
      ),
      home: const DecoyScreen(),
    );
  }
}

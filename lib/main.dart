import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mindmirror/splash_screen.dart' show SplashScreen;
import 'game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode — game is designed for portrait only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Full immersive mode — hide status bar & navigation bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MindMirrorApp());
}

class MindMirrorApp extends StatelessWidget {
  const MindMirrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TraceMind',
      debugShowCheckedModeBanner: false,

      // ── Dark theme matching the game's neon aesthetic ──────────────────
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF03030C),
        colorScheme: const ColorScheme.dark(
          primary:   Color(0xFF00E5FF), // neon cyan  — player
          secondary: Color(0xFFAA44FF), // neon purple — ghost
          error:     Color(0xFFFF1E44), // neon red    — walls / death
          surface:   Color(0xFF06061A),
        ),
        fontFamily: 'monospace', // clean fallback; swap for any Google Font
        useMaterial3: true,
      ),

      // ── Single route — straight into the game ─────────────────────────
      home: const SplashScreen(),
    );
  }
}
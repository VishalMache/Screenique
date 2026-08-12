import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/secrets.dart';
import 'firebase_options.dart';

// Services & Screens
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'home_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Fetch API keys from Firebase Remote Config (never bundled in APK).
  await AppSecrets.init();
  await NotificationService().init();
  runApp(const ScreeniqueApp());
}

class ScreeniqueApp extends StatelessWidget {
  const ScreeniqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Screenique',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F4EC), // Vintage Cream
        primaryColor: const Color(0xFF111111), // Stark Black
        hintColor: const Color(0xFFC62828),    // Vintage Red
        cardColor: const Color(0xFFFFFFFF),    // Pure White for some cards
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: Color(0xFF111111), 
            fontWeight: FontWeight.w900, 
            letterSpacing: -1.0 // Editorial tight spacing
          ),
          bodyMedium: TextStyle(color: Color(0xFF454545)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF111111),
            foregroundColor: const Color(0xFFF4F4EC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2), // Sharp corners
              side: const BorderSide(color: Color(0xFF111111), width: 2), // Solid black border
            ),
          ),
        ),
      ),
      // The FilmBurn wraps the entry point so the aesthetic is global
      home: const FilmBurnOverlay(
        child: AuthWrapper(), // App starts directly with the auth gate check
      ),
    );
  }
}

// --- AUTH WRAPPER ---
// This determines if we show the Login screen or the Home screen
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = AuthService().user;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text("Authentication Error"))
          );
        }
        // If user is logged in, show HomeScreen, else show LoginScreen
        return snapshot.hasData ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}

// --- FILM BURN OVERLAY (Action Feedback) ---
class FilmBurnOverlay extends StatefulWidget {
  final Widget child;
  const FilmBurnOverlay({super.key, required this.child});

  static _FilmBurnOverlayState? of(BuildContext context) =>
      context.findAncestorStateOfType<_FilmBurnOverlayState>();

  @override
  State<FilmBurnOverlay> createState() => _FilmBurnOverlayState();
}

class _FilmBurnOverlayState extends State<FilmBurnOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  void triggerBurn() => _controller.forward(from: 0.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: (_controller.value > 0.1 && _controller.value < 0.9) ? 1.0 : 0.0,
                child: CustomPaint(
                  painter: BurnPainter(_controller.value), 
                  size: Size.infinite
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class BurnPainter extends CustomPainter {
  final double progress;
  BurnPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    
    // Primary Burn Hole
    paint.color = const Color(0xFFFF4500).withOpacity((1 - progress) * 0.7);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.3), size.width * progress, paint);
    
    // Spreading Heat
    paint.color = const Color(0xFFFFA500).withOpacity((1 - progress) * 0.4);
    canvas.drawOval(Rect.fromLTWH(0, size.height * (1 - progress), size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(BurnPainter old) => true;
}

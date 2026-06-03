import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

// Services & Screens
import 'services/auth_service.dart';
import 'home_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      // The FilmBurn and FilmGrain wrap the entry point so the aesthetic is global
      home: FilmBurnOverlay(
        child: const FilmGrainOverlay(
          child: AuthWrapper(), // App starts directly with the auth gate check
        ),
      ),
    );
  }
}

// --- AUTH WRAPPER ---
// This determines if we show the Login screen or the Home screen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
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

// --- FILM GRAIN & SCRATCHES OVERLAY ---
class FilmGrainOverlay extends StatefulWidget {
  final Widget child;
  const FilmGrainOverlay({super.key, required this.child});

  @override
  State<FilmGrainOverlay> createState() => _FilmGrainOverlayState();
}

class _FilmGrainOverlayState extends State<FilmGrainOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final AssetImage _grainImageProvider;

  @override
  void initState() {
    super.initState();
    _grainImageProvider = const AssetImage('assets/stardust.png');
    _controller = AnimationController(duration: const Duration(milliseconds: 150), vsync: this)..repeat();
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
        RepaintBoundary(child: widget.child),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: [
                  // Occasional vertical film scratches (darker for light theme)
                  if (Random().nextDouble() > 0.94)
                    Positioned(
                      left: Random().nextDouble() * MediaQuery.of(context).size.width,
                      top: 0, bottom: 0,
                      child: Container(width: 1.2, color: Colors.black.withOpacity(0.06)),
                    ),
                  // Constant film grain texture
                  Opacity(
                    opacity: 0.12, // slightly higher opacity for light theme
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: _grainImageProvider,
                          repeat: ImageRepeat.repeat,
                          alignment: Alignment(
                            Random().nextDouble() * 2 - 1, 
                            Random().nextDouble() * 2 - 1
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
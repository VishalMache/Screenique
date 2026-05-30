import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../main.dart'; // To access AuthWrapper

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isLottieLoaded = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToNext() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, anim, secondAnim) => const AuthWrapper(),
          transitionsBuilder: (context, anim, secondAnim, child) => 
            FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 1200),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigateToNext,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4EC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Editorial Typography Logo
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1500),
                    onEnd: _navigateToNext,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.9 + (value * 0.1),
                        child: Opacity(
                          opacity: value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "SCREENIQUE",
                                style: TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                  letterSpacing: 2,
                                  fontFamily: 'Impact',
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                color: const Color(0xFFD32F2F),
                                child: const Text(
                                  "CURATED CHRONICLE",
                                  style: TextStyle(
                                    color: Color(0xFFF4F4EC),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 60),
              
              // 2. The Subtitle
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value * 0.6,
                    child: const Text(
                      "TAP TO START",
                      style: TextStyle(
                        color: Color(0xFF111111),
                        letterSpacing: 8,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'dart:async';
import 'choose_challenge_screen.dart';

class GameIntroScreen extends StatefulWidget {
  const GameIntroScreen({super.key});

  @override
  State<GameIntroScreen> createState() => _GameIntroScreenState();
}

class _GameIntroScreenState extends State<GameIntroScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _buttonController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _buttonFade;

  bool _skipVisible = true;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _logoFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));
    _logoScale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack));

    _textController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _textFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
            CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic));

    _buttonController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _buttonFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _buttonController, curve: Curves.easeOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _buttonController.forward();
  }

  void _proceed() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ChooseChallengeScreen()),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        children: [
          // Background film grain texture
          Positioned.fill(
            child: CustomPaint(painter: _GrainPainter()),
          ),
          // Skip button
          if (_skipVisible)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: TextButton(
                onPressed: _proceed,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Color(0xFF888882),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Logo + title
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1A0808),
                              border: Border.all(
                                  color: const Color(0xFFD32F2F), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD32F2F).withOpacity(0.35),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.movie_filter_rounded,
                              color: Color(0xFFD32F2F),
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'SCREENIQUE',
                            style: TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 40, child: Divider(color: Color(0xFF333333), thickness: 1)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'GUESS',
                                  style: TextStyle(
                                    color: Color(0xFFF4F4EC),
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 40, child: Divider(color: Color(0xFF333333), thickness: 1)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Tagline
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: const [
                          Text(
                            'Every movie leaves clues.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFF4F4EC),
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'How quickly can you find it?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF888882),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  // CTA button
                  FadeTransition(
                    opacity: _buttonFade,
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Material(
                            color: const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _proceed,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'START GUESSING',
                                      style: TextStyle(
                                        color: Color(0xFFF4F4EC),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(Icons.arrow_forward_rounded,
                                        color: Color(0xFFF4F4EC), size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.circle, color: Color(0xFFD32F2F), size: 6),
                            SizedBox(width: 8),
                            Text(
                              'Today\'s challenge available',
                              style: TextStyle(
                                color: Color(0xFF888882),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '🔥 2,481 cinephiles have played today',
                          style: TextStyle(
                            color: Color(0xFF575757),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle noise grain background painter
class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle vignette gradient
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          const Color(0xFF1A0808).withOpacity(0.0),
          const Color(0xFF000000).withOpacity(0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_GrainPainter _) => false;
}

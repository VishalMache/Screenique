import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import 'game_ready_screen.dart';
import 'themed_challenge_screen.dart';

class ChooseChallengeScreen extends StatefulWidget {
  const ChooseChallengeScreen({super.key});

  @override
  State<ChooseChallengeScreen> createState() => _ChooseChallengeScreenState();
}

class _ChooseChallengeScreenState extends State<ChooseChallengeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToQuickMix() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const GameReadyScreen(
          challengeType: ChallengeType.quickMix,
        ),
      ),
    );
  }

  void _goToThemed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ThemedChallengeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF575757), size: 24),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'CHOOSE ARENA',
                        style: TextStyle(
                          color: Color(0xFFF4F4EC),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Impact',
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '10 MOVIES. 3 CLUES. 1 FINAL SCORE.',
                    style: TextStyle(
                      color: Color(0xFFD32F2F),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Quick Mix Card
                  _buildQuickMixCard(),
                  const SizedBox(height: 20),
                  
                  // Themed Card
                  _buildThemedCard(),
                  
                  const Spacer(),
                  // How it works
                  _buildScoringCheat(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMixCard() {
    return GestureDetector(
      onTap: _goToQuickMix,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD32F2F), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD32F2F).withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative background elements
            Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.flash_on_rounded, size: 140, color: const Color(0xFFD32F2F).withValues(alpha: 0.05)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'RECOMMENDED',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'QUICK MIX',
                    style: TextStyle(
                      color: Color(0xFFF4F4EC),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Impact',
                      letterSpacing: 1.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A totally unpredictable mix from across all cinema.',
                    style: TextStyle(
                      color: Color(0xFF888882),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'START RANDOMIZED RUN',
                        style: TextStyle(
                          color: Color(0xFFD32F2F),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: const Color(0xFFD32F2F), size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemedCard() {
    return GestureDetector(
      onTap: _goToThemed,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F11),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THEMED CHALLENGE',
                style: TextStyle(
                  color: Color(0xFF888882),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Impact',
                  letterSpacing: 1.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick a specific cinematic world (Marvel, 90s, Horror...)',
                style: TextStyle(
                  color: Color(0xFF575757),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SELECT THEME',
                    style: TextStyle(
                      color: Color(0xFF575757),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: const Color(0xFF575757), size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoringCheat() {
    final items = [
      ('EV 1', '100', const Color(0xFF4CAF50)),
      ('EV 2', '80', const Color(0xFF8BC34A)),
      ('EV 3', '60', const Color(0xFFFF9800)),
      ('EV 4', '40', const Color(0xFFD32F2F)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items.map((item) => _buildScoreChip(
            item.$1, item.$2, item.$3,
          )).toList(),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'WARNING: −5 POINTS PER WRONG GUESS',
            style: TextStyle(
              color: Color(0xFFD32F2F), 
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreChip(String label, String pts, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Text(pts, style: TextStyle(
            color: color, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Impact')),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(
            color: Color(0xFF888882), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

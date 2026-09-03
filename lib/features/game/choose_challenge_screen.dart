import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import 'choose_difficulty_screen.dart';
import 'themed_challenge_screen.dart';
import 'custom_challenge_screen.dart';

class ChooseChallengeScreen extends StatefulWidget {
  const ChooseChallengeScreen({super.key});

  @override
  State<ChooseChallengeScreen> createState() => _ChooseChallengeScreenState();
}

class _ChooseChallengeScreenState extends State<ChooseChallengeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
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
        builder: (_) => const ChooseDifficultyScreen(
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

  void _goToCustom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomChallengeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFF4F4EC), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'CHOOSE CHALLENGE',
          style: TextStyle(
            color: Color(0xFFF4F4EC),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded,
                color: Color(0xFF575757), size: 20),
            onPressed: () => _showInfoSheet(context),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fade,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Featured — Quick Mix
              _buildQuickMixCard(),
              const SizedBox(height: 16),
              // Themed
              _buildChallengeCard(
                emoji: '🎞️',
                title: 'THEMED CHALLENGE',
                subtitle: 'Choose a theme you love',
                description:
                    'Marvel, Bollywood, Horror, 90s Classics and more — 5 movie rounds per session.',
                onTap: _goToThemed,
                featured: false,
              ),
              const SizedBox(height: 12),
              // Custom
              _buildChallengeCard(
                emoji: '🎯',
                title: 'CUSTOM CHALLENGE',
                subtitle: 'Create your own challenge',
                description:
                    'Pick your genre, era, and a director. Your rules, your cinema.',
                onTap: _goToCustom,
                featured: false,
              ),
            ],
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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD32F2F).withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shuffle_rounded,
                      color: Color(0xFFD32F2F),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'QUICK MIX',
                          style: TextStyle(
                            color: Color(0xFFD32F2F),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'One random movie. Pure instinct.',
                          style: TextStyle(
                            color: Color(0xFF888882),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'A carefully curated random pick from our movie pool. No themes, no categories — just you and the film.',
                style: TextStyle(
                  color: Color(0xFF888882),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: _goToQuickMix,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'PLAY QUICK MIX',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFF4F4EC),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeCard({
    required String emoji,
    required String title,
    required String subtitle,
    required String description,
    required VoidCallback onTap,
    required bool featured,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141416).withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF4F4EC),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF888882),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF444444),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'HOW IT WORKS',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '1. Pick a challenge type\n'
              '2. Choose your difficulty\n'
              '3. Select how you want to guess\n'
              '4. Receive clues one by one\n'
              '5. Guess the movie — the earlier, the better\n'
              '6. Earn XP and build your streak',
              style: TextStyle(
                color: Color(0xFF888882),
                fontSize: 13,
                height: 1.8,
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

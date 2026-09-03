import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import 'choose_guess_mode_screen.dart';

class ChooseDifficultyScreen extends StatefulWidget {
  final ChallengeType challengeType;
  final ThemeCategory? selectedTheme;
  final int? customGenreId;
  final int? customYearFrom;
  final int? customYearTo;
  final int? customPersonId;
  final String? customLabel;

  const ChooseDifficultyScreen({
    super.key,
    required this.challengeType,
    this.selectedTheme,
    this.customGenreId,
    this.customYearFrom,
    this.customYearTo,
    this.customPersonId,
    this.customLabel,
  });

  @override
  State<ChooseDifficultyScreen> createState() => _ChooseDifficultyScreenState();
}

class _ChooseDifficultyScreenState extends State<ChooseDifficultyScreen>
    with SingleTickerProviderStateMixin {
  GameDifficulty _selected = GameDifficulty.medium;

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

  void _proceed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChooseGuessModeScreen(
          challengeType: widget.challengeType,
          difficulty: _selected,
          selectedTheme: widget.selectedTheme,
          customGenreId: widget.customGenreId,
          customYearFrom: widget.customYearFrom,
          customYearTo: widget.customYearTo,
          customPersonId: widget.customPersonId,
          customLabel: widget.customLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFF4F4EC), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'CHOOSE DIFFICULTY',
          style: TextStyle(
            color: Color(0xFFF4F4EC),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildDifficultyCard(DifficultyConfig.easy),
              const SizedBox(height: 12),
              _buildDifficultyCard(DifficultyConfig.medium),
              const SizedBox(height: 12),
              _buildDifficultyCard(DifficultyConfig.hard),
              const Spacer(),
              const Text(
                'You can change difficulty anytime before the game starts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF444444),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
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
                      child: Text(
                        'CONTINUE →',
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

  Widget _buildDifficultyCard(DifficultyConfig config) {
    final isSelected = _selected == config.difficulty;
    return GestureDetector(
      onTap: () => setState(() => _selected = config.difficulty),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? config.color.withOpacity(0.1)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? config.color : const Color(0xFF2A2A2A),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Emoji icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? config.color.withOpacity(0.2)
                    : const Color(0xFF222222),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(config.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            // Label + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.label,
                    style: TextStyle(
                      color:
                          isSelected ? config.color : const Color(0xFFF4F4EC),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    config.description,
                    style: const TextStyle(
                      color: Color(0xFF888882),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatBadge('${config.maxClues}', 'CLUES', config.color, isSelected),
                const SizedBox(height: 6),
                _buildStatBadge(
                    '×${config.scoreMultiplier.toStringAsFixed(config.scoreMultiplier % 1 == 0 ? 0 : 1)}',
                    'SCORE',
                    config.color,
                    isSelected),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String value, String label, Color color, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.15) : const Color(0xFF222222),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: active ? color : const Color(0xFF575757),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: active ? color.withOpacity(0.7) : const Color(0xFF444444),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

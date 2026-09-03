import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/game_models.dart';

class GameResultScreen extends StatefulWidget {
  final GameResult result;
  const GameResultScreen({super.key, required this.result});

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends State<GameResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heroController;
  late final AnimationController _scoreController;
  late final AnimationController _verdictController;
  late final Animation<double> _heroFade;
  late final Animation<double> _heroScale;
  late final Animation<double> _scoreAnim;
  late final Animation<double> _verdictFade;

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroScale = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOutBack));

    _scoreController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scoreAnim = CurvedAnimation(parent: _scoreController, curve: Curves.easeOut);

    _verdictController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _verdictFade =
        CurvedAnimation(parent: _verdictController, curve: Curves.easeOut);

    _runSequence();
  }

  Future<void> _runSequence() async {
    _heroController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _scoreController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _verdictController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _scoreController.dispose();
    _verdictController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final isSolved = result.solvedCount > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Verdict header
                FadeTransition(
                  opacity: _heroFade,
                  child: ScaleTransition(
                    scale: _heroScale,
                    child: Column(
                      children: [
                        Text(
                          isSolved ? 'CASE SOLVED' : 'CASE UNSOLVED',
                          style: TextStyle(
                            color: isSolved
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF888882),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.0,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Movie poster
                        if (result.posterUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: result.posterUrl!,
                              width: 120,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 120,
                            height: 180,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.movie_rounded,
                                color: Color(0xFF444444), size: 48),
                          ),
                        const SizedBox(height: 20),
                        // Movie title
                        Text(
                          result.movieTitle?.toUpperCase() ?? 'UNKNOWN',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFF4F4EC),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            height: 1.2,
                          ),
                        ),
                        if (result.solvedAtClue != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'You guessed it from CLUE #${result.solvedAtClue}',
                            style: const TextStyle(
                              color: Color(0xFF888882),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),
                _buildDivider(),
                const SizedBox(height: 20),

                // Score block
                FadeTransition(
                  opacity: _scoreAnim,
                  child: Column(
                    children: [
                      const Text(
                        'SCORE',
                        style: TextStyle(
                          color: Color(0xFF575757),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${result.totalScore}',
                        style: const TextStyle(
                          color: Color(0xFFF4F4EC),
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: DifficultyConfig.fromEnum(result.difficulty)
                              .color
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: DifficultyConfig.fromEnum(result.difficulty)
                                .color
                                .withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          '${DifficultyConfig.fromEnum(result.difficulty).emoji} '
                          '${DifficultyConfig.fromEnum(result.difficulty).label} '
                          '× ${DifficultyConfig.fromEnum(result.difficulty).scoreMultiplier.toStringAsFixed(result.difficulty == GameDifficulty.easy ? 0 : 1)}',
                          style: TextStyle(
                            color: DifficultyConfig.fromEnum(result.difficulty).color,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                _buildDivider(),
                const SizedBox(height: 20),

                // Verdict quote
                FadeTransition(
                  opacity: _verdictFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '"${result.verdict}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF4F4EC),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                _buildDivider(),
                const SizedBox(height: 20),

                // XP + Streak
                FadeTransition(
                  opacity: _verdictFade,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if ((result.streakDays ?? 0) > 0) ...[
                        Text(
                          '🔥 ${result.streakDays} DAY STREAK',
                          style: const TextStyle(
                            color: Color(0xFFFF9800),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFD32F2F).withOpacity(0.3)),
                        ),
                        child: Text(
                          '+${result.xpEarned} XP',
                          style: const TextStyle(
                            color: Color(0xFFD32F2F),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (result.isPerfectRun) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.4)),
                    ),
                    child: const Text(
                      '🏆 PERFECT RUN',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Action buttons
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // Share result text
                        final text =
                            'I scored ${result.totalScore} on The Screenique Guess!\n'
                            '"${result.verdict}"\n'
                            '🎬 Screenique';
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Share feature coming soon!')),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share_rounded,
                                color: Color(0xFF888882), size: 16),
                            SizedBox(width: 8),
                            Text(
                              'SHARE RESULT',
                              style: TextStyle(
                                color: Color(0xFF888882),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: const Color(0xFFD32F2F),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // Pop back to challenge selection
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'PLAY AGAIN',
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

                const SizedBox(height: 24),

                // Movie details expander
                if (result.movieTitle != null)
                  _buildMovieDetailsSection(result),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(color: Color(0xFF222222), thickness: 1);
  }

  Widget _buildMovieDetailsSection(GameResult result) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      iconColor: const Color(0xFF575757),
      collapsedIconColor: const Color(0xFF575757),
      title: const Text(
        'SHOW ANSWER DETAILS',
        style: TextStyle(
          color: Color(0xFF575757),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.posterUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: result.posterUrl!,
                    width: 70,
                    height: 105,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.movieTitle ?? '',
                      style: const TextStyle(
                        color: Color(0xFFF4F4EC),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (result.year != null)
                      Text(result.year!,
                          style: const TextStyle(
                              color: Color(0xFF575757), fontSize: 12)),
                    if (result.directorName != null)
                      Text('Dir: ${result.directorName}',
                          style: const TextStyle(
                              color: Color(0xFF888882), fontSize: 12)),
                    if (result.genre != null)
                      Text(result.genre!,
                          style: const TextStyle(
                              color: Color(0xFF888882), fontSize: 11)),
                    if (result.rating != null && result.rating! > 0)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFFFD700), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            result.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Color(0xFFF4F4EC), fontSize: 12),
                          ),
                        ],
                      ),
                    if (result.interestingFact != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💡 ', style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Text(
                                result.interestingFact!,
                                style: const TextStyle(
                                  color: Color(0xFF888882),
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

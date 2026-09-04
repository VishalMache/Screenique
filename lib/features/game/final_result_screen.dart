import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/game_models.dart';

class FinalResultScreen extends StatefulWidget {
  final GameResult result;
  const FinalResultScreen({super.key, required this.result});

  @override
  State<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends State<FinalResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _statsController;
  late final AnimationController _verdictController;
  late final AnimationController _actionsController;
  late final AnimationController _glowController;

  late final Animation<double> _introFade;
  late final Animation<double> _introScale;
  late final Animation<double> _statsFade;
  late final Animation<Offset> _statsSlide;
  late final Animation<double> _verdictFade;
  late final Animation<double> _actionsFade;
  late final Animation<double> _glowAnim;

  // Animated counter
  int _displayedScore = 0;
  Timer? _scoreTimer;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _introFade = CurvedAnimation(parent: _introController, curve: Curves.easeOut);
    _introScale = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _introController, curve: Curves.easeOutBack));

    _statsController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _statsFade = CurvedAnimation(parent: _statsController, curve: Curves.easeOut);
    _statsSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _statsController, curve: Curves.easeOutCubic));

    _verdictController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _verdictFade =
        CurvedAnimation(parent: _verdictController, curve: Curves.easeOut);

    _actionsController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _actionsFade =
        CurvedAnimation(parent: _actionsController, curve: Curves.easeOut);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    _introController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _statsController.forward();
    _startScoreCounter();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _verdictController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _actionsController.forward();
  }

  void _startScoreCounter() {
    final target = widget.result.totalScore;
    const steps = 40;
    final increment = (target / steps).ceil();
    int current = 0;
    _scoreTimer = Timer.periodic(const Duration(milliseconds: 28), (timer) {
      current += increment;
      if (current >= target) {
        current = target;
        timer.cancel();
      }
      if (mounted) setState(() => _displayedScore = current);
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _statsController.dispose();
    _verdictController.dispose();
    _actionsController.dispose();
    _glowController.dispose();
    _scoreTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final isBigWin = result.solvedCount >= 8;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          // Background ambient glow
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (context, _) => Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isBigWin
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFD32F2F))
                      .withOpacity(0.07 * _glowAnim.value),
                  boxShadow: [
                    BoxShadow(
                      color: (isBigWin
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFD32F2F))
                          .withOpacity(0.12 * _glowAnim.value),
                      blurRadius: 120,
                      spreadRadius: 60,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main scrollable content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // ── TOP HEADER ──
                  FadeTransition(
                    opacity: _introFade,
                    child: ScaleTransition(
                      scale: _introScale,
                      child: _buildTopHeader(result),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── STATS GRID ──
                  SlideTransition(
                    position: _statsSlide,
                    child: FadeTransition(
                      opacity: _statsFade,
                      child: _buildStatsGrid(result),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── ROUND BREAKDOWN ──
                  FadeTransition(
                    opacity: _statsFade,
                    child: _buildRoundBreakdown(result),
                  ),

                  const SizedBox(height: 24),

                  // ── VERDICT ──
                  FadeTransition(
                    opacity: _verdictFade,
                    child: _buildVerdictBlock(result),
                  ),

                  const SizedBox(height: 24),

                  // ── XP + STREAK ──
                  FadeTransition(
                    opacity: _verdictFade,
                    child: _buildXpBlock(result),
                  ),

                  const SizedBox(height: 32),

                  // ── ACTIONS ──
                  FadeTransition(
                    opacity: _actionsFade,
                    child: _buildActions(context),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(GameResult result) {
    return Column(
      children: [
        // Title
        const Text(
          '🎞️ CHALLENGE COMPLETE',
          style: TextStyle(
            color: Color(0xFF575757),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(height: 20),
        // Score counter
        Text(
          '$_displayedScore',
          style: const TextStyle(
            color: Color(0xFFF4F4EC),
            fontSize: 80,
            fontWeight: FontWeight.w900,
            fontFamily: 'Impact',
            height: 0.9,
            shadows: [
              Shadow(
                color: Color(0x50D32F2F),
                offset: Offset(0, 8),
                blurRadius: 24,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'POINTS',
          style: TextStyle(
            color: Color(0xFF444444),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(height: 20),
        // Solved ratio
        Text(
          '${result.solvedCount} / ${result.totalRounds} SOLVED',
          style: TextStyle(
            color: result.solvedCount >= result.totalRounds * 0.7
                ? const Color(0xFF4CAF50)
                : const Color(0xFF888882),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        if (result.isPerfectRun) ...[
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.4)),
            ),
            child: const Text(
              '🏆 PERFECT RUN',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsGrid(GameResult result) {
    final items = [
      ('Average Evidence', result.avgEvidenceUsed.toStringAsFixed(1), '🔍'),
      ('Best Round', '+${result.bestRoundScore} pts', '⚡'),
      if (result.fastestSolveMs != null)
        ('Fastest Solve', '${(result.fastestSolveMs! / 1000).toStringAsFixed(1)}s', '⏱️'),
      if (result.themeName != null)
        (result.themeName!, result.themeEmoji ?? '🎞️', '📽️'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SESSION STATS',
            style: TextStyle(
              color: Color(0xFF575757),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: items.map((item) => _buildStatItem(
              label: item.$1,
              value: item.$2,
              emoji: item.$3,
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required String emoji,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF4F4EC),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
              color: Color(0xFF575757), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildRoundBreakdown(GameResult result) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Text(
                  'ROUND BREAKDOWN',
                  style: TextStyle(
                    color: Color(0xFF575757),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const Spacer(),
                Text(
                  '${result.rounds.where((r) => r.isSolved).length} solved',
                  style: const TextStyle(
                      color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          ...result.rounds.asMap().entries.map((entry) {
            final i = entry.key;
            final round = entry.value;
            final score = round.computeScore();
            return _buildRoundRow(i + 1, round, score);
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRoundRow(int num, GameRound round, int score) {
    final isSolved = round.isSolved;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
        ),
        child: Row(
          children: [
            // Round number
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSolved
                    ? const Color(0xFF4CAF50).withOpacity(0.15)
                    : const Color(0xFF222222),
                border: Border.all(
                  color: isSolved
                      ? const Color(0xFF4CAF50).withOpacity(0.4)
                      : const Color(0xFF333333),
                ),
              ),
              child: Center(
                child: Text(
                  '$num',
                  style: TextStyle(
                    color: isSolved
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF444444),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Movie thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: CachedNetworkImage(
                imageUrl: round.posterUrl,
                width: 28,
                height: 40,
                fit: BoxFit.cover,
                color: isSolved ? null : Colors.black.withOpacity(0.5),
                colorBlendMode: BlendMode.darken,
              ),
            ),
            const SizedBox(width: 10),
            // Title
            Expanded(
              child: Text(
                round.movieTitle,
                style: TextStyle(
                  color: isSolved
                      ? const Color(0xFFF4F4EC)
                      : const Color(0xFF575757),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Evidence used
            if (isSolved && round.solvedAtEvidence != null)
              Text(
                'E${round.solvedAtEvidence}',
                style: const TextStyle(
                    color: Color(0xFF575757), fontSize: 10),
              ),
            const SizedBox(width: 8),
            // Score pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _scoreColor(score).withOpacity(0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                isSolved ? '+$score' : '0',
                style: TextStyle(
                  color: _scoreColor(score),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerdictBlock(GameResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            result.verdictLabel,
            style: const TextStyle(
              color: Color(0xFFD32F2F),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '"${result.verdict}"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF4F4EC),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpBlock(GameResult result) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if ((result.streakDays ?? 0) > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: const Color(0xFFFF9800).withOpacity(0.3)),
            ),
            child: Text(
              '🔥 ${result.streakDays} DAY STREAK',
              style: const TextStyle(
                color: Color(0xFFFF9800),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFD32F2F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
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
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: Material(
            color: const Color(0xFFD32F2F),
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => Navigator.of(context)
                  .popUntil((route) => route.isFirst),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'PLAY AGAIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF4F4EC),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => Navigator.of(context)
                  .popUntil((route) => route.isFirst),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home_rounded,
                        color: Color(0xFF575757), size: 16),
                    SizedBox(width: 8),
                    Text(
                      'BACK TO GAMES',
                      style: TextStyle(
                        color: Color(0xFF575757),
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
      ],
    );
  }

  Color _scoreColor(int score) {
    if (score >= 90) return const Color(0xFF4CAF50);
    if (score >= 70) return const Color(0xFF8BC34A);
    if (score >= 50) return const Color(0xFFFF9800);
    if (score > 0) return const Color(0xFFD32F2F);
    return const Color(0xFF444444);
  }
}

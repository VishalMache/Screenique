import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/game_models.dart';
import '../../models/movie_model.dart';
import '../../services/game_service.dart';
import 'game_guess_overlay.dart';
import 'final_result_screen.dart';

class GameplayScreen extends StatefulWidget {
  final GameSession session;
  const GameplayScreen({super.key, required this.session});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with TickerProviderStateMixin {
  final GameService _gameService = GameService();

  late GameSession _session;
  int _currentRoundIndex = 0;
  bool _showingRoundResult = false;
  int _lastRoundScore = 0;

  // Timer for tracking solve time
  DateTime? _roundStartTime;

  // Animation controllers
  late final AnimationController _headerController;
  late final AnimationController _evidenceController;
  late final AnimationController _resultController;
  late final AnimationController _celebrationController;

  late final Animation<double> _headerFade;
  late final Animation<Offset> _evidenceSlide;
  late final Animation<double> _evidenceFade;
  late final Animation<double> _resultSlide; // 0→1 (bottom to up)
  late final Animation<double> _celebrationScale;
  late final Animation<double> _celebrationOpacity;

  @override
  void initState() {
    super.initState();
    _session = widget.session;

    _headerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _headerFade =
        CurvedAnimation(parent: _headerController, curve: Curves.easeOut);

    _evidenceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _evidenceSlide = Tween<Offset>(
            begin: const Offset(0.05, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _evidenceController, curve: Curves.easeOutCubic));
    _evidenceFade =
        CurvedAnimation(parent: _evidenceController, curve: Curves.easeOut);

    _resultController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _resultSlide = CurvedAnimation(
        parent: _resultController, curve: Curves.easeOutCubic);

    _celebrationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _celebrationScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(
            parent: _celebrationController, curve: Curves.easeOutBack));
    _celebrationOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _celebrationController, curve: Curves.easeOut));

    _headerController.forward();
    _evidenceController.forward();
    _roundStartTime = DateTime.now();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _evidenceController.dispose();
    _resultController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  GameRound get _currentRound => _session.rounds[_currentRoundIndex];

  // ─── GUESS HANDLING ──────────────────────────────────────────────────────────

  void _showGuessOverlay() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameGuessOverlay(
        onGuess: _handleGuess,
        attemptsRemaining: 3 - _currentRound.wrongGuesses,
      ),
    );
  }

  void _handleGuess(MovieModel? movie) {
    Navigator.pop(context); // close overlay
    if (movie == null) return;

    final round = _currentRound;
    final isCorrect = movie.id == round.movieId ||
        movie.title.toLowerCase() == round.movieTitle.toLowerCase();

    if (isCorrect) {
      HapticFeedback.heavyImpact();
      final now = DateTime.now();
      final solveMs =
          _roundStartTime != null ? now.difference(_roundStartTime!).inMilliseconds : null;

      setState(() {
        round.isSolved = true;
        round.solvedAtEvidence = round.evidencesRevealed;
        round.solveTimeMs = solveMs;
        _lastRoundScore = GameService.scoreForEvidence(
          round.evidencesRevealed - 1,
          round.wrongGuesses,
        );
      });
      _showRoundResult(correct: true);
    } else {
      HapticFeedback.lightImpact();
      setState(() {
        round.wrongGuesses++;
      });

      // Auto-reveal next evidence if wrong and more are available
      final hasMoreEvidence =
          round.evidencesRevealed < round.evidences.length;
      final outOfGuesses = round.wrongGuesses >= 3;

      if (outOfGuesses) {
        // No more guesses — show answer
        if (hasMoreEvidence && round.evidencesRevealed < round.evidences.length) {
          _revealNextEvidence(auto: true);
        } else {
          setState(() {
            round.isSkipped = true;
            _lastRoundScore = 0;
          });
          _showRoundResult(correct: false);
        }
      } else if (hasMoreEvidence) {
        // Auto-advance to next evidence
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _revealNextEvidence(auto: true);
        });
      }
    }
  }

  void _revealNextEvidence({bool auto = false}) {
    final round = _currentRound;
    if (round.evidencesRevealed >= round.evidences.length) {
      // No more evidence — force end
      setState(() {
        round.isSkipped = true;
        _lastRoundScore = 0;
      });
      _showRoundResult(correct: false);
      return;
    }
    setState(() {
      round.evidencesRevealed++;
    });
    _evidenceController.forward(from: 0);
  }

  void _skipRound() {
    setState(() {
      _currentRound.isSkipped = true;
      _lastRoundScore = 0;
    });
    _showRoundResult(correct: false);
  }

  // ─── ROUND RESULT ─────────────────────────────────────────────────────────────

  void _showRoundResult({required bool correct}) {
    setState(() => _showingRoundResult = true);
    _resultController.forward(from: 0);
    if (correct) {
      _celebrationController.forward(from: 0);
    }
  }

  void _goToNextRound() {
    _resultController.reverse();

    if (_currentRoundIndex >= _session.rounds.length - 1) {
      // All rounds done → final result
      _goToFinalResult();
      return;
    }

    setState(() {
      _currentRoundIndex++;
      _showingRoundResult = false;
      _roundStartTime = DateTime.now();
    });

    _evidenceController.forward(from: 0);
    _celebrationController.reset();
  }

  Future<void> _goToFinalResult() async {
    final streak = await _gameService.getStreakDays();
    final result = _gameService.buildFinalResult(
      session: _session,
      streakDays: streak,
    );
    await _gameService.saveResult(result);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => FinalResultScreen(result: result)),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final round = _currentRound;
    final totalRounds = _session.rounds.length;
    final roundNum = _currentRoundIndex + 1;
    final currentEvidence = round.evidences[round.evidencesRevealed - 1];
    final totalScore = _session.totalScore;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                // ── TOP HEADER ──
                FadeTransition(
                  opacity: _headerFade,
                  child: _buildHeader(roundNum, totalRounds, totalScore),
                ),
                const SizedBox(height: 4),

                // ── ROUND PROGRESS BAR ──
                _buildRoundProgressBar(totalRounds),
                const SizedBox(height: 16),

                // ── EVIDENCE AREA ──
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SlideTransition(
                      position: _evidenceSlide,
                      child: FadeTransition(
                        opacity: _evidenceFade,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Evidence number indicator
                            _buildEvidenceIndicator(round),
                            const SizedBox(height: 16),

                            // Evidence type badge + content
                            _buildEvidenceCard(currentEvidence, round),
                            const SizedBox(height: 20),

                            // Wrong guess feedback
                            if (round.wrongGuesses > 0 && !_showingRoundResult)
                              _buildWrongGuessFeedback(round.wrongGuesses),

                            // Evidence dots (past evidences)
                            if (round.evidences.length > 1) ...[
                              const SizedBox(height: 16),
                              _buildEvidenceDots(round),
                            ],

                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── BOTTOM ACTIONS ──
                if (!_showingRoundResult)
                  _buildBottomActions(round),
              ],
            ),
          ),

          // ── ROUND RESULT PANEL (slides up) ──
          if (_showingRoundResult)
            _buildRoundResultPanel(round),
        ],
      ),
    );
  }

  Widget _buildHeader(int roundNum, int totalRounds, int totalScore) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Round label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROUND ${roundNum.toString().padLeft(2, '0')} / $totalRounds',
                  style: const TextStyle(
                    color: Color(0xFFD32F2F),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                if (widget.session.themeName != null)
                  Text(
                    '${widget.session.themeEmoji ?? ''} ${widget.session.themeName!}',
                    style: const TextStyle(
                        color: Color(0xFF444444), fontSize: 10),
                  ),
              ],
            ),
          ),
          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text(
                  '$totalScore',
                  style: const TextStyle(
                    color: Color(0xFFF4F4EC),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundProgressBar(int totalRounds) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(totalRounds, (i) {
          final isDone = i < _currentRoundIndex;
          final isCurrent = i == _currentRoundIndex;
          final round = _session.rounds[i];
          Color color;
          if (isDone) {
            color = round.isSolved
                ? const Color(0xFF4CAF50)
                : const Color(0xFF333333);
          } else if (isCurrent) {
            color = const Color(0xFFD32F2F);
          } else {
            color = const Color(0xFF2A2A2A);
          }
          return Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i < totalRounds - 1 ? 3 : 0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEvidenceIndicator(GameRound round) {
    return Row(
      children: List.generate(round.evidences.length, (i) {
        final isPast = i < round.evidencesRevealed - 1;
        final isCurrent = i == round.evidencesRevealed - 1;
        final e = round.evidences[i];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFFD32F2F).withOpacity(0.15)
                  : isPast
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFF141416),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isCurrent
                    ? const Color(0xFFD32F2F).withOpacity(0.7)
                    : const Color(0xFF222222),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.emoji,
                  style: TextStyle(
                    fontSize: 10,
                    color: isCurrent
                        ? null
                        : const Color(0xFF444444),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'EVIDENCE ${i + 1}',
                  style: TextStyle(
                    color: isCurrent
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF444444),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEvidenceCard(Evidence evidence, GameRound round) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD32F2F).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type badge
          Row(
            children: [
              Text(evidence.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Text(
                evidence.label,
                style: const TextStyle(
                  color: Color(0xFFD32F2F),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content
          Text(
            evidence.content,
            style: const TextStyle(
              color: Color(0xFFF4F4EC),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceDots(GameRound round) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(round.evidences.length, (i) {
        final isActive = i == round.evidencesRevealed - 1;
        final isPast = i < round.evidencesRevealed - 1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFD32F2F)
                : isPast
                    ? const Color(0xFF444444)
                    : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildWrongGuessFeedback(int wrongGuesses) {
    final remaining = 3 - wrongGuesses;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1111),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('❌', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 10),
          Text(
            'Not quite. $remaining guess${remaining == 1 ? '' : 'es'} remaining.',
            style: const TextStyle(color: Color(0xFF888882), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(GameRound round) {
    final canRevealMore =
        round.evidencesRevealed < round.evidences.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Color(0xFF09090B),
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // GUESS button
          SizedBox(
            width: double.infinity,
            child: Material(
              color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: _showGuessOverlay,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded,
                          color: Color(0xFFF4F4EC), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'GUESS MOVIE',
                        style: TextStyle(
                          color: Color(0xFFF4F4EC),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Next Evidence
              Expanded(
                child: Material(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: canRevealMore ? _revealNextEvidence : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Text(
                            'NEXT EVIDENCE',
                            style: TextStyle(
                              color: canRevealMore
                                  ? const Color(0xFF888882)
                                  : const Color(0xFF333333),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            canRevealMore ? '−20 pts' : 'No more',
                            style: const TextStyle(
                                color: Color(0xFF444444), fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Skip
              Expanded(
                child: Material(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: _skipRound,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Text(
                            'SKIP MOVIE',
                            style: TextStyle(
                              color: Color(0xFF575757),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text('0 pts',
                              style: TextStyle(
                                  color: Color(0xFF444444), fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── ROUND RESULT PANEL ───────────────────────────────────────────────────────

  Widget _buildRoundResultPanel(GameRound round) {
    final isSolved = round.isSolved;
    final isLast = _currentRoundIndex >= _session.rounds.length - 1;

    return AnimatedBuilder(
      animation: _resultSlide,
      builder: (context, child) {
        final slideY = (1 - _resultSlide.value) * 200;
        return Transform.translate(
          offset: Offset(0, slideY),
          child: child,
        );
      },
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            border: Border(
              top: BorderSide(
                color: isSolved
                    ? const Color(0xFF4CAF50).withOpacity(0.4)
                    : const Color(0xFF333333),
                width: 1.5,
              ),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Celebration confetti layer (correct only)
              if (isSolved)
                AnimatedBuilder(
                  animation: _celebrationOpacity,
                  builder: (context, _) => Opacity(
                    opacity: _celebrationOpacity.value,
                    child: _buildCelebrationOverlay(),
                  ),
                ),

              // Main content
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status header
                      if (isSolved)
                        _buildSolvedHeader(round)
                      else
                        _buildFailedHeader(round),

                      const SizedBox(height: 20),

                      // Next button
                      SizedBox(
                        width: double.infinity,
                        child: Material(
                          color: isSolved
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: _goToNextRound,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isLast
                                        ? 'SEE FINAL RESULT'
                                        : isSolved
                                            ? 'NEXT MOVIE →'
                                            : 'CONTINUE →',
                                    style: TextStyle(
                                      color: isSolved
                                          ? const Color(0xFFF4F4EC)
                                          : const Color(0xFF888882),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSolvedHeader(GameRound round) {
    return ScaleTransition(
      scale: _celebrationScale,
      child: FadeTransition(
        opacity: _celebrationOpacity,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4CAF50), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            children: [
              // Movie poster + solved badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster
                  SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
                        .animate(CurvedAnimation(parent: _celebrationController, curve: Curves.easeOutBack)),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
                        ]
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: round.posterUrl,
                          width: 64,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Solved badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            '🎬 CASE SOLVED',
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Movie title
                        Text(
                          round.movieTitle.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFF4F4EC),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            fontFamily: 'Impact',
                            letterSpacing: 1.0,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Score
                        Text(
                          'Solved with Evidence ${round.solvedAtEvidence ?? 1}  •  +$_lastRoundScore pts',
                          style: const TextStyle(
                            color: Color(0xFF888882),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Score badge
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _scoreColor(_lastRoundScore).withValues(alpha: 0.15),
                      border: Border.all(
                          color: _scoreColor(_lastRoundScore).withValues(alpha: 0.5),
                          width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '+$_lastRoundScore',
                        style: TextStyle(
                          color: _scoreColor(_lastRoundScore),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Impact',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Interesting fact
              if (round.interestingFact != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09090B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          round.interestingFact!,
                          style: const TextStyle(
                            color: Color(0xFF888882),
                            fontSize: 12,
                            height: 1.4,
                            fontStyle: FontStyle.italic,
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
      ),
    );
  }

  Widget _buildFailedHeader(GameRound round) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: round.posterUrl,
                width: 56,
                height: 84,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.4),
                colorBlendMode: BlendMode.darken,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '📽️ CASE UNSOLVED',
                      style: TextStyle(
                        color: Color(0xFF888882),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    round.movieTitle.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF575757),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      fontFamily: 'Impact',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Better luck on the next one.',
                    style: TextStyle(color: Color(0xFF575757), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCelebrationOverlay() {
    // Simple star burst / glow effect
    return Positioned(
      top: -60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF4CAF50).withOpacity(0.25),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 90) return const Color(0xFF4CAF50);
    if (score >= 70) return const Color(0xFF8BC34A);
    if (score >= 50) return const Color(0xFFFF9800);
    return const Color(0xFFD32F2F);
  }
}

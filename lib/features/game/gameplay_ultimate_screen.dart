import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_models.dart';
import '../../models/movie_model.dart';
import '../../services/game_service.dart';
import 'game_guess_overlay.dart';
import 'game_result_screen.dart';

class GameplayUltimateScreen extends StatefulWidget {
  final GameSession session;
  const GameplayUltimateScreen({super.key, required this.session});

  @override
  State<GameplayUltimateScreen> createState() => _GameplayUltimateScreenState();
}

class _GameplayUltimateScreenState extends State<GameplayUltimateScreen>
    with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  late GameRound _currentRound;
  late DifficultyConfig _config;
  int _currentClueIndex = 0;
  bool _showingGuessOverlay = false;
  String? _lastGuessResult; // 'correct', 'wrong', null

  late final AnimationController _clueController;
  late final Animation<double> _clueFade;
  late final AnimationController _shakeController;
  late final Animation<Offset> _shake;

  @override
  void initState() {
    super.initState();
    _currentRound = widget.session.rounds.first;
    _config = DifficultyConfig.fromEnum(widget.session.difficulty);
    _currentRound.cluesRevealed = 1;

    _clueController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _clueFade = CurvedAnimation(parent: _clueController, curve: Curves.easeOut);
    _clueController.forward();

    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shake = Tween<Offset>(
            begin: Offset.zero, end: const Offset(0.02, 0))
        .animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
  }

  @override
  void dispose() {
    _clueController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _revealNextClue() {
    if (_currentClueIndex >= _currentRound.clues.length - 1) return;
    setState(() {
      _currentClueIndex++;
      _currentRound.cluesRevealed = _currentClueIndex + 1;
      _lastGuessResult = null;
    });
    _clueController.forward(from: 0);
  }

  void _showGuessOverlay() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameGuessOverlay(
        onGuess: _handleGuess,
        attemptsRemaining:
            _config.maxAttempts - _currentRound.wrongGuesses,
      ),
    );
  }

  void _handleGuess(MovieModel? movie) {
    Navigator.pop(context); // close overlay
    if (movie == null) return;

    final isCorrect = movie.id == _currentRound.movieId ||
        movie.title.toLowerCase() == _currentRound.movieTitle.toLowerCase();

    if (isCorrect) {
      HapticFeedback.heavyImpact();
      setState(() {
        _currentRound.isSolved = true;
        _currentRound.solvedAtClue = _currentClueIndex + 1;
        _lastGuessResult = 'correct';
      });
      Future.delayed(const Duration(milliseconds: 800), _finishRound);
    } else {
      HapticFeedback.lightImpact();
      _shakeController.forward(from: 0);
      setState(() {
        _currentRound.wrongGuesses++;
        _lastGuessResult = 'wrong';
      });

      if (_currentRound.wrongGuesses >= _config.maxAttempts) {
        // Game over for this round
        Future.delayed(const Duration(milliseconds: 600), _finishRound);
      }
    }
  }

  void _finishRound() {
    _navigateToResult();
  }

  Future<void> _navigateToResult() async {
    widget.session.rounds[0] = _currentRound;
    final streak = await _gameService.getStreakDays();
    final result = _gameService.buildResult(session: widget.session, streakDays: streak);
    await _gameService.saveResult(result);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameResultScreen(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clues = _currentRound.clues;
    final currentClue = clues.isNotEmpty ? clues[_currentClueIndex] : null;
    final attemptsLeft = _config.maxAttempts - _currentRound.wrongGuesses;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF575757), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'THE ULTIMATE GUESS',
          style: TextStyle(
            color: Color(0xFFF4F4EC),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Clue ${_currentClueIndex + 1} of ${clues.length}',
                style: const TextStyle(
                  color: Color(0xFF575757),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clue progress dots
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: List.generate(clues.length, (i) {
                final revealed = i <= _currentClueIndex;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: i < clues.length - 1 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: revealed
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clue type label
                  if (currentClue != null) ...[
                    Text(
                      currentClue.label,
                      style: const TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Clue content
                    FadeTransition(
                      opacity: _clueFade,
                      child: SlideTransition(
                        position: _shake,
                        child: Text(
                          currentClue.content,
                          style: const TextStyle(
                            color: Color(0xFFF4F4EC),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Wrong guess feedback
                  if (_lastGuessResult == 'wrong') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1111),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFD32F2F).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Text('❌', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Not quite.',
                                  style: TextStyle(
                                    color: Color(0xFFF4F4EC),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '$attemptsLeft attempt${attemptsLeft == 1 ? '' : 's'} remaining',
                                  style: const TextStyle(
                                    color: Color(0xFF888882),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_lastGuessResult == 'correct') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A2A0A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Text('✅', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 10),
                          Text(
                            'Correct! Excellent eye.',
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Bottom action buttons
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _currentRound.isSolved ? null : _showGuessOverlay,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'MAKE A GUESS',
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
                  Row(
                    children: [
                      Expanded(
                        child: _buildSecondaryButton(
                          label: 'SKIP CLUE',
                          sublabel: '−10 points',
                          onTap: _currentClueIndex < clues.length - 1
                              ? () {
                                  setState(() {
                                    _currentRound.wrongGuesses++;
                                  });
                                  _revealNextClue();
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSecondaryButton(
                          label: 'NEXT CLUE',
                          sublabel: 'Free',
                          onTap: _currentClueIndex < clues.length - 1
                              ? _revealNextClue
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required String sublabel,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: onTap != null
                      ? const Color(0xFF888882)
                      : const Color(0xFF333333),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                sublabel,
                style: const TextStyle(
                  color: Color(0xFF444444),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

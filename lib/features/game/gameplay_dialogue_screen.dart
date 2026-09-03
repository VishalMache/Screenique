import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_models.dart';
import '../../models/movie_model.dart';
import '../../data/dialogues_data.dart';
import '../../services/game_service.dart';
import 'game_guess_overlay.dart';
import 'game_result_screen.dart';

class GameplayDialogueScreen extends StatefulWidget {
  final GameSession session;
  const GameplayDialogueScreen({super.key, required this.session});

  @override
  State<GameplayDialogueScreen> createState() => _GameplayDialogueScreenState();
}

class _GameplayDialogueScreenState extends State<GameplayDialogueScreen>
    with SingleTickerProviderStateMixin {
  final GameService _gameService = GameService();
  late GameRound _currentRound;
  late DifficultyConfig _config;

  // Dialogue data
  late MovieDialogue _dialogue;
  bool _showCharacter = false;
  bool _showContext = false;

  String? _lastGuessResult;
  int _currentClueIndex = 1;

  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _currentRound = widget.session.rounds.first;
    _config = DifficultyConfig.fromEnum(widget.session.difficulty);
    _currentRound.cluesRevealed = 1;

    // Pick dialogue — from round data or random
    final movieDialogue = MovieDialogue.dialogues
        .where((d) => d.tmdbId == _currentRound.movieId)
        .toList();
    _dialogue = movieDialogue.isNotEmpty
        ? movieDialogue.first
        : MovieDialogue.getRandom();

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _revealCharacter() {
    setState(() {
      _showCharacter = true;
      _currentClueIndex = 2;
      _currentRound.cluesRevealed = 2;
    });
    _fadeController.forward(from: 0);
  }

  void _revealContext() {
    setState(() {
      _showContext = true;
      _currentClueIndex = 3;
      _currentRound.cluesRevealed = 3;
    });
    _fadeController.forward(from: 0);
  }

  void _showGuessOverlay() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameGuessOverlay(
        onGuess: _handleGuess,
        attemptsRemaining: _config.maxAttempts - _currentRound.wrongGuesses,
      ),
    );
  }

  void _handleGuess(MovieModel? movie) {
    Navigator.pop(context);
    if (movie == null) return;

    final isCorrect = movie.id == _currentRound.movieId ||
        movie.title.toLowerCase() == _currentRound.movieTitle.toLowerCase();

    if (isCorrect) {
      HapticFeedback.heavyImpact();
      setState(() {
        _currentRound.isSolved = true;
        _currentRound.solvedAtClue = _currentClueIndex;
        _lastGuessResult = 'correct';
      });
      Future.delayed(const Duration(milliseconds: 800), _finishRound);
    } else {
      HapticFeedback.lightImpact();
      setState(() {
        _currentRound.wrongGuesses++;
        _lastGuessResult = 'wrong';
      });
      if (_currentRound.wrongGuesses >= _config.maxAttempts) {
        Future.delayed(const Duration(milliseconds: 600), _finishRound);
      }
    }
  }

  Future<void> _finishRound() async {
    widget.session.rounds[0] = _currentRound;
    final streak = await _gameService.getStreakDays();
    final result =
        _gameService.buildResult(session: widget.session, streakDays: streak);
    await _gameService.saveResult(result);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => GameResultScreen(result: result)));
  }

  @override
  Widget build(BuildContext context) {
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
          'DIALOGUE',
          style: TextStyle(
            color: Color(0xFFF4F4EC),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Clue $_currentClueIndex of ${_config.maxClues}',
                style: const TextStyle(color: Color(0xFF575757), fontSize: 11),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress
            Row(
              children: List.generate(_config.maxClues, (i) => Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i < _config.maxClues - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i < _currentClueIndex
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 24),
            // Dialogue type label
            const Text(
              'DIALOGUE CLUE',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 20),
            // Quote
            FadeTransition(
              opacity: _fade,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Text(
                  '"${_dialogue.quote}"',
                  style: const TextStyle(
                    color: Color(0xFFF4F4EC),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Character + Context tabs
            Row(
              children: [
                _buildTabChip(
                  label: 'CHARACTER',
                  revealed: _showCharacter,
                  onTap: _showCharacter ? null : _revealCharacter,
                  revealedContent: _dialogue.character,
                ),
                const SizedBox(width: 10),
                _buildTabChip(
                  label: 'CONTEXT',
                  revealed: _showContext,
                  onTap: (!_showCharacter || _showContext) ? null : _revealContext,
                  revealedContent: _dialogue.genre,
                ),
              ],
            ),
            const Spacer(),
            // Feedback
            if (_lastGuessResult == 'wrong') ...[
              _buildFeedbackRow(
                  '❌ Not quite. $attemptsLeft attempt${attemptsLeft == 1 ? '' : 's'} remaining.'),
              const SizedBox(height: 12),
            ],
            if (_lastGuessResult == 'correct') ...[
              _buildFeedbackRow('✅ Correct! You know your lines.', isCorrect: true),
              const SizedBox(height: 12),
            ],
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
                Expanded(child: _buildSecBtn('SKIP CLUE', '−10 pts', null)),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSecBtn(
                    'NEXT CLUE',
                    'Free',
                    !_showCharacter
                        ? _revealCharacter
                        : (!_showContext ? _revealContext : null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    required bool revealed,
    required VoidCallback? onTap,
    required String revealedContent,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: revealed ? const Color(0xFF1E1010) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: revealed ? const Color(0xFFD32F2F).withOpacity(0.4) : const Color(0xFF2A2A2A),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: revealed ? const Color(0xFFD32F2F) : const Color(0xFF575757),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  if (!revealed) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.touch_app_rounded, color: Color(0xFF444444), size: 12),
                  ],
                ],
              ),
              if (revealed) ...[
                const SizedBox(height: 4),
                Text(
                  revealedContent,
                  style: const TextStyle(
                    color: Color(0xFFF4F4EC),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackRow(String text, {bool isCorrect = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFF0A2A0A) : const Color(0xFF2A1111),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isCorrect ? const Color(0xFF4CAF50) : const Color(0xFF888882),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSecBtn(String label, String sublabel, VoidCallback? onTap) {
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
              Text(label,
                  style: TextStyle(
                    color: onTap != null ? const Color(0xFF888882) : const Color(0xFF333333),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  )),
              Text(sublabel,
                  style: const TextStyle(color: Color(0xFF444444), fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}

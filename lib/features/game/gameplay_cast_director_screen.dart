import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_models.dart';
import '../../models/movie_model.dart';
import '../../services/game_service.dart';
import 'game_guess_overlay.dart';
import 'game_result_screen.dart';

class GameplayCastDirectorScreen extends StatefulWidget {
  final GameSession session;
  const GameplayCastDirectorScreen({super.key, required this.session});

  @override
  State<GameplayCastDirectorScreen> createState() =>
      _GameplayCastDirectorScreenState();
}

class _GameplayCastDirectorScreenState
    extends State<GameplayCastDirectorScreen> with SingleTickerProviderStateMixin {
  final GameService _gameService = GameService();
  late GameRound _currentRound;
  late DifficultyConfig _config;

  int _revealedNames = 1; // Start with 1 cast name
  String? _lastGuessResult;

  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _currentRound = widget.session.rounds.first;
    _config = DifficultyConfig.fromEnum(widget.session.difficulty);
    _currentRound.cluesRevealed = 1;

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

  List<Map<String, String>> get _allClues {
    final clues = <Map<String, String>>[];
    final cast = _currentRound.castNames;
    for (int i = 0; i < cast.length; i++) {
      final role = i == 0 ? 'SUPPORTING CAST' : (i == cast.length - 1 ? 'LEAD ACTOR' : 'CAST MEMBER');
      clues.add({'role': role, 'name': cast[i]});
    }
    if (_currentRound.directorName != null) {
      clues.add({'role': 'DIRECTOR', 'name': _currentRound.directorName!});
    }
    return clues;
  }

  void _revealNext() {
    final total = _allClues.length;
    if (_revealedNames >= total) return;
    setState(() {
      _revealedNames++;
      _currentRound.cluesRevealed = _revealedNames;
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
        _currentRound.solvedAtClue = _revealedNames;
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
    final clues = _allClues;
    final revealed = clues.take(_revealedNames).toList();
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
          'CAST + DIRECTOR',
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
                '$_revealedNames / ${clues.length} revealed',
                style: const TextStyle(color: Color(0xFF575757), fontSize: 11),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Row(
              children: List.generate(clues.length, (i) => Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i < clues.length - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i < _revealedNames
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'CONNECT THE NAMES',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Revealed name cards
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: revealed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final clue = revealed[i];
                final isDirector = clue['role'] == 'DIRECTOR';
                return FadeTransition(
                  opacity: i == revealed.length - 1 ? _fade : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDirector
                          ? const Color(0xFF1E0A0A)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDirector
                            ? const Color(0xFFD32F2F).withOpacity(0.4)
                            : const Color(0xFF2A2A2A),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDirector
                                ? const Color(0xFFD32F2F).withOpacity(0.15)
                                : const Color(0xFF222222),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              isDirector
                                  ? Icons.movie_filter_rounded
                                  : Icons.person_rounded,
                              color: isDirector
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFF575757),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clue['role']!,
                              style: TextStyle(
                                color: isDirector
                                    ? const Color(0xFFD32F2F)
                                    : const Color(0xFF575757),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              clue['name']!,
                              style: const TextStyle(
                                color: Color(0xFFF4F4EC),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Feedback
          if (_lastGuessResult == 'wrong')
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF2A1111),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '❌ Not quite. $attemptsLeft attempt${attemptsLeft == 1 ? '' : 's'} remaining.',
                  style: const TextStyle(color: Color(0xFF888882), fontSize: 12),
                ),
              ),
            ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: SizedBox(
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                Expanded(child: _buildSecBtn('SKIP CLUE', '−10 pts', null)),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSecBtn(
                    'NEXT NAME',
                    'Free',
                    _revealedNames < clues.length ? _revealNext : null,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                    color: onTap != null
                        ? const Color(0xFF888882)
                        : const Color(0xFF333333),
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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/game_models.dart';
import '../../models/movie_model.dart';
import '../../services/game_service.dart';
import 'game_guess_overlay.dart';
import 'game_result_screen.dart';

class GameplayBlurPosterScreen extends StatefulWidget {
  final GameSession session;
  const GameplayBlurPosterScreen({super.key, required this.session});

  @override
  State<GameplayBlurPosterScreen> createState() =>
      _GameplayBlurPosterScreenState();
}

class _GameplayBlurPosterScreenState extends State<GameplayBlurPosterScreen>
    with SingleTickerProviderStateMixin {
  final GameService _gameService = GameService();
  late GameRound _currentRound;
  late DifficultyConfig _config;

  // Blur stages: percentage labels and sigma values
  static const _blurStages = [
    {'label': '95%', 'sigma': 40.0},
    {'label': '80%', 'sigma': 28.0},
    {'label': '60%', 'sigma': 18.0},
    {'label': '40%', 'sigma': 10.0},
    {'label': '20%', 'sigma': 5.0},
    {'label': '0%', 'sigma': 0.0},
  ];

  int _stageIndex = 0;
  String? _lastGuessResult;

  late final AnimationController _blurController;
  late final Animation<double> _blurAnim;
  double _currentSigma = 40.0;

  @override
  void initState() {
    super.initState();
    _currentRound = widget.session.rounds.first;
    _config = DifficultyConfig.fromEnum(widget.session.difficulty);
    _currentRound.cluesRevealed = 1;

    _blurController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _blurAnim = _blurController.view;
    _currentSigma = (_blurStages[_stageIndex]['sigma'] as double);
  }

  @override
  void dispose() {
    _blurController.dispose();
    super.dispose();
  }

  void _nextStage() {
    if (_stageIndex >= _blurStages.length - 1) return;
    final fromSigma = _currentSigma;
    final toSigma = _blurStages[_stageIndex + 1]['sigma'] as double;

    _blurController.reset();
    _blurAnim.addListener(() {
      if (mounted) {
        setState(() {
          _currentSigma = lerpDouble(fromSigma, toSigma, _blurController.value)!;
        });
      }
    });
    _blurController.forward();

    setState(() {
      _stageIndex++;
      _currentRound.cluesRevealed = _stageIndex + 1;
    });
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
        _currentRound.solvedAtClue = _stageIndex + 1;
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
    final currentStageLabel =
        _blurStages[_stageIndex]['label'] as String;
    final attemptsLeft = _config.maxAttempts - _currentRound.wrongGuesses;
    final posterUrl = _currentRound.posterUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF575757), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'BLUR POSTER',
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
                'Clue ${_stageIndex + 1} of ${_blurStages.length}',
                style: const TextStyle(color: Color(0xFF575757), fontSize: 11),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: List.generate(_blurStages.length, (i) => Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i < _blurStages.length - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i <= _stageIndex
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
          ),
          // Blurred poster
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: posterUrl,
                      fit: BoxFit.cover,
                    ),
                    // Blur overlay
                    BackdropFilter(
                      filter: ImageFilter.blur(
                          sigmaX: _currentSigma, sigmaY: _currentSigma),
                      child: Container(color: Colors.transparent),
                    ),
                    // Blur % badge
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$currentStageLabel BLUR',
                          style: const TextStyle(
                            color: Color(0xFFF4F4EC),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Blur stage pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: _blurStages.asMap().entries.map((entry) {
                final i = entry.key;
                final stage = entry.value;
                final isPast = i <= _stageIndex;
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isPast
                        ? const Color(0xFFD32F2F).withOpacity(0.2)
                        : const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: isPast
                            ? const Color(0xFFD32F2F).withOpacity(0.5)
                            : const Color(0xFF2A2A2A)),
                  ),
                  child: Text(
                    stage['label'] as String,
                    style: TextStyle(
                      color: isPast
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF444444),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Feedback
          if (_lastGuessResult == 'wrong')
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF2A1111),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(
                  '❌ Not quite. $attemptsLeft attempt${attemptsLeft == 1 ? '' : 's'} remaining.',
                  style: const TextStyle(
                      color: Color(0xFF888882), fontSize: 12),
                ),
              ),
            ),
          if (_lastGuessResult == 'correct')
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                '✅ You saw it before it was clear. Impressive.',
                style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12),
              ),
            ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: SizedBox(
              width: double.infinity,
              child: Material(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
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
                Expanded(
                  child: _buildSecBtn('SKIP CLUE', '−10 pts', null),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSecBtn(
                    'NEXT CLUE',
                    'Free',
                    _stageIndex < _blurStages.length - 1 ? _nextStage : null,
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
      color: const Color(0xFF141416),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
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
                  style: const TextStyle(
                      color: Color(0xFF444444), fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}

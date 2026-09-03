import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import '../../services/game_service.dart';
import 'gameplay_ultimate_screen.dart';
import 'gameplay_dialogue_screen.dart';
import 'gameplay_blur_poster_screen.dart';
import 'gameplay_cast_director_screen.dart';

class ChooseGuessModeScreen extends StatefulWidget {
  final ChallengeType challengeType;
  final GameDifficulty difficulty;
  final ThemeCategory? selectedTheme;
  final int? customGenreId;
  final int? customYearFrom;
  final int? customYearTo;
  final int? customPersonId;
  final String? customLabel;

  const ChooseGuessModeScreen({
    super.key,
    required this.challengeType,
    required this.difficulty,
    this.selectedTheme,
    this.customGenreId,
    this.customYearFrom,
    this.customYearTo,
    this.customPersonId,
    this.customLabel,
  });

  @override
  State<ChooseGuessModeScreen> createState() => _ChooseGuessModeScreenState();
}

class _ChooseGuessModeScreenState extends State<ChooseGuessModeScreen>
    with SingleTickerProviderStateMixin {
  GuessMode _selected = GuessMode.ultimate;
  bool _loading = false;

  late final AnimationController _controller;
  late final Animation<double> _fade;

  final GameService _gameService = GameService();

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

  Future<void> _startGame() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      switch (widget.challengeType) {
        case ChallengeType.quickMix:
          final round = await _gameService.getQuickMixRound(
            difficulty: widget.difficulty,
            guessMode: _selected,
          );
          if (!mounted) return;
          if (round == null) {
            _showError('Could not load a movie. Please try again.');
            return;
          }
          final session = GameSession(
            challengeType: ChallengeType.quickMix,
            difficulty: widget.difficulty,
            guessMode: _selected,
            rounds: [round],
          );
          _navigateToGameplay(session);
          break;

        case ChallengeType.themed:
          if (widget.selectedTheme == null) return;
          final rounds = await _gameService.getThemedRounds(
            theme: widget.selectedTheme!,
            difficulty: widget.difficulty,
            guessMode: _selected,
          );
          if (!mounted) return;
          if (rounds.isEmpty) {
            _showError('Could not load movies for this theme.');
            return;
          }
          final session = GameSession(
            challengeType: ChallengeType.themed,
            themeName: widget.selectedTheme!.name,
            themeEmoji: widget.selectedTheme!.emoji,
            difficulty: widget.difficulty,
            guessMode: _selected,
            rounds: rounds,
          );
          _navigateToGameplay(session);
          break;

        case ChallengeType.custom:
          final rounds = await _gameService.getCustomRounds(
            genreId: widget.customGenreId,
            yearFrom: widget.customYearFrom,
            yearTo: widget.customYearTo,
            personId: widget.customPersonId,
            difficulty: widget.difficulty,
            guessMode: _selected,
          );
          if (!mounted) return;
          if (rounds.isEmpty) {
            _showError('Could not load movies for your custom settings.');
            return;
          }
          final session = GameSession(
            challengeType: ChallengeType.custom,
            themeName: widget.customLabel ?? 'Custom',
            difficulty: widget.difficulty,
            guessMode: _selected,
            rounds: rounds,
          );
          _navigateToGameplay(session);
          break;
      }
    } catch (e) {
      if (mounted) _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToGameplay(GameSession session) {
    Widget screen;
    switch (_selected) {
      case GuessMode.ultimate:
        screen = GameplayUltimateScreen(session: session);
        break;
      case GuessMode.dialogue:
        screen = GameplayDialogueScreen(session: session);
        break;
      case GuessMode.blurPoster:
        screen = GameplayBlurPosterScreen(session: session);
        break;
      case GuessMode.castDirector:
        screen = GameplayCastDirectorScreen(session: session);
        break;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static const List<Map<String, dynamic>> _modes = [
    {
      'mode': GuessMode.ultimate,
      'emoji': '⭐',
      'title': 'THE ULTIMATE GUESS',
      'subtitle': 'The complete Screenique experience.',
      'description':
          'Start with a plot clue. Receive progressively different hints — character, director, cast, and facts. The earlier you guess, the higher your score.',
      'featured': true,
    },
    {
      'mode': GuessMode.dialogue,
      'emoji': '💬',
      'title': 'DIALOGUE',
      'subtitle': 'Recognize the movie from its words.',
      'description':
          'A famous line is your only clue. Request the character name or context for hints.',
      'featured': false,
    },
    {
      'mode': GuessMode.blurPoster,
      'emoji': '🖼️',
      'title': 'BLUR POSTER',
      'subtitle': 'The less you see, the more you know.',
      'description':
          'Start at 95% blur. The poster clears in stages — guess before it\'s fully revealed.',
      'featured': false,
    },
    {
      'mode': GuessMode.castDirector,
      'emoji': '🎭',
      'title': 'CAST + DIRECTOR',
      'subtitle': 'Connect the names. Find the movie.',
      'description':
          'Actor names and the director are your only clues. Which film connects them all?',
      'featured': false,
    },
  ];

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
          'HOW DO YOU WANT TO GUESS?',
          style: TextStyle(
            color: Color(0xFFF4F4EC),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: _modes
                      .map((m) => _buildModeCard(
                            mode: m['mode'] as GuessMode,
                            emoji: m['emoji'] as String,
                            title: m['title'] as String,
                            subtitle: m['subtitle'] as String,
                            description: m['description'] as String,
                            featured: m['featured'] as bool,
                          ))
                      .toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: Material(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _loading ? null : _startGame,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _loading
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFF4F4EC)),
                                ),
                              ),
                            )
                          : const Text(
                              'START GAME →',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required GuessMode mode,
    required String emoji,
    required String title,
    required String subtitle,
    required String description,
    required bool featured,
  }) {
    final isSelected = _selected == mode;
    return GestureDetector(
      onTap: () => setState(() => _selected = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD32F2F).withOpacity(0.1)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD32F2F)
                : const Color(0xFF2A2A2A),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFD32F2F).withOpacity(0.2)
                    : const Color(0xFF222222),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFF4F4EC)
                              : const Color(0xFF888882),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (featured) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              color: Color(0xFFF4F4EC),
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF575757),
                      fontSize: 11,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF888882),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFFD32F2F), size: 20),
          ],
        ),
      ),
    );
  }
}

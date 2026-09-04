import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import '../../services/game_service.dart';
import 'gameplay_screen.dart';

class GameReadyScreen extends StatefulWidget {
  final ChallengeType challengeType;
  final ThemeCategory? selectedTheme;

  const GameReadyScreen({
    super.key,
    required this.challengeType,
    this.selectedTheme,
  });

  @override
  State<GameReadyScreen> createState() => _GameReadyScreenState();
}

class _GameReadyScreenState extends State<GameReadyScreen>
    with TickerProviderStateMixin {
  final GameService _gameService = GameService();

  List<GameRound>? _rounds;
  String? _errorMessage;
  bool _isLoading = true;

  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _fadeController.forward();
    _loadRounds();
  }

  Future<void> _loadRounds() async {
    try {
      List<GameRound> rounds;
      if (widget.challengeType == ChallengeType.quickMix) {
        rounds = await _gameService.getQuickMixRounds();
      } else {
        rounds = await _gameService.getThemedRounds(
          theme: widget.selectedTheme!,
        );
      }

      if (!mounted) return;
      setState(() {
        _rounds = rounds;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load movies. Check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  void _startGame() {
    if (_rounds == null || _rounds!.isEmpty) return;
    final session = GameSession(
      challengeType: widget.challengeType,
      themeName: widget.selectedTheme?.name,
      themeEmoji: widget.selectedTheme?.emoji,
      rounds: _rounds!,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => GameplayScreen(session: session)),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThemed = widget.challengeType == ChallengeType.themed;
    final challengeTitle = isThemed
        ? (widget.selectedTheme?.name.toUpperCase() ?? 'THEMED')
        : 'QUICK MIX';
    final challengeEmoji = isThemed
        ? (widget.selectedTheme?.emoji ?? '🎞️')
        : '⚡';

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Back
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF575757), size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const Spacer(flex: 2),

                // Challenge badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$challengeEmoji  $challengeTitle',
                    style: const TextStyle(
                      color: Color(0xFFD32F2F),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Main headline
                const Text(
                  '10 MOVIES',
                  style: TextStyle(
                    color: Color(0xFFF4F4EC),
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    fontFamily: 'Impact',
                    height: 0.95,
                    shadows: [
                      Shadow(
                        color: Color(0x60D32F2F),
                        offset: Offset(0, 6),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'READY?',
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    fontFamily: 'Impact',
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '3–4 pieces of evidence per film.\nGuess early. Score higher.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF575757),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),

                const Spacer(flex: 3),

                // Loading / CTA
                _isLoading ? _buildLoadingState() : _buildReadyState(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD32F2F).withValues(alpha: 0.1),
              border: Border.all(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.3), width: 1.5),
            ),
            child: const Icon(
              Icons.movie_filter_rounded,
              color: Color(0xFFD32F2F),
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'SELECTING YOUR FILMS...',
          style: TextStyle(
            color: Color(0xFF575757),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }

  Widget _buildReadyState() {
    if (_errorMessage != null) {
      return Column(
        children: [
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF888882), fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _loadRounds();
            },
            child: const Text('TRY AGAIN',
                style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5)),
          ),
        ],
      );
    }

    // Loaded — show start button
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.circle, color: Color(0xFF4CAF50), size: 7),
            const SizedBox(width: 8),
            Text(
              '${_rounds!.length} films loaded',
              style: const TextStyle(
                color: Color(0xFF575757),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ]
            ),
            child: Material(
              color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _startGame,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'START GUESSING',
                        style: TextStyle(
                          color: Color(0xFFF4F4EC),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Impact',
                          letterSpacing: 2.0,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded,
                          color: Color(0xFFF4F4EC), size: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

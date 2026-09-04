import 'package:flutter/material.dart';
import '../../services/game_service.dart';
import 'choose_challenge_screen.dart';

class GameHubScreen extends StatefulWidget {
  const GameHubScreen({super.key});

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen>
    with TickerProviderStateMixin {
  final GameService _gameService = GameService();

  int _xp = 0;
  int _played = 0;
  int _streak = 0;
  String _levelTitle = '🍿 Casual Viewer';

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  late final AnimationController _cardController;
  late final Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _cardController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic));
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _gameService.getPlayerStats();
    if (mounted) {
      setState(() {
        _xp = stats['xp'] as int;
        _played = stats['played'] as int;
        _streak = stats['streak'] as int;
        _levelTitle = stats['levelTitle'] as String;
      });
      _fadeController.forward();
      _cardController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD32F2F).withOpacity(0.15),
                // Blur effect
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD32F2F).withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildStatsBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  child: SlideTransition(
                    position: _cardSlide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildSectionLabel('AVAILABLE NOW'),
                        const SizedBox(height: 12),
                        _buildScreeniqueGuessCard(),
                        const SizedBox(height: 32),
                        _buildSectionLabel('COMING SOON'),
                        const SizedBox(height: 12),
                        _buildComingSoonCard(
                          title: 'SCREENIQUE TRIVIA',
                          icon: Icons.psychology_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildComingSoonCard(
                          title: 'FRAME GAME',
                          icon: Icons.image_rounded,
                        ),
                      ],
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
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'ARCADE',
            style: TextStyle(
              color: Color(0xFFF4F4EC),
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              fontFamily: 'Impact',
              shadows: [Shadow(color: Color(0xFFD32F2F), blurRadius: 20)],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_xp XP',
                style: const TextStyle(
                  color: Color(0xFFD32F2F),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                _levelTitle.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF888882),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildHudItem(Icons.local_fire_department_rounded, '$_streak', 'DAY STREAK', const Color(0xFFFF9800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildHudItem(Icons.sports_esports_rounded, '$_played', 'GAMES PLAYED', const Color(0xFF4CAF50)),
          ),
        ],
      ),
    );
  }

  Widget _buildHudItem(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: Color(0xFF575757), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF575757),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
    );
  }

  Widget _buildScreeniqueGuessCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChooseChallengeScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF141416),
          border: Border.all(color: const Color(0xFFD32F2F), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD32F2F).withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Abstract geometric background pattern
            Positioned(
              right: -50,
              top: -50,
              child: Icon(
                Icons.movie_filter_rounded,
                size: 250,
                color: const Color(0xFFD32F2F).withOpacity(0.05),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PLAY NOW',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Text(
                          'THE\nSCREENIQUE\nGUESS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Impact',
                            height: 1.1,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD32F2F).withOpacity(0.5),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonCard({
    required String title,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF575757), size: 32),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF575757),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const Icon(Icons.lock_rounded, color: Color(0xFF333333), size: 20),
        ],
      ),
    );
  }
}

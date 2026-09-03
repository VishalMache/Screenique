import 'package:flutter/material.dart';
import '../../services/game_service.dart';
import 'game_intro_screen.dart';

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
                          title: 'Screenique Trivia',
                          subtitle: 'Test your cinema knowledge',
                          emoji: '🧠',
                        ),
                        const SizedBox(height: 12),
                        _buildComingSoonCard(
                          title: 'Frame Game',
                          subtitle: 'Identify the movie from a single frame',
                          emoji: '🖼️',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videogame_asset_rounded,
                  color: Color(0xFFD32F2F), size: 22),
              const SizedBox(width: 8),
              const Text(
                'GAME SECTION',
                style: TextStyle(
                  color: Color(0xFFD32F2F),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'CHOOSE YOUR\nARENA.',
            style: TextStyle(
              color: Color(0xFFF4F4EC),
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -1.0,
              fontFamily: 'Impact',
              shadows: [
                Shadow(
                  color: Color(0x80D32F2F),
                  offset: Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _streak > 0
                ? '🔥 $_streak day streak · $_xp XP earned'
                : '$_xp XP earned · $_played games played',
            style: const TextStyle(
              color: Color(0xFF888882),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD32F2F).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('🏅', _levelTitle.split(' ').last, 'RANK'),
          _buildStatDivider(),
          _buildStatItem('🎮', '$_played', 'PLAYED'),
          _buildStatDivider(),
          _buildStatItem('⚡', '$_xp', 'XP'),
          _buildStatDivider(),
          _buildStatItem('🔥', '$_streak', 'STREAK'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF4F4EC),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF575757),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1, 
      height: 36, 
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2A2A2A).withOpacity(0.0),
            const Color(0xFFD32F2F).withOpacity(0.5),
            const Color(0xFF2A2A2A).withOpacity(0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF575757),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: Color(0xFF2A2A2A), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildScreeniqueGuessCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GameIntroScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2B0A0A), Color(0xFF1A0505), Color(0xFF0F0F0F)],
          ),
          border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD32F2F).withOpacity(0.25),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top decorative film strip area
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                color: const Color(0xFF1A0808),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Film reel decorative pattern
                  Positioned.fill(
                    child: CustomPaint(painter: _FilmStripPainter()),
                  ),
                  // Center content
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFD32F2F).withOpacity(0.15),
                            border: Border.all(
                                color: const Color(0xFFD32F2F).withOpacity(0.5),
                                width: 1.5),
                          ),
                          child: const Icon(
                            Icons.movie_filter_rounded,
                            color: Color(0xFFD32F2F),
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'THE SCREENIQUE GUESS',
                          style: TextStyle(
                            color: Color(0xFFF4F4EC),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            fontFamily: 'Impact',
                            shadows: [
                              Shadow(color: Color(0xFFD32F2F), blurRadius: 10)
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Every movie leaves clues.',
                          style: TextStyle(
                            color: Color(0xFF888882),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tag pill
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🎬 MOVIE GUESSING',
                        style: TextStyle(
                          color: Color(0xFFF4F4EC),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom action area
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '4 GAME MODES',
                          style: TextStyle(
                            color: Color(0xFFD32F2F),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Plot • Dialogue • Blur Poster • Cast',
                          style: TextStyle(
                            color: Color(0xFF888882),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'PLAY NOW',
                          style: TextStyle(
                            color: Color(0xFFF4F4EC),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.sports_esports_rounded,
                            color: Color(0xFFF4F4EC), size: 16),
                      ],
                    ),
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
    required String subtitle,
    required String emoji,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF575757),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF3A3A3A),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: Color(0xFF444444), size: 11),
                SizedBox(width: 4),
                Text(
                  'SOON',
                  style: TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FILM STRIP PAINTER ────────────────────────────────────────────────────────
class _FilmStripPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A0A0A)
      ..style = PaintingStyle.fill;

    // Draw film perforations along the top and bottom
    const double holeDiam = 10;
    const double holeSpacing = 18;
    const double holeMargin = 10;

    for (double x = holeSpacing; x < size.width; x += holeSpacing * 1.5) {
      // Top holes
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x, holeMargin), width: holeDiam, height: holeDiam),
          const Radius.circular(2),
        ),
        paint,
      );
      // Bottom holes
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x, size.height - holeMargin),
              width: holeDiam,
              height: holeDiam),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FilmStripPainter _) => false;
}

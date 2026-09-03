import 'package:flutter/material.dart';
import '../../data/game_themes_data.dart';
import '../../models/game_models.dart';
import '../../services/game_service.dart';
import 'choose_difficulty_screen.dart';

class ThemedChallengeScreen extends StatefulWidget {
  const ThemedChallengeScreen({super.key});

  @override
  State<ThemedChallengeScreen> createState() => _ThemedChallengeScreenState();
}

class _ThemedChallengeScreenState extends State<ThemedChallengeScreen>
    with SingleTickerProviderStateMixin {
  final GameService _gameService = GameService();
  String _selectedGroup = 'POPULAR';
  ThemeCategory? _selectedTheme;
  List<String> _recentThemes = [];

  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final recent = await _gameService.getRecentThemes();
    if (mounted) setState(() => _recentThemes = recent);
  }

  void _selectGroup(String group) {
    setState(() {
      _selectedGroup = group;
      _selectedTheme = null;
      _controller.forward(from: 0);
    });
  }

  void _selectTheme(ThemeCategory theme) {
    setState(() => _selectedTheme = theme);
  }

  void _proceed() {
    if (_selectedTheme == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChooseDifficultyScreen(
          challengeType: ChallengeType.themed,
          selectedTheme: _selectedTheme,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFF4F4EC), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'THEMED CHALLENGE',
          style: TextStyle(
            color: Color(0xFFF4F4EC),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              'CHOOSE A CATEGORY',
              style: TextStyle(
                color: Color(0xFF575757),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
          // Group selector grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: themeGroups.map((g) => _buildGroupChip(g)).toList(),
            ),
          ),
          const SizedBox(height: 20),
          // Subcategory list
          Expanded(
            child: FadeTransition(
              opacity: _fade,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...categoriesByGroup(_selectedGroup)
                        .map((theme) => _buildThemeRow(theme)),
                    if (_selectedTheme != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141416).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ABOUT THIS CATEGORY',
                                style: const TextStyle(
                                  color: Color(0xFF575757),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedTheme!.description,
                                style: const TextStyle(
                                  color: Color(0xFF888882),
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_recentThemes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'YOUR RECENT',
                          style: TextStyle(
                            color: Color(0xFF575757),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: _recentThemes
                              .take(3)
                              .map((t) => _buildRecentChip(t))
                              .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          // Bottom CTA
          if (_selectedTheme != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: Material(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: _proceed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${_selectedTheme!.emoji} PLAY ${_selectedTheme!.name.toUpperCase()}',
                            style: const TextStyle(
                              color: Color(0xFFF4F4EC),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Color(0xFFF4F4EC), size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupChip(String group) {
    final isSelected = _selectedGroup == group;
    final emoji = groupEmojis[group] ?? '';
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectGroup(group),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFFD32F2F) : const Color(0xFF141416),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFFD32F2F).withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                group,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFF4F4EC)
                      : const Color(0xFF575757),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeRow(ThemeCategory theme) {
    final isSelected = _selectedTheme?.id == theme.id;
    return GestureDetector(
      onTap: () => _selectTheme(theme),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD32F2F).withOpacity(0.15)
              : const Color(0xFF141416).withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD32F2F)
                : const Color(0xFFD32F2F).withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Text(theme.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                theme.name,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFF4F4EC)
                      : const Color(0xFF888882),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: isSelected
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFF333333),
              size: isSelected ? 20 : 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentChip(String name) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3)),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Color(0xFF888882),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/movie_model.dart';
import '../../services/taste_profile_service.dart';

/// Cold-start onboarding quiz shown to users with 0 watched movies.
/// Saves genre preferences to the taste profile and marks onboardingComplete.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final Set<int> _selectedGenres = {};
  bool _isSaving = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const List<_GenreOption> _genres = [
    _GenreOption(id: 878,  label: 'SCI-FI',      emoji: '🚀'),
    _GenreOption(id: 18,   label: 'DRAMA',        emoji: '🎭'),
    _GenreOption(id: 28,   label: 'ACTION',       emoji: '💥'),
    _GenreOption(id: 27,   label: 'HORROR',       emoji: '👁️'),
    _GenreOption(id: 35,   label: 'COMEDY',       emoji: '😂'),
    _GenreOption(id: 53,   label: 'THRILLER',     emoji: '🔪'),
    _GenreOption(id: 10749,label: 'ROMANCE',      emoji: '❤️'),
    _GenreOption(id: 14,   label: 'FANTASY',      emoji: '🧙'),
    _GenreOption(id: 12,   label: 'ADVENTURE',    emoji: '🗺️'),
    _GenreOption(id: 16,   label: 'ANIMATION',    emoji: '✏️'),
    _GenreOption(id: 80,   label: 'CRIME',        emoji: '🕵️'),
    _GenreOption(id: 99,   label: 'DOCUMENTARY',  emoji: '🎙️'),
    _GenreOption(id: 9648, label: 'MYSTERY',      emoji: '🔍'),
    _GenreOption(id: 36,   label: 'HISTORY',      emoji: '📜'),
    _GenreOption(id: 10752,label: 'WAR',          emoji: '⚔️'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (_selectedGenres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PICK AT LEAST ONE GENRE TO BEGIN',
            style: TextStyle(color: Color(0xFFF4F4EC), fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Color(0xFFD32F2F),
      ));
      return;
    }
    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await TasteProfileService()
            .saveOnboardingPreferences(uid, _selectedGenres.toList());
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        widget.onComplete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      color: const Color(0xFFD32F2F),
                      child: const Text('WELCOME TO SCREENIQUE',
                          style: TextStyle(
                              color: Color(0xFFF4F4EC),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'WHAT GENRES\nDO YOU LIVE FOR?',
                      style: TextStyle(
                        color: Color(0xFFF4F4EC),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Impact',
                        letterSpacing: 1,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select all that speak to your cinematic soul.\nWe\'ll calibrate your Archival DNA from these.',
                      style: TextStyle(
                        color: const Color(0xFFF4F4EC).withValues(alpha: 0.5),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Divider(color: Color(0xFF2A2A2A), thickness: 1.5),
              ),
              const SizedBox(height: 16),

              // ── Genre Grid ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: _genres.length,
                    itemBuilder: (context, index) {
                      final genre = _genres[index];
                      final isSelected = _selectedGenres.contains(genre.id);
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (isSelected) {
                              _selectedGenres.remove(genre.id);
                            } else {
                              _selectedGenres.add(genre.id);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFF1A1A1A),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFF2A2A2A),
                              width: 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    const BoxShadow(
                                        color: Color(0x50D32F2F),
                                        blurRadius: 8,
                                        offset: Offset(0, 2))
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(genre.emoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(height: 4),
                              Text(
                                genre.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFF4F4EC)
                                      : const Color(0xFF888882),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── CTA ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  children: [
                    Text(
                      '${_selectedGenres.length} SELECTED',
                      style: TextStyle(
                        color: _selectedGenres.isEmpty
                            ? const Color(0xFF444444)
                            : const Color(0xFFD32F2F),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _isSaving ? null : _saveAndContinue,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _selectedGenres.isEmpty
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFFD32F2F),
                          border: Border.all(
                              color: _selectedGenres.isEmpty
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFD32F2F),
                              width: 1.5),
                          boxShadow: _selectedGenres.isNotEmpty
                              ? const [
                                  BoxShadow(
                                      color: Color(0xFF111111),
                                      offset: Offset(3, 3))
                                ]
                              : null,
                        ),
                        child: Center(
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Color(0xFFF4F4EC), strokeWidth: 2))
                              : const Text(
                                  'ENTER THE ARCHIVE →',
                                  style: TextStyle(
                                    color: Color(0xFFF4F4EC),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    fontFamily: 'Impact',
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: widget.onComplete,
                      child: Text(
                        'SKIP FOR NOW',
                        style: TextStyle(
                          color: const Color(0xFFF4F4EC).withValues(alpha: 0.3),
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreOption {
  final int id;
  final String label;
  final String emoji;
  const _GenreOption(
      {required this.id, required this.label, required this.emoji});
}

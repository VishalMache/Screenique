import 'dart:async';
import 'package:flutter/material.dart';
import '../data/dialogues_data.dart';

class DialogueHeroWidget extends StatefulWidget {
  final List<MovieDialogue> dialogues;
  final int currentIndex;
  final VoidCallback onForgeTap;
  final ValueChanged<int> onIndexChanged;

  const DialogueHeroWidget({
    super.key,
    required this.dialogues,
    required this.currentIndex,
    required this.onForgeTap,
    required this.onIndexChanged,
  });

  @override
  State<DialogueHeroWidget> createState() => _DialogueHeroWidgetState();
}

class _DialogueHeroWidgetState extends State<DialogueHeroWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  Timer? _autoRotateTimer;
  int _localIndex = 0;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _localIndex = widget.currentIndex;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
    _startAutoRotation();
  }

  @override
  void didUpdateWidget(DialogueHeroWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex && widget.currentIndex != _localIndex) {
      _animateTo(widget.currentIndex);
    }
  }

  void _startAutoRotation() {
    _autoRotateTimer?.cancel();
    if (widget.dialogues.length <= 1) return;
    _autoRotateTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || _isTransitioning) return;
      final next = (_localIndex + 1) % widget.dialogues.length;
      _animateTo(next);
    });
  }

  Future<void> _animateTo(int index) async {
    if (_isTransitioning || !mounted) return;
    _isTransitioning = true;

    await _fadeController.reverse();
    _slideController.reset();

    if (mounted) {
      setState(() => _localIndex = index);
      widget.onIndexChanged(index);
    }

    _fadeController.forward();
    _slideController.forward();
    _isTransitioning = false;
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dialogues.isEmpty) return const SizedBox.shrink();
    final dialogue = widget.dialogues[_localIndex.clamp(0, widget.dialogues.length - 1)];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card ──────────────────────────────────────────────
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (widget.dialogues.length <= 1) return;
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -200) {
                  // Swipe left → next
                  final next = (_localIndex + 1) % widget.dialogues.length;
                  _autoRotateTimer?.cancel();
                  _animateTo(next).then((_) => _startAutoRotation());
                } else if (details.primaryVelocity! > 200) {
                  // Swipe right → previous
                  final prev = (_localIndex - 1 + widget.dialogues.length) % widget.dialogues.length;
                  _autoRotateTimer?.cancel();
                  _animateTo(prev).then((_) => _startAutoRotation());
                }
              }
            },
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildCard(context, dialogue),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Pagination Dots + Genre Tag ────────────────────────
          _buildFooter(dialogue),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, MovieDialogue dialogue) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        border: Border.all(color: const Color(0xFF111111), width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4)),
        ],
      ),
      child: Stack(
        children: [
          // ── Movie Poster (right, desaturated bleed) ────────────
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.55,
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.black],
                    stops: [0.0, 0.55],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                  child: Image.network(
                    dialogue.posterUrl
                        .replaceAll('image.tmdb.org', 'images.tmdb.org')
                        .replaceAll('/original/', '/w500/'),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (c, e, s) => Container(color: Colors.transparent),
                  ),
                ),
              ),
            ),
          ),

          // ── Red accent bar (right edge) ───────────────────────
          Positioned(
            top: 0, right: 0, bottom: 0,
            child: Container(width: 24, color: const Color(0xFFD32F2F)),
          ),

          // ── Vertical movie title ──────────────────────────────
          Positioned(
            right: 2, top: 0, bottom: 0,
            child: Center(
              child: RotatedBox(
                quarterTurns: 1,
                child: Text(
                  dialogue.movieTitle,
                  style: const TextStyle(
                    color: Color(0xFFF4F4EC),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    fontFamily: 'Impact',
                  ),
                ),
              ),
            ),
          ),

          // ── Quote + character ─────────────────────────────────
          Positioned(
            top: 16,
            left: 16,
            right: MediaQuery.of(context).size.width * 0.44,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "\u201C",
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        height: 0.8,
                        fontFamily: 'serif',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(width: 16, height: 1.2, color: const Color(0xFFD32F2F)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  dialogue.movieTitle,
                                  style: const TextStyle(
                                    color: Color(0xFFD32F2F),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Builder(
                      builder: (context) {
                        final q = dialogue.quote.toUpperCase();
                        double fs = 18.0;
                        if (q.length > 120) fs = 11.0;
                        else if (q.length > 80) fs = 13.0;
                        else if (q.length > 50) fs = 15.0;
                        else if (q.length > 30) fs = 16.5;
                        return Text(
                          q,
                          style: TextStyle(
                            color: const Color(0xFF111111),
                            fontSize: fs,
                            fontWeight: FontWeight.w900,
                            height: 0.95,
                            fontFamily: 'Impact',
                            letterSpacing: -0.3,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dialogue.character.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Forge / Edit button ───────────────────────────────
          Positioned(
            top: 12,
            right: 36,
            child: GestureDetector(
              onTap: widget.onForgeTap,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  border: Border.all(color: const Color(0xFF111111), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFD32F2F), offset: Offset(2, 2)),
                  ],
                ),
                child: const Icon(Icons.edit_note_rounded, color: Color(0xFFF4F4EC), size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(MovieDialogue dialogue) {
    final total = widget.dialogues.length;
    return Row(
      children: [
        // Genre tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            border: Border.all(color: const Color(0xFFD32F2F), width: 1.0),
          ),
          child: Text(
            dialogue.genre,
            style: const TextStyle(
              color: Color(0xFFD32F2F),
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontFamily: 'Impact',
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Pagination dots
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(total.clamp(0, 30), (i) {
                final isActive = i == _localIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 4),
                  width: isActive ? 16 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFD32F2F) : const Color(0xFF111111).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                );
              }),
            ),
          ),
        ),
        // Index label
        Text(
          '${_localIndex + 1}/$total',
          style: const TextStyle(
            color: Color(0xFF888882),
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/movie_model.dart';
import '../services/movie_service.dart';
import '../movie_details_screen.dart';
import 'dart:math';

class TrendingHeroSlideshow extends StatefulWidget {
  const TrendingHeroSlideshow({super.key});

  @override
  State<TrendingHeroSlideshow> createState() => _TrendingHeroSlideshowState();
}

class _TrendingHeroSlideshowState extends State<TrendingHeroSlideshow> {
  final PageController _pageController = PageController(viewportFraction: 1.0);
  final MovieService _movieService = MovieService();
  
  List<MovieModel> _slides = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  Timer? _autoRotateTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final List<MovieModel> trendingMovies = await _movieService.getTrendingAll();
      final List<MovieModel> rawSlides = trendingMovies.take(10).toList();
      
      // Shuffle to make it random as requested
      rawSlides.shuffle(Random());

      if (mounted) {
        setState(() {
          _slides = rawSlides;
          _isLoading = false;
        });
        _startAutoRotation();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint("Error fetching trending slideshow data: $e");
    }
  }

  void _startAutoRotation() {
    _autoRotateTimer?.cancel();
    if (_slides.length <= 1) return;
    _autoRotateTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      final next = (_currentIndex + 1) % _slides.length;
      _animateTo(next);
    });
  }

  void _animateTo(int index) {
    if (!mounted || !_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 800),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4EC),
            border: Border.all(color: const Color(0xFF111111), width: 2.5),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF111111)),
          ),
        ),
      );
    }

    if (_slides.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "TRENDING STUFF",
                style: TextStyle(
                  color: Color(0xFF575757),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Divider(color: Color(0xFFD4D1C8), thickness: 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Card ──────────────────────────────────────────────
          SizedBox(
            height: 200,
            child: GestureDetector(
              onPanDown: (_) => _autoRotateTimer?.cancel(),
              onPanEnd: (_) => _startAutoRotation(),
              onPanCancel: () => _startAutoRotation(),
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) {
                  setState(() => _currentIndex = idx);
                },
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double pageOffset = 0;
                      if (_pageController.position.haveDimensions) {
                        pageOffset = _pageController.page! - index;
                      } else {
                        pageOffset = (_currentIndex - index).toDouble();
                      }
                      return _buildMovieSlide(context, _slides[index], index, pageOffset);
                    },
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Pagination Dots ────────────────────────
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildMovieSlide(BuildContext context, MovieModel movie, int index, double pageOffset) {
    final hasBackdrop = movie.backdropPath != null && movie.backdropPath!.isNotEmpty;
    final imageUrl = hasBackdrop ? movie.backdropPath! : movie.posterPath;
    final bool isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: movie)));
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8), // subtle gap if swiping peeks
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border.all(color: const Color(0xFF111111), width: 2.5),
          boxShadow: const [
            BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4)),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image with Parallax & Ken Burns
            ClipRect(
              child: AnimatedScale(
                scale: isActive ? 1.15 : 1.0,
                duration: const Duration(seconds: 8),
                curve: Curves.linear,
                child: FractionalTranslation(
                  translation: Offset(pageOffset * 0.25, 0),
                  child: Image.network(
                    imageUrl,
                    fit: hasBackdrop ? BoxFit.cover : BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    errorBuilder: (c, e, s) => Container(color: const Color(0xFF333333)),
                  ),
                ),
              ),
            ),
            
            // Left red bar
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(width: 4, color: const Color(0xFFD32F2F)),
            ),

            // Bottom glassmorphism strip
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          "TRENDING NOW",
                          style: TextStyle(
                            color: const Color(0xFFD32F2F),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            fontFamily: 'Impact',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          movie.isTvShow ? "📺 SHOW" : "🎬 MOVIE",
                          style: const TextStyle(
                            color: Color(0xFFF4F4EC),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      movie.title.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFF4F4EC),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Impact',
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (movie.genreNames.isNotEmpty && movie.genreNames != 'Unknown') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              movie.genreNames.split(',').first.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFFF4F4EC),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text("•", style: TextStyle(color: Color(0xFF888882), fontSize: 10)),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          movie.voteAverage.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFFF4F4EC),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text("•", style: TextStyle(color: Color(0xFF888882), fontSize: 10)),
                        const SizedBox(width: 8),
                        Text(
                          movie.releaseDate.split('-').first,
                          style: const TextStyle(
                            color: Color(0xFFF4F4EC),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final total = _slides.length;
    return Row(
      children: [
        // Pagination dots
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(total.clamp(0, 30), (i) {
                final isActive = i == _currentIndex;
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
      ],
    );
  }
}

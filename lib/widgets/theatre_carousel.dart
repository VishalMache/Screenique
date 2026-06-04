import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie_model.dart';
import '../services/movie_service.dart';
import '../movie_details_screen.dart';

class TheatreCarousel extends StatefulWidget {
  const TheatreCarousel({super.key});

  @override
  State<TheatreCarousel> createState() => _TheatreCarouselState();
}

class _TheatreCarouselState extends State<TheatreCarousel> {
  final MovieService _movieService = MovieService();
  bool _isLoading = true;
  bool _isNowPlaying = true; // true = Now Playing, false = Coming Soon
  List<MovieModel> _nowPlaying = [];
  List<MovieModel> _upcoming = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _movieService.getNowPlayingMovies(),
        _movieService.getUpcomingMovies(),
      ]);
      
      if (mounted) {
        setState(() {
          _nowPlaying = results[0];
          _upcoming = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleTap(MovieModel movie) async {
    // If it's a Now Playing film, record the tap for the follow-up prompt
    if (_isNowPlaying) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theatre_last_tapped_title', movie.title);
      await prefs.setString('theatre_last_tapped_date', DateTime.now().toIso8601String());
    }

    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _CarouselPlaceholder();
    }
    
    if (_nowPlaying.isEmpty && _upcoming.isEmpty) {
      return const SizedBox.shrink(); // Hide if completely failed
    }

    final currentList = _isNowPlaying ? _nowPlaying : _upcoming;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Row(
            children: [
              _buildToggle(),
              const Expanded(child: Padding(padding: EdgeInsets.only(left: 12), child: Divider(color: Color(0xFF111111), thickness: 2.5))),
            ],
          ),
        ),
        
        // Carousel
        SizedBox(
          height: 240, // Enough room for poster + title + date
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: currentList.length,
            itemBuilder: (context, index) {
              final movie = currentList[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => _handleTap(movie),
                  child: SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poster Card
                        Container(
                          width: 120,
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4EC),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: const Color(0xFF111111), width: 1.5),
                            boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(1),
                                child: Image.network(
                                  movie.posterPath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Color(0xFF888882))),
                                ),
                              ),
                              // Ink Stamp Badge
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _isNowPlaying ? const Color(0xFFD32F2F) : const Color(0xFF111111),
                                    border: Border.all(color: const Color(0xFFF4F4EC), width: 1),
                                  ),
                                  child: Text(
                                    _isNowPlaying ? "IN THEATRES" : "RELEASING",
                                    style: const TextStyle(
                                      color: Color(0xFFF4F4EC),
                                      fontSize: 6,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Title
                        Text(
                          movie.title.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            fontFamily: 'Impact',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Release Date (for Coming Soon)
                        if (!_isNowPlaying && movie.releaseDate.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              movie.releaseDate,
                              style: const TextStyle(
                                color: Color(0xFF454545),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToggle() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111111).withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF111111).withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (!_isNowPlaying) {
                    HapticFeedback.selectionClick();
                    setState(() => _isNowPlaying = true);
                  }
                },
                child: Text(
                  "NOW PLAYING",
                  style: TextStyle(
                    color: _isNowPlaying ? const Color(0xFF111111) : const Color(0xFF888882),
                    fontWeight: _isNowPlaying ? FontWeight.w900 : FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text("/", style: TextStyle(color: Color(0xFF888882), fontSize: 10, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (_isNowPlaying) {
                    HapticFeedback.selectionClick();
                    setState(() => _isNowPlaying = false);
                  }
                },
                child: Text(
                  "COMING SOON",
                  style: TextStyle(
                    color: !_isNowPlaying ? const Color(0xFF111111) : const Color(0xFF888882),
                    fontWeight: !_isNowPlaying ? FontWeight.w900 : FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarouselPlaceholder extends StatelessWidget {
  const _CarouselPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Row(
            children: [
              Text("NOW PLAYING", style: TextStyle(color: const Color(0xFF111111).withOpacity(0.5), fontSize: 14, letterSpacing: 3, fontWeight: FontWeight.w900, fontFamily: 'Impact')),
              const Expanded(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Divider(color: Color(0xFFE0E0D8), thickness: 2.5))),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0D8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(width: 100, height: 10, color: const Color(0xFFE0E0D8)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

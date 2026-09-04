
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../models/movie_model.dart';
import '../../services/movie_service.dart';
import 'person_details_screen.dart';
import '../../services/watchlist_service.dart';

class MovieDetailsScreen extends StatefulWidget {
  final MovieModel movie;
  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  final WatchlistService _watchlistService = WatchlistService();
  final MovieService _movieService = MovieService();
  
  late MovieModel _movie;
  List<Map<String, dynamic>> _cast = [];
  
  Map<String, dynamic>? _fullDetails;
  String _directorName = "UNKNOWN"; 
  int? _directorId;
  String? _trailerUrl;
  YoutubePlayerController? _inlineTrailerController;
  List<Map<String, dynamic>> _watchProviders = [];
  bool _isSpotlight = false;
  bool _isWatched = false;
  bool _isInWatchlist = false; 
  bool _isLoading = true;
  bool _isInTheatres = false;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    _isInTheatres = MovieService.nowPlayingIds.contains(_movie.id);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _movieService.getMediaDetails(_movie.id, isTv: _movie.isTvShow),
        _movieService.getMediaCast(_movie.id, isTv: _movie.isTvShow),
        _movieService.getTrailerUrl(_movie.id, isTv: _movie.isTvShow),
        _movieService.getWatchProviders(_movie.id, isTv: _movie.isTvShow),
        _checkInitialStatusFuture(),
      ]);

      final details = results[0] as Map<String, dynamic>?;
      final castData = results[1] as List<Map<String, dynamic>>;
      final trailer = results[2] as String?;
      final providers = results[3] as List<Map<String, dynamic>>;

      String foundDirector = "UNKNOWN";
      int? foundDirectorId;
      if (details != null && details['credits'] != null) {
        final crew = details['credits']['crew'] as List;
        final director = crew.firstWhere(
          (member) => member['job'] == 'Director', 
          orElse: () => null
        );
        if (director != null) {
          foundDirector = director['name'];
          foundDirectorId = director['id'];
        }
      }

      if (context.mounted) {
        if (trailer != null) {
          final videoId = Uri.parse(trailer).queryParameters['v'] ?? '';
          if (videoId.isNotEmpty) {
            _inlineTrailerController = YoutubePlayerController.fromVideoId(
              videoId: videoId,
              autoPlay: true,
              params: const YoutubePlayerParams(
                showControls: false,
                mute: true,
                showFullscreenButton: false,
                loop: true,
                pointerEvents: PointerEvents.none,
              ),
            );
          }
        }

        setState(() {
          _fullDetails = details;
          _directorName = foundDirector;
          _directorId = foundDirectorId;
          _cast = castData;
          _trailerUrl = trailer;
          _watchProviders = providers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkInitialStatusFuture() async {
    final user = _watchlistService.getCurrentUser();
    if (user == null) return;
    
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('users').doc(user.uid).collection('top_five').doc(_movie.id.toString()).get(),
      FirebaseFirestore.instance.collection('users').doc(user.uid).collection('movies').doc(_movie.id.toString()).get(),
    ]);

    if (mounted) {
      _isSpotlight = results[0].exists;
      if (results[1].exists) {
        final data = results[1].data() as Map<String, dynamic>;
        _isWatched = data['status'] == 'watched';
        _isInWatchlist = data['status'] == 'watchlist';
        
        if (data['personalNote'] != null && data['personalNote'].toString().trim().isNotEmpty) {
          _movie = MovieModel(
            id: _movie.id,
            title: _movie.title,
            overview: _movie.overview,
            posterPath: _movie.posterPath,
            voteAverage: _movie.voteAverage,
            releaseDate: _movie.releaseDate,
            genreIds: _movie.genreIds,
            isTvShow: _movie.isTvShow,
            personalNote: data['personalNote'],
          );
        }
      }
    }
  }

  void _showBroadcastDialog(Color accent) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF4F4EC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: Color(0xFF111111), width: 2),
        ),
        title: const Text("COMMUNITY BROADCAST", 
          style: TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "EXPLAIN THE CINEMATIC MERIT OF THIS WORK TO THE GLOBAL ARCHIVE.",
              style: TextStyle(color: Color(0xFF454545), fontSize: 11, letterSpacing: 1),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: reasonController,
              maxLength: 1200, 
              maxLines: 5,
              minLines: 1,
              autofocus: true,
              style: const TextStyle(color: Color(0xFF111111), fontSize: 15, height: 1.5),
              decoration: const InputDecoration(
                hintText: "WHY SHOULD OTHERS WATCH THIS?",
                hintStyle: TextStyle(color: Color(0xFF454545), fontSize: 12),
                counterStyle: TextStyle(color: Color(0xFF454545), fontSize: 11),
                filled: true,
                fillColor: Color(0xFFF4F4EC),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF111111), width: 2)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Color(0xFF111111), fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111111)),
            onPressed: () async {
              if (reasonController.text.trim().isNotEmpty) {
                await _watchlistService.broadcastMovie(_movie, reasonController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("TRANSMISSION SUCCESSFUL", style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)), 
                      backgroundColor: Color(0xFF111111),
                      behavior: SnackBarBehavior.floating
                    ),
                  );
                }
              }
            },
            child: const Text("SEND", style: TextStyle(color: Color(0xFFF4F4EC), fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showLogWatchedDialog(Color accent) {
    final TextEditingController reviewController = TextEditingController(text: _movie.personalNote);
    double rating = 3.0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          scrollable: true,
          backgroundColor: const Color(0xFFF4F4EC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: const BorderSide(color: Color(0xFF111111), width: 2),
          ),
          title: Row(
            children: [
              Icon(Icons.star_rounded, color: accent, size: 26),
              const SizedBox(width: 10),
              const Text(
                "RATE & REVIEW",
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Share your rating and personal review.",
                style: TextStyle(color: Color(0xFF454545), fontSize: 12, letterSpacing: 1),
              ),
              const SizedBox(height: 20),
              
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("YOUR RATING", style: TextStyle(color: Color(0xFF111111), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () {
                    setST(() {
                      final fullValue = i + 1.0;
                      final halfValue = i + 0.5;
                      if (rating == fullValue) {
                        rating = halfValue;
                      } else if (rating == halfValue) {
                        rating = fullValue;
                      } else {
                        rating = fullValue;
                      }
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Icon(
                      i < rating.floor()
                          ? Icons.star
                          : (i == rating.floor() && (rating - rating.floor()) >= 0.5
                              ? Icons.star_half
                              : Icons.star_border),
                      color: i < rating ? const Color(0xFF111111) : const Color(0xFF454545),
                      size: 32,
                    ),
                  ),
                )),
              ),
              Center(
                child: Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("YOUR REVIEW", style: TextStyle(color: Color(0xFF111111), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reviewController,
                maxLines: 4,
                minLines: 2,
                style: const TextStyle(color: Color(0xFF111111), fontSize: 15, height: 1.5),
                decoration: const InputDecoration(
                  hintText: "WRITE YOUR REVIEW (OPTIONAL)...",
                  hintStyle: TextStyle(color: Color(0xFF454545), fontSize: 12),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF111111), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2),
                  ),
                  filled: true,
                  fillColor: Color(0xFFF4F4EC),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Color(0xFF111111), fontSize: 13, letterSpacing: 1)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111111)),
              onPressed: () async {
                final reviewText = reviewController.text.trim();
                
                final updatedMovie = MovieModel(
                  id: _movie.id,
                  title: _movie.title,
                  overview: _movie.overview,
                  posterPath: _movie.posterPath,
                  voteAverage: _movie.voteAverage,
                  releaseDate: _movie.releaseDate,
                  genreIds: _movie.genreIds,
                  isTvShow: _movie.isTvShow,
                  personalNote: reviewText,
                );
                
                await _watchlistService.toggleMovieStatus(updatedMovie, 'watched');
                await _watchlistService.updateMovieRating(_movie.id, rating);
                
                if (context.mounted) {
                  setState(() {
                    _movie = updatedMovie;
                    _isWatched = true;
                    _isInWatchlist = false;
                  });
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("WATCHED ADDED SUCCESSFULLY", style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      backgroundColor: Color(0xFF111111),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text("SAVE", style: TextStyle(color: Color(0xFFF4F4EC), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color noirCrimson = Color(0xFFD32F2F); // Using standard red for accent as requested by design
    final Color accentColor = noirCrimson;
    const Color bgColor = Color(0xFFF4F4EC);
    const Color textColor = Color(0xFF111111);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 40,
                width: 40,
                child: CircularProgressIndicator(color: noirCrimson, strokeWidth: 4),
              ),
              SizedBox(height: 24),
              Text(
                "ACCESSING CINEMATIC ARCHIVES...",
                style: TextStyle(color: textColor, fontFamily: 'Impact', fontSize: 14, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8, bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: textColor, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: textColor, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: textColor, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.share_outlined, color: textColor, size: 20),
                onPressed: () {
                  // Assuming share logic
                },
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPoster(),
                const SizedBox(height: 24),
                _buildTitleSection(accentColor),
                const SizedBox(height: 12),
                _buildMetaData(accentColor),
                const SizedBox(height: 24),
                
                if (_fullDetails?['tagline'] != null && _fullDetails!['tagline'].toString().isNotEmpty) ...[
                  _buildTagline(),
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE0E0D8), thickness: 1.5),
                  const SizedBox(height: 24),
                ],
                
                _buildSectionLabel("SYNOPSIS", accentColor),
                const SizedBox(height: 12),
                Text(
                  _movie.overview,
                  style: const TextStyle(color: textColor, fontSize: 14, height: 1.6, fontWeight: FontWeight.w500),
                ),
                
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE0E0D8), thickness: 1.5),
                const SizedBox(height: 24),
                
                _buildSectionLabel("TECHNICAL DETAILS", accentColor),
                const SizedBox(height: 16),
                _buildTechnicalManifest(accentColor),

                if (_fullDetails?['production_companies'] != null && (_fullDetails!['production_companies'] as List).isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE0E0D8), thickness: 1.5),
                  const SizedBox(height: 24),
                  _buildSectionLabel("PRODUCTION STUDIOS", accentColor),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (_fullDetails!['production_companies'] as List)
                              .map((company) => company['name'])
                              .join(" • "),
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ],

                if (_watchProviders.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE0E0D8), thickness: 1.5),
                  const SizedBox(height: 24),
                  _buildSectionLabel("WHERE TO WATCH", accentColor),
                  const SizedBox(height: 16),
                  _buildWatchProvidersSection(),
                ],
                
                if (_cast.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE0E0D8), thickness: 1.5),
                  const SizedBox(height: 24),
                  _buildSectionLabel("CAST MEMBERS", accentColor),
                  const SizedBox(height: 16),
                  _buildCastSection(accentColor),
                ],
                
                const SizedBox(height: 32),
                _buildActionButtons(accentColor),
                SizedBox(height: _isInTheatres ? 140 : 60),
              ],
            ),
          ),
          if (_isInTheatres)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBookingBar(),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inlineTrailerController?.close();
    super.dispose();
  }

  Widget _buildPoster() {
    if (_inlineTrailerController != null) {
      return Center(
        child: Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(77),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: YoutubePlayer(
                  controller: _inlineTrailerController!,
                  backgroundColor: Colors.black,
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    if (_trailerUrl != null) {
                      showDialog(
                        context: context,
                        builder: (_) => TrailerDialog(videoUrl: _trailerUrl!),
                      );
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Hero(
        tag: 'movie-poster-${_movie.id}',
        child: Container(
          width: 320,
          height: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(77),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  _movie.posterPath,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              if (_fullDetails?['genres'] != null && (_fullDetails!['genres'] as List).isNotEmpty)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (_fullDetails!['genres'] as List).first['name'].toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            _movie.title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
        ),
        GestureDetector(
          onTap: () async {
            if (_isSpotlight) { 
              await _watchlistService.unpinFromTopFive(_movie.id); 
              setState(() => _isSpotlight = false); 
            } else { 
              await _watchlistService.pinToTopFive(_movie); 
              setState(() => _isSpotlight = true); 
            }
          },
          child: Icon(
            _isSpotlight ? Icons.stars : Icons.stars_outlined, 
            color: accent, 
            size: 32
          ),
        ),
      ],
    );
  }

  Widget _buildMetaData(Color accent) {
    final firstGenre = _fullDetails?['genres'] != null && (_fullDetails!['genres'] as List).isNotEmpty 
        ? (_fullDetails!['genres'] as List).first['name'].toString().toUpperCase()
        : (_movie.isTvShow ? "SERIES" : "FILM");
        
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: accent, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            firstGenre,
            style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _movie.releaseDate.split('-')[0], 
          style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 12),
        const Text("•", style: TextStyle(color: Colors.grey)),
        const SizedBox(width: 12),
        const Icon(Icons.star, color: Color(0xFFFFC107), size: 16),
        const SizedBox(width: 4),
        Text(
          "${_movie.voteAverage}/10",
          style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }



  Widget _buildTagline() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("“", style: TextStyle(color: Color(0xFFD32F2F), fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'serif', height: 1.0)),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _fullDetails!['tagline'].toString().toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 16,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w800,
                fontFamily: 'serif',
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, Color accent) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: accent),
        const SizedBox(width: 10),
        Text(
          label, 
          style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
      ],
    );
  }

  Widget _buildTechnicalManifest(Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F4), // Slightly lighter than background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0D8), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSpecItem(
                  Icons.chair_alt, 
                  "DIRECTOR", 
                  _directorName,
                  onTap: _directorId != null ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PersonDetailsScreen(
                          personId: _directorId!,
                          name: _directorName,
                        ),
                      ),
                    );
                  } : null,
                ),
              ),
              Expanded(
                child: !_movie.isTvShow
                    ? _buildSpecItem(Icons.access_time, "LENGTH", "${_fullDetails?['runtime'] ?? 'N/A'} min")
                    : _buildSpecItem(Icons.live_tv, "SEASONS", "${_fullDetails?['number_of_seasons'] ?? 'N/A'} S"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE0E0D8), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSpecItem(Icons.calendar_month, "STATUS", _fullDetails?['status'] ?? 'N/A')),
              Expanded(child: _buildSpecItem(Icons.language, "ORIGIN", (_fullDetails?['original_language'] ?? 'N/A').toString().toUpperCase())),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE0E0D8), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: !_movie.isTvShow
                    ? _buildSpecItem(Icons.monetization_on_outlined, "BUDGET", _fullDetails?['budget'] != null && _fullDetails!['budget'] > 0 ? "Set" : "Unset")
                    : _buildSpecItem(Icons.category, "TYPE", _fullDetails?['type'] ?? 'N/A'),
              ),
              Expanded(
                child: !_movie.isTvShow
                    ? _buildSpecItem(Icons.bar_chart, "REVENUE", _fullDetails?['revenue'] != null && _fullDetails!['revenue'] > 0 ? "Set" : "Unset")
                    : _buildSpecItem(Icons.bar_chart, "POPULARITY", "${_fullDetails?['popularity']?.toStringAsFixed(0) ?? 'N/A'}"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String label, String value, {VoidCallback? onTap}) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFD32F2F), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                value, 
                style: TextStyle(
                  color: onTap != null ? const Color(0xFFD32F2F) : const Color(0xFF111111), 
                  fontSize: 14, 
                  fontWeight: FontWeight.w600,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }

  Widget _buildWatchProvidersSection() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _watchProviders.length,
        itemBuilder: (context, index) {
          final provider = _watchProviders[index];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0D8), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (provider['logo_path'] != null)
                  Image.network(
                    'https://image.tmdb.org/t/p/w200${provider['logo_path']}',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  )
                else
                  const Icon(Icons.live_tv, color: Color(0xFF111111), size: 40),
                const SizedBox(height: 8),
                Text(
                  provider['type'].toString().toUpperCase(),
                  style: const TextStyle(color: Color(0xFF111111), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCastSection(Color accent) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _cast.length > 10 ? 10 : _cast.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PersonDetailsScreen(
                      personId: _cast[index]['id'],
                      name: _cast[index]['name'] ?? 'UNKNOWN',
                    ),
                  ),
                );
              },
              child: SizedBox(
                width: 70,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 35, 
                      backgroundColor: const Color(0xFFE0E0D8), 
                      backgroundImage: _cast[index]['profile_path'] != null 
                          ? NetworkImage('https://image.tmdb.org/t/p/w200${_cast[index]['profile_path']}') 
                          : null,
                      child: _cast[index]['profile_path'] == null 
                          ? const Icon(Icons.person, color: Color(0xFF111111), size: 30)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _cast[index]['name'] ?? 'Unknown',
                      style: const TextStyle(color: Color(0xFF111111), fontSize: 11, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (_cast[index]['character'] ?? '').toString().toUpperCase(),
                      style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 9, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(Color accent) {
    return Row(
      children: [
        // ADD TO WATCHLIST
        Expanded(
          flex: 5,
          child: GestureDetector(
            onTap: () {
              if (!_isWatched) {
                _watchlistService.toggleMovieStatus(_movie, 'watchlist');
                setState(() => _isInWatchlist = !_isInWatchlist);
              }
            },
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isInWatchlist ? Icons.check : Icons.add, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _isInWatchlist ? "ON WATCHLIST" : "ADD TO WATCHLIST",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        
        // MARK WATCHED
        Expanded(
          flex: 4,
          child: GestureDetector(
            onTap: () {
              if (!_isWatched) {
                _showLogWatchedDialog(accent);
              }
            },
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: _isWatched ? const Color(0xFFE0E0D8) : Colors.transparent,
                border: Border.all(color: const Color(0xFF111111), width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, color: const Color(0xFF111111), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _isWatched ? "WATCHED" : "MARK WATCHED",
                      style: const TextStyle(color: Color(0xFF111111), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        
        // CINECAST
        GestureDetector(
          onTap: () => _showBroadcastDialog(accent),
          child: Container(
            height: 54,
            width: 58,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF111111), width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.podcasts_rounded, color: Color(0xFF111111), size: 20),
                SizedBox(height: 2),
                Text(
                  "CINECAST",
                  style: TextStyle(color: Color(0xFF111111), fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Color(0xFFD32F2F), width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("NOW PLAYING", style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBookingButton(
                  title: "BOOKMYSHOW",
                  url: 'https://in.bookmyshow.com/search?q=${Uri.encodeComponent(_movie.title)}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBookingButton(
                  title: "DISTRICT",
                  url: 'https://district.in/search?q=${Uri.encodeComponent(_movie.title)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingButton({required String title, required String url}) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F),
          border: Border.all(color: const Color(0xFFF4F4EC), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.confirmation_num, color: Color(0xFFF4F4EC), size: 16),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, fontFamily: 'Impact')),
          ],
        ),
      ),
    );
  }
}

class TrailerDialog extends StatefulWidget {
  final String videoUrl;
  const TrailerDialog({super.key, required this.videoUrl});

  @override
  State<TrailerDialog> createState() => _TrailerDialogState();
}

class _TrailerDialogState extends State<TrailerDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = Uri.parse(widget.videoUrl).queryParameters['v'] ?? '';
    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        mute: false,
        showFullscreenButton: true,
        loop: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border.all(color: const Color(0xFFD32F2F), width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("OFFICIAL TRAILER", style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Color(0xFFF4F4EC), size: 20),
                  ),
                ],
              ),
            ),
            YoutubePlayer(
              controller: _controller,
              backgroundColor: const Color(0xFF111111),
            ),
          ],
        ),
      ),
    );
  }
}
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/movie_model.dart';
import '../../services/movie_service.dart';
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
        _checkInitialStatusFuture(),
      ]);

      final details = results[0] as Map<String, dynamic>?;
      final castData = results[1] as List<Map<String, dynamic>>;

      String foundDirector = "UNKNOWN";
      if (details != null && details['credits'] != null) {
        final crew = details['credits']['crew'] as List;
        final director = crew.firstWhere(
          (member) => member['job'] == 'Director', 
          orElse: () => null
        );
        if (director != null) foundDirector = director['name'];
      }

      if (mounted) {
        setState(() {
          _fullDetails = details;
          _directorName = foundDirector;
          _cast = castData;
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
                if (mounted) {
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
                  onTap: () => setST(() => rating = i + 1.0),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Icon(
                      i < rating ? Icons.star : Icons.star_border,
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
                
                if (mounted) {
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
    const Color noirCrimson = Color(0xFF111111);
    const Color tvBlue = Color(0xFF111111);
    final Color accentColor = _movie.isTvShow ? tvBlue : noirCrimson;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F4EC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                height: 40,
                width: 40,
                child: CircularProgressIndicator(
                  color: Color(0xFFD32F2F),
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "ACCESSING CINEMATIC ARCHIVES...",
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontFamily: 'Impact',
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4EC),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildTitleSection(),
                      const SizedBox(height: 12),
                      _buildMetaData(accentColor),
                      const SizedBox(height: 20),
                      
                      // --- GENRES WRAP ---
                      if (_fullDetails?['genres'] != null) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (_fullDetails!['genres'] as List).map<Widget>((genre) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F4EC),
                                border: Border.all(color: const Color(0xFF111111), width: 1.5),
                              ),
                              child: Text(
                                genre['name'].toString().toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // --- TAGLINE ---
                      if (_fullDetails?['tagline'] != null && _fullDetails!['tagline'].toString().isNotEmpty) ...[
                        Text(
                          '"${_fullDetails!['tagline'].toString().toUpperCase()}"',
                          style: const TextStyle(
                            color: Color(0xFFD32F2F),
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'serif',
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const Divider(color: Color(0xFF111111), thickness: 3),
                      const SizedBox(height: 24),
                      
                      _buildSectionLabel("LOGLINE", accentColor),
                      const SizedBox(height: 12),
                      Text(
                        _movie.overview,
                        style: const TextStyle(color: Color(0xFF111111), fontSize: 15, height: 1.7, fontWeight: FontWeight.w500),
                      ),
                      
                      const SizedBox(height: 32),
                      const Divider(color: Color(0xFF111111), thickness: 2),
                      const SizedBox(height: 32),
                      _buildSectionLabel("TECHNICAL DETAILS", accentColor),
                      const SizedBox(height: 20),
                      _buildTechnicalManifest(accentColor),

                      // --- PRODUCTION COMPANIES ---
                      if (_fullDetails?['production_companies'] != null && (_fullDetails!['production_companies'] as List).isNotEmpty) ...[
                        const SizedBox(height: 32),
                        const Divider(color: Color(0xFF111111), thickness: 2),
                        const SizedBox(height: 32),
                        _buildSectionLabel("PRODUCTION STUDIOS", accentColor),
                        const SizedBox(height: 16),
                        Text(
                          (_fullDetails!['production_companies'] as List)
                              .map((company) => company['name'])
                              .join(" • ")
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF454545),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            height: 1.6,
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 32),
                      const Divider(color: Color(0xFF111111), thickness: 2),
                      const SizedBox(height: 32),
                      _buildCastSection(accentColor),
                      const SizedBox(height: 40),
                      _buildActionButtons(accentColor),
                      SizedBox(height: _isInTheatres ? 160 : 80),
                    ],
                  ),
                ),
              ),
            ],
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

  Widget _buildSectionLabel(String label, Color accent) {
    return Row(
      children: [
        Container(width: 4, height: 12, color: accent),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3)),
      ],
    );
  }

  Widget _buildTechnicalManifest(Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 2.3,
        children: [
          _buildSpecItem("DIRECTOR", _directorName.toUpperCase()),

          if (!_movie.isTvShow)
            _buildSpecItem("LENGTH", "${_fullDetails?['runtime'] ?? 'N/A'} MIN")
          else
            _buildSpecItem("SEASONS", "${_fullDetails?['number_of_seasons'] ?? 'N/A'} S / ${_fullDetails?['number_of_episodes'] ?? 'N/A'} E"),
          
          _buildSpecItem("STATE", (_fullDetails?['status'] ?? 'N/A').toString().toUpperCase()),
          _buildSpecItem("ORIGIN", (_fullDetails?['original_language'] ?? 'N/A').toString().toUpperCase()),
          
          if (!_movie.isTvShow)
            _buildSpecItem("BUDGET", _fullDetails?['budget'] != null && _fullDetails!['budget'] > 0 ? "\$${(_fullDetails!['budget'] / 1000000).toStringAsFixed(1)}M" : "UNSET")
          else
            _buildSpecItem("TYPE", (_fullDetails?['type'] ?? 'Web Series').toString().toUpperCase()),

          if (!_movie.isTvShow)
            _buildSpecItem("REVENUE", _fullDetails?['revenue'] != null && _fullDetails!['revenue'] > 0 ? "\$${(_fullDetails!['revenue'] / 1000000).toStringAsFixed(1)}M" : "UNSET")
          else
            _buildSpecItem("POPULARITY", "${_fullDetails?['popularity']?.toStringAsFixed(0) ?? 'N/A'} SCORE"),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildAppBar() {
    final String? backdropPath = _fullDetails?['backdrop_path'];
    return SliverAppBar(
      expandedHeight: 380, pinned: true, backgroundColor: const Color(0xFFF4F4EC),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC),
          border: Border.all(color: const Color(0xFF111111), width: 1.5),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111111), size: 16),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Atmospheric Backdrop Image
            if (backdropPath != null)
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                    stops: [0.3, 0.95],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: Image.network(
                    'https://image.tmdb.org/t/p/w780$backdropPath',
                    fit: BoxFit.cover,
                    color: Colors.grey,
                    colorBlendMode: BlendMode.saturation,
                  ),
                ),
              ),
            // Floating Poster Card
            Center(
              child: Hero(
                tag: 'movie-poster-${_movie.id}',
                child: Container(
                  width: 180, height: 260,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4EC),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: const Color(0xFF111111), width: 2),
                    boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(5, 5))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.network(_movie.posterPath, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(_movie.title.toUpperCase(), style: const TextStyle(color: Color(0xFF111111), fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0, height: 1.0, fontFamily: 'Impact'))),
        IconButton(
          onPressed: () async {
            if (_isSpotlight) { await _watchlistService.unpinFromTopFive(_movie.id); setState(() => _isSpotlight = false); }
            else { await _watchlistService.pinToTopFive(_movie); setState(() => _isSpotlight = true); }
          },
          icon: Icon(_isSpotlight ? Icons.stars : Icons.stars_outlined, color: _isSpotlight ? const Color(0xFF111111) : const Color(0xFF454545), size: 30),
        ),
      ],
    );
  }

  Widget _buildMetaData(Color accent) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            border: Border.all(color: accent),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _movie.isTvShow ? "SERIES" : "FILM",
            style: TextStyle(color: accent, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ),
        const SizedBox(width: 12),
        Text(_movie.releaseDate.split('-')[0], style: const TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(width: 15),
        const Text("•", style: TextStyle(color: Color(0xFF111111))),
        const SizedBox(width: 15),
        Text("${_movie.voteAverage} SCORE", style: const TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildCastSection(Color accent) {
    if (_cast.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("CAST MEMBERS", accent),
        const SizedBox(height: 20),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _cast.length > 10 ? 10 : _cast.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30, 
                      backgroundColor: const Color(0xFFF4F4EC), 
                      backgroundImage: _cast[index]['profile_path'] != null 
                          ? NetworkImage('https://image.tmdb.org/t/p/w200${_cast[index]['profile_path']}') 
                          : null,
                      child: _cast[index]['profile_path'] == null 
                          ? const Icon(Icons.person, color: Color(0xFF111111))
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(_cast[index]['name'].toString().toUpperCase().split(' ').first, style: const TextStyle(color: Color(0xFF111111), fontSize: 8, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Color accent) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: _isWatched ? const Color(0xFFF4F4EC) : accent,
              border: Border.all(color: const Color(0xFF111111), width: 2),
              boxShadow: _isWatched ? [] : const [BoxShadow(color: Color(0xFF111111), offset: Offset(6, 6))],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                if (!_isWatched) {
                  _showLogWatchedDialog(accent);
                }
              },
              icon: Icon(_isWatched ? Icons.check_circle : Icons.play_circle_fill, size: 20),
              label: Text(
                _isWatched ? "WATCHED" : "MARK WATCHED", 
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 11)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: _isWatched ? const Color(0xFF111111) : const Color(0xFFF4F4EC),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        _buildSmallIconButton(
          icon: _isInWatchlist ? Icons.bookmark_added : Icons.bookmark_outline,
          isActive: _isInWatchlist,
          accent: accent,
          onTap: () {
            if (!_isWatched) {
              _watchlistService.toggleMovieStatus(_movie, 'watchlist');
              setState(() => _isInWatchlist = !_isInWatchlist);
            }
          },
        ),
        const SizedBox(width: 12),

        _buildSmallIconButton(
          icon: Icons.podcasts_rounded,
          isActive: false, 
          accent: accent,
          onTap: () => _showBroadcastDialog(accent),
        ),
      ],
    );
  }

  Widget _buildSmallIconButton({required IconData icon, required bool isActive, required Color accent, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 60, width: 60,
        decoration: BoxDecoration(
          color: isActive ? accent : const Color(0xFFF4F4EC), 
          border: Border.all(color: const Color(0xFF111111), width: 2),
          boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))],
        ),
        child: Icon(icon, color: isActive ? const Color(0xFFF4F4EC) : const Color(0xFF111111)),
      ),
    );
  }
}
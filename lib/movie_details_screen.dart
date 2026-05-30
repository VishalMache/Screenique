import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  // Localized State Copy to prevent detail vanishing during parent rebuilds
  late MovieModel _movie;
  late Future<List<Map<String, dynamic>>> _castFuture;
  
  Map<String, dynamic>? _fullDetails;
  String _directorName = "LOADING..."; 
  bool _isSpotlight = false;
  bool _isWatched = false;
  bool _isInWatchlist = false; 
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    _castFuture = _movieService.getMediaCast(_movie.id, isTv: _movie.isTvShow);
    _fetchExtendedData();
    _checkInitialStatus();
  }

  Future<void> _fetchExtendedData() async {
    try {
      final details = await _movieService.getMediaDetails(
        _movie.id, 
        isTv: _movie.isTvShow
      );

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
          _isLoadingDetails = false;
        });
      }
    } catch (e) { 
      if (mounted) setState(() => _isLoadingDetails = false); 
    }
  }

  Future<void> _checkInitialStatus() async {
    final user = _watchlistService.getCurrentUser();
    if (user == null) return;
    
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('users').doc(user.uid).collection('top_five').doc(_movie.id.toString()).get(),
      FirebaseFirestore.instance.collection('users').doc(user.uid).collection('movies').doc(_movie.id.toString()).get(),
    ]);

    if (mounted) {
      setState(() {
        _isSpotlight = results[0].exists;
        if (results[1].exists) {
          final data = results[1].data() as Map<String, dynamic>;
          _isWatched = data['status'] == 'watched';
          _isInWatchlist = data['status'] == 'watchlist';
          
          // Re-bind personal note/review if it already exists in Firestore
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
      });
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
                hintStyle: const TextStyle(color: Color(0xFF454545), fontSize: 12),
                counterStyle: const TextStyle(color: Color(0xFF454545), fontSize: 11),
                filled: true,
                fillColor: const Color(0xFFF4F4EC),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF111111), width: 2)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2)),
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

  // premium watched logging dialog (review text + rating stars slider)
  void _showLogWatchedDialog(Color accent) {
    final TextEditingController reviewController = TextEditingController(text: _movie.personalNote);
    double rating = 3.0; // Default rating
    
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
              
              // Rating Stars
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
              
              // Review Input
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
                decoration: InputDecoration(
                  hintText: "WRITE YOUR REVIEW (OPTIONAL)...",
                  hintStyle: const TextStyle(color: Color(0xFF454545), fontSize: 12),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF111111), width: 2),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF4F4EC),
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
                      const SizedBox(height: 20),
                      _buildTitleSection(),
                      const SizedBox(height: 12),
                      _buildMetaData(accentColor),
                      const SizedBox(height: 24),
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
                      
                      const SizedBox(height: 32),
                      const Divider(color: Color(0xFF111111), thickness: 2),
                      const SizedBox(height: 32),
                      _buildCastSection(accentColor),
                      const SizedBox(height: 40),
                      _buildActionButtons(accentColor),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
    if (_isLoadingDetails) return LinearProgressIndicator(color: accent, backgroundColor: const Color(0xFFF4F4EC));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 2.5,
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
    return SliverAppBar(
      expandedHeight: 420, pinned: true, backgroundColor: const Color(0xFFF4F4EC),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111111), size: 20), onPressed: () => Navigator.pop(context)),
      flexibleSpace: FlexibleSpaceBar(
        background: Center(
          child: Hero(
            tag: 'movie-poster-${_movie.id}',
            child: Container(
              width: 220, height: 320,
              decoration: BoxDecoration(color: const Color(0xFFF4F4EC), borderRadius: BorderRadius.circular(2), border: Border.all(color: const Color(0xFF111111), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))]),
              child: ClipRRect(borderRadius: BorderRadius.circular(2), child: Image.network(_movie.posterPath, fit: BoxFit.cover)),
            ),
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("CAST MEMBERS", accent),
        const SizedBox(height: 20),
        SizedBox(
          height: 110,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _castFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final cast = snapshot.data!;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: cast.length > 10 ? 10 : cast.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Column(
                      children: [
                        CircleAvatar(radius: 30, backgroundColor: const Color(0xFFF4F4EC), backgroundImage: cast[index]['profile_path'] != null ? NetworkImage('https://image.tmdb.org/t/p/w200${cast[index]['profile_path']}') : null),
                        const SizedBox(height: 8),
                        Text(cast[index]['name'].toString().toUpperCase().split(' ').first, style: const TextStyle(color: Color(0xFF111111), fontSize: 8, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
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
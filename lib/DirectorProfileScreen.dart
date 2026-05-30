import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/movie_model.dart';
import '../../services/movie_service.dart';
import '../../movie_details_screen.dart';

class DirectorProfileScreen extends StatefulWidget {
  final int personId;
  final String name;

  const DirectorProfileScreen({super.key, required this.personId, required this.name});

  @override
  State<DirectorProfileScreen> createState() => _DirectorProfileScreenState();
}

class _DirectorProfileScreenState extends State<DirectorProfileScreen> {
  final MovieService _movieService = MovieService();
  Map<String, dynamic>? _details;
  List<MovieModel> _directedMovies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDirectorData();
  }

  Future<void> _loadDirectorData() async {
    try {
      final details = await _movieService.getPersonDetails(widget.personId);
      final movies = await _movieService.getDirectedMovies(widget.personId);
      if (mounted) {
        setState(() {
          _details = details;
          _directedMovies = movies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color noirCrimson = Color(0xFFD32F2F);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4EC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: noirCrimson))
          : Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBasicInfo(noirCrimson),
                            const SizedBox(height: 40),
                            const Divider(color: Color(0xFF111111), thickness: 2),
                            const SizedBox(height: 30),
                            _buildSectionLabel("ARCHIVAL BIO", noirCrimson),
                            const SizedBox(height: 12),
                            Text(
                              _details?['biography']?.isNotEmpty == true ? _details!['biography'] : "BIO NOT IN ARCHIVE.",
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF111111), fontSize: 13, height: 1.6, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 40),
                            const Divider(color: Color(0xFF111111), thickness: 2),
                            const SizedBox(height: 30),
                            _buildSectionLabel("DIRECTED FILMOGRAPHY", noirCrimson),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    _buildMoviesGrid(),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111111), size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildBasicInfo(Color accent) {
    return Row(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4EC),
            border: Border.all(color: const Color(0xFF111111), width: 2),
            boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))],
            image: _details?['profile_path'] != null ? DecorationImage(
              image: NetworkImage('https://image.tmdb.org/t/p/w400${_details?['profile_path']}'),
              fit: BoxFit.cover,
            ) : null,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.name.toUpperCase(), 
                style: const TextStyle(color: Color(0xFF111111), fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0, height: 1.0, fontFamily: 'Impact')),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: const Color(0xFFD32F2F),
                child: Text(_details?['place_of_birth']?.toString().toUpperCase() ?? 'UNKNOWN ORIGIN', 
                  style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, Color accent) {
    return Row(
      children: [
        Container(width: 4, height: 12, color: accent),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3)),
      ],
    );
  }

  Widget _buildMoviesGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final movie = _directedMovies[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie))),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4EC),
                  border: Border.all(color: const Color(0xFF111111), width: 2),
                  boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))],
                ),
                child: Image.network(movie.posterPath, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: const Color(0xFF111111))),
              ),
            );
          },
          childCount: _directedMovies.length,
        ),
      ),
    );
  }
}
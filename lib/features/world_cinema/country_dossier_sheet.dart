import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/world_cinema_service.dart';
import '../../models/movie_model.dart';
import 'country_mapper.dart';
import '../movie_lists/watchlist_tab.dart'; // To potentially extract or recreate poster card
import '../../movie_details_screen.dart';
import '../../directorprofilescreen.dart';
import '../../data/curated_directors.dart';

class CountryDossierSheet extends StatefulWidget {
  final String isoCode;
  const CountryDossierSheet({super.key, required this.isoCode});

  @override
  State<CountryDossierSheet> createState() => _CountryDossierSheetState();
}

class _CountryDossierSheetState extends State<CountryDossierSheet> {
  final WorldCinemaService _service = WorldCinemaService();
  final EditorialService _editorialService = EditorialService();
  
  String _editorial = '';
  bool _isLoadingEditorial = true;
  
  List<MovieModel> _topFilms = [];
  List<MovieModel> _topSeries = [];
  List<Map<String, dynamic>> _directors = [];
  int _watchedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _backfillOriginCountryIfNeeded(); // Lazy backfill
  }
  
  Future<void> _loadData() async {
    final name = CountryMapper.getName(widget.isoCode);
    
    // Fire all fetchers in parallel
    Future.wait([
      _service.getTopFilmsByCountry(widget.isoCode),
      _service.getTopTvByCountry(widget.isoCode),
      _service.getWatchedCountForCountry(widget.isoCode),
    ]).then((results) {
      if (!mounted) return;
      setState(() {
        _topFilms = results[0] as List<MovieModel>;
        _topSeries = results[1] as List<MovieModel>;
        _watchedCount = results[2] as int;
      });
    });

    // Load Directors (Curated fallback first)
    if (curatedDirectors.containsKey(widget.isoCode)) {
      if (mounted) setState(() => _directors = curatedDirectors[widget.isoCode]!);
    } else {
      _service.getIconicDirectors(widget.isoCode).then((dirs) {
        if (mounted) setState(() => _directors = dirs);
      });
    }

    // Load Editorial
    try {
      final text = await _editorialService.getOrGenerateEditorial(widget.isoCode, name);
      if (mounted) {
        setState(() {
          _editorial = text;
          _isLoadingEditorial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _editorial = "The cinematic landscape of $name awaits exploration. Its stories are deeply rooted in its culture, waiting to be discovered by the intrepid cinephile.";
          _isLoadingEditorial = false;
        });
      }
    }
  }

  // Lazy backfill: If user has movies from this country but they don't have originCountry tagged, 
  // we would theoretically scan their untagged movies. Since it's heavy to scan ALL untagged,
  // we can do a lightweight pass or just rely on new additions. 
  // For this phase, we'll keep it simple: the prompt mentioned it's a future optimization.
  Future<void> _backfillOriginCountryIfNeeded() async {
    // Implementation placeholder for Option A backfill
  }

  @override
  Widget build(BuildContext context) {
    final name = CountryMapper.getName(widget.isoCode);
    final flag = CountryMapper.getFlagEmoji(widget.isoCode);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF4F4EC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
            border: Border(top: BorderSide(color: Color(0xFF111111), width: 2.0)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  height: 4,
                  width: 40,
                  color: const Color(0xFF111111),
                ),
              ),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 60),
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(flag, style: const TextStyle(fontSize: 40)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF111111),
                                fontFamily: 'Impact',
                                fontSize: 34,
                                letterSpacing: 1.0,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Divider(color: Color(0xFF111111), height: 1, thickness: 2.0),
                    ),
                    
                    // Editorial Section (Note on Paper Style)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFFDF5), // Light paper cream
                              boxShadow: [
                                BoxShadow(color: Color(0x33111111), offset: Offset(2, 4), blurRadius: 4),
                              ],
                              border: Border(
                                left: BorderSide(color: Color(0xFFD32F2F), width: 3), // Subtle red accent like notebook margins
                                top: BorderSide(color: Color(0x1A111111), width: 1),
                                right: BorderSide(color: Color(0x1A111111), width: 1),
                                bottom: BorderSide(color: Color(0x1A111111), width: 1),
                              ),
                            ),
                            child: _isLoadingEditorial 
                                ? _buildEditorialSkeleton()
                                : TweenAnimationBuilder<int>(
                                    tween: IntTween(begin: 0, end: _editorial.length),
                                    duration: Duration(milliseconds: _editorial.length * 25), // 25ms per char
                                    builder: (context, value, child) {
                                      return Text(
                                        _editorial.substring(0, value),
                                        style: const TextStyle(
                                          color: Color(0xFF111111),
                                          fontSize: 15,
                                          height: 1.6,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'serif',
                                          fontStyle: FontStyle.italic,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          // Simulated tape at the top center
                          Positioned(
                            top: -10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Transform.rotate(
                                angle: -0.05,
                                child: Container(
                                  width: 60,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Color(0xCCE8E5D8), // Translucent masking tape color
                                    boxShadow: [BoxShadow(color: Color(0x1A111111), offset: Offset(0, 1), blurRadius: 1)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Top Films
                    if (_topFilms.isNotEmpty) ...[
                      _buildSectionHeader("DEFINING FILMS"),
                      _buildMediaRow(_topFilms),
                      const SizedBox(height: 24),
                    ],
                    
                    // Top Series
                    if (_topSeries.isNotEmpty) ...[
                      _buildSectionHeader("ICONIC TELEVISION"),
                      _buildMediaRow(_topSeries),
                      const SizedBox(height: 24),
                    ],
                    
                    // Directors
                    if (_directors.isNotEmpty) ...[
                      _buildSectionHeader("VISIONARY DIRECTORS"),
                      _buildPersonRow(_directors),
                      const SizedBox(height: 24),
                    ],
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(color: Color(0xFF111111), height: 1, thickness: 1.5),
                    ),
                    
                    // Archive Stat
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(child: _buildArchiveStat()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditorialSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 12, width: double.infinity, color: const Color(0xFF111111).withOpacity(0.1)),
        const SizedBox(height: 8),
        Container(height: 12, width: double.infinity, color: const Color(0xFF111111).withOpacity(0.1)),
        const SizedBox(height: 8),
        Container(height: 12, width: 200, color: const Color(0xFF111111).withOpacity(0.1)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontFamily: 'Impact',
          fontSize: 18,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildMediaRow(List<MovieModel> movies) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: movie))),
            child: Container(
              width: 120,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF111111), width: 1.5),
                        boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))],
                      ),
                      child: Image.network(
                        movie.posterPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF111111), child: const Center(child: Icon(Icons.broken_image, color: Color(0xFFF4F4EC)))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      fontFamily: 'Impact',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPersonRow(List<Map<String, dynamic>> persons) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: persons.length,
        itemBuilder: (context, index) {
          final person = persons[index];
          final tmdbId = person['tmdbId'] ?? person['id'];
          final name = person['name'] ?? 'Unknown';
          final knownFor = person['knownFor'] ?? 'Legendary Director';
          final profilePath = person['profilePath'] ?? person['profile_path'];
          final imageUrl = profilePath != null ? 'https://images.tmdb.org/t/p/w200$profilePath' : '';

          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DirectorProfileScreen(
                name: name,
                personId: tmdbId,
              )));
            },
            child: Container(
              width: 90,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF111111), width: 1.5),
                      boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))],
                      image: imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
                    ),
                    child: imageUrl.isEmpty ? const Icon(Icons.person, color: Color(0xFF111111)) : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF111111), fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    knownFor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: const Color(0xFF111111).withOpacity(0.6), fontSize: 8, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArchiveStat() {
    final text = _watchedCount > 0 
        ? "YOU'VE WATCHED $_watchedCount FILMS FROM ${CountryMapper.getName(widget.isoCode).toUpperCase()}"
        : "UNCHARTED TERRITORY";
        
    return Transform.rotate(
      angle: -0.05,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F),
          border: Border.all(color: const Color(0xFF111111), width: 2),
          boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF4F4EC),
            fontFamily: 'Impact',
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

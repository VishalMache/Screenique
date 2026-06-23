import 'package:flutter/material.dart';
import 'models/movie_model.dart';
import 'services/movie_service.dart';
import 'movie_details_screen.dart';

class PersonDetailsScreen extends StatefulWidget {
  final int personId;
  final String name;

  const PersonDetailsScreen({
    super.key,
    required this.personId,
    required this.name,
  });

  @override
  State<PersonDetailsScreen> createState() => _PersonDetailsScreenState();
}

class _PersonDetailsScreenState extends State<PersonDetailsScreen> {
  final MovieService _movieService = MovieService();
  bool _isLoading = true;
  Map<String, dynamic>? _personDetails;
  List<MovieModel> _credits = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _movieService.getPersonDetails(widget.personId),
        _movieService.getPersonCombinedCredits(widget.personId),
      ]);

      if (mounted) {
        setState(() {
          _personDetails = results[0] as Map<String, dynamic>?;
          _credits = results[1] as List<MovieModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(width: 4, height: 12, color: const Color(0xFFD32F2F)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F4EC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                height: 40,
                width: 40,
                child: CircularProgressIndicator(
                  color: Color(0xFFD32F2F),
                  strokeWidth: 4,
                ),
              ),
              SizedBox(height: 24),
              Text(
                "RETRIEVING DOSSIER...",
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

    final String? profilePath = _personDetails?['profile_path'];
    final String biography = _personDetails?['biography'] ?? '';
    final String birthday = _personDetails?['birthday'] ?? 'UNKNOWN';
    final String placeOfBirth = _personDetails?['place_of_birth'] ?? 'UNKNOWN';
    final String knownFor = _personDetails?['known_for_department'] ?? 'UNKNOWN';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4EC),
        elevation: 0,
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
        title: Text(
          widget.name.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF111111),
            fontFamily: 'Impact',
            fontSize: 20,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image
            Center(
              child: Container(
                width: 160,
                height: 240,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4EC),
                  border: Border.all(color: const Color(0xFF111111), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF111111), offset: Offset(5, 5))
                  ],
                ),
                child: profilePath != null
                    ? Image.network(
                        'https://image.tmdb.org/t/p/w500$profilePath',
                        fit: BoxFit.cover,
                      )
                    : const Center(
                        child: Icon(Icons.person, size: 64, color: Color(0xFF111111)),
                      ),
              ),
            ),
            const SizedBox(height: 32),

            // Name
            Center(
              child: Text(
                widget.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  height: 1.0,
                  fontFamily: 'Impact',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Meta info
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111).withOpacity(0.1),
                    border: Border.all(color: const Color(0xFF111111)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    knownFor.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  birthday,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                placeOfBirth.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF454545),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(color: Color(0xFF111111), thickness: 2),
            const SizedBox(height: 32),

            // Biography
            if (biography.isNotEmpty) ...[
              _buildSectionLabel("DOSSIER / BIOGRAPHY"),
              const SizedBox(height: 16),
              Text(
                biography,
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 14,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              const Divider(color: Color(0xFF111111), thickness: 2),
              const SizedBox(height: 32),
            ],

            // Cinematic Journey
            _buildSectionLabel("CINEMATIC JOURNEY"),
            const SizedBox(height: 20),
            if (_credits.isEmpty)
              const Text(
                "NO RECORDS FOUND.",
                style: TextStyle(
                  color: Color(0xFF454545),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              )
            else
              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _credits.length,
                  itemBuilder: (context, index) {
                    final movie = _credits[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MovieDetailsScreen(movie: movie),
                          ),
                        );
                      },
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 16, bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4EC),
                          border: Border.all(color: const Color(0xFF111111), width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: movie.posterPath.isNotEmpty
                                  ? Image.network(
                                      movie.posterPath,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: const Color(0xFF111111),
                                      child: const Icon(Icons.movie, color: Color(0xFFF4F4EC)),
                                    ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              color: const Color(0xFF111111),
                              child: Text(
                                movie.title.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFF4F4EC),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

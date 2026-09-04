import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'models/movie_model.dart';
import 'movie_details_screen.dart';

class RecommendationListScreen extends StatelessWidget {
  final String title;
  final List<MovieModel> movies;

  const RecommendationListScreen({
    super.key,
    required this.title,
    required this.movies,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4EC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111111)),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 16,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w900,
            fontFamily: 'Impact',
          ),
        ),
        centerTitle: true,
      ),
      body: movies.isEmpty
          ? const Center(
              child: Text(
                "NO RECOMMENDATIONS FOUND",
                style: TextStyle(
                  color: Color(0xFF454545),
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: movies.length,
              itemBuilder: (context, index) {
                final movie = movies[index];
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
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4EC),
                      border: Border.all(color: const Color(0xFF111111), width: 2.0),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            child: CachedNetworkImage(
                              imageUrl: movie.posterPath,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const Center(
                                child: Icon(Icons.error_outline),
                              ),
                              placeholder: (context, url) => Container(
                                color: const Color(0xFF111111).withOpacity(0.1),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFF111111), width: 2.0),
                            ),
                          ),
                          child: Text(
                            movie.title.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Impact',
                              letterSpacing: 0.5,
                            ),
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
}

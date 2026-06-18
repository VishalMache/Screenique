import 'package:flutter/material.dart';
import '../models/movie_model.dart';
import '../movie_details_screen.dart';

class CinebotSuggestionCard extends StatelessWidget {
  final MovieModel movie;
  final VoidCallback onTapChat;

  const CinebotSuggestionCard({
    super.key,
    required this.movie,
    required this.onTapChat,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (movie.id != 0) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: movie)));
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border.all(color: const Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
                borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology_alt_rounded,
                        color: Color(0xFFF4F4EC), size: 12),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'CINEBOT SUGGESTS...',
                      style: TextStyle(
                        color: Color(0xFFF4F4EC),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onTapChat,
                    child: const Icon(Icons.chat_bubble_outline_rounded,
                        color: Color(0xFF888882), size: 16),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster
                  if (movie.posterPath.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.network(
                        movie.posterPath,
                        width: 80,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderPoster(),
                      ),
                    )
                  else
                    _buildPlaceholderPoster(),
                    
                  const SizedBox(width: 12),
                  
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie.title.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF4F4EC),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (movie.releaseDate.isNotEmpty)
                          Text(
                            movie.releaseDate.length >= 4
                                ? movie.releaseDate.substring(0, 4)
                                : movie.releaseDate,
                            style: const TextStyle(
                                color: Color(0xFF888882), fontSize: 10, letterSpacing: 1),
                          ),
                        const SizedBox(height: 8),
                        
                        // "Why" Text
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            border: Border.all(color: const Color(0xFF2A2A2A)),
                          ),
                          child: Text(
                            movie.overview.isNotEmpty
                                ? movie.overview
                                : 'Tap to explore this pick',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFFF4F4EC).withValues(alpha: 0.8),
                              fontSize: 10,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderPoster() {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Center(
        child: Icon(Icons.movie_filter_rounded, color: Color(0xFFD32F2F), size: 28),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../models/movie_model.dart';
import '../../../../../services/watchlist_service.dart';
import '../../../../../movie_details_screen.dart';
import '../../../../../main.dart'; // To access FilmBurnOverlay

class WatchlistTab extends StatelessWidget {
  const WatchlistTab({super.key});

  @override
  Widget build(BuildContext context) {
    final WatchlistService service = WatchlistService();
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('movies')
          .where('status', isEqualTo: 'watchlist')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF111111)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        int filmCount = docs.where((d) => (d.data() as Map)['isTvShow'] != true).length;
        int seriesCount = docs.length - filmCount;

        return Column(
          children: [
            // 1. COHESIVE WATCHLIST COUNTER HEADER
            _buildWatchlistSummary(filmCount, seriesCount),
            const Divider(color: Color(0xFF111111), height: 1.5, thickness: 1.5),

            Expanded(
              child: docs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_roll_outlined, size: 48, color: Color(0xFF888882)),
                          SizedBox(height: 12),
                          Text(
                            "NO PENDING REELS", 
                            style: TextStyle(color: Color(0xFF111111), letterSpacing: 4, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Impact'),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Your watchlist is empty.",
                            style: TextStyle(color: Color(0xFF454545), fontSize: 10),
                          ),
                        ],
                      ),
                    )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 120), 
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, 
                          childAspectRatio: 0.58, 
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final movie = MovieModel.fromJson(data);
                          return _buildNoirMovieCard(context, movie, service);
                        },
                      ),
            ),
          ],
        );
      },
    );
  }

  // Cohesive counter summary matching watched tab styling
  Widget _buildWatchlistSummary(int films, int series) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: const Color(0xFFF4F4EC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem("PENDING FILMS", films.toString()),
          _verticalDivider(),
          _statItem("PENDING SERIES", series.toString()),
          _verticalDivider(),
          _statItem("TOTAL PENDING", (films + series).toString(), color: const Color(0xFFD32F2F)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {Color color = const Color(0xFF111111)}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF111111), fontSize: 8, letterSpacing: 1.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'Impact', height: 1.0),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1.5,
      height: 24,
      color: const Color(0xFF111111).withOpacity(0.12),
    );
  }

  Widget _buildNoirMovieCard(BuildContext context, MovieModel movie, WatchlistService service) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              // Poster with Noir Shadow
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: const Color(0xFF111111), width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF111111),
                          offset: Offset(3, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Hero(
                        tag: 'rec-${movie.id}',
                        child: Image.network(
                          movie.posterPath.replaceAll('image.tmdb.org', 'images.tmdb.org'),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: const Color(0xFF111111), child: const Center(child: Icon(Icons.broken_image, color: Color(0xFFF4F4EC)))),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // COHESIVE HANGING RED BOOKMARK
              Positioned(
                top: 0,
                left: 8,
                child: Container(
                  width: 6,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC62828),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(1.5)),
                  ),
                ),
              ),
              
              // Series/Movie Badge
              Positioned(
                top: 6,
                left: 18, // Shifted to right of the bookmark
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4EC),
                    borderRadius: BorderRadius.circular(1.5),
                    border: Border.all(color: const Color(0xFF111111), width: 1.0),
                  ),
                  child: Text(
                    movie.isTvShow ? "TV" : "FILM",
                    style: const TextStyle(color: Color(0xFF111111), fontSize: 6, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ),
              ),

              // Top Action Bar
              Positioned(
                top: 6,
                right: 6,
                child: Column(
                  children: [
                    _buildCircularActionBtn(
                      icon: Icons.check, 
                      color: const Color(0xFF111111), 
                      onTap: () {
                        FilmBurnOverlay.of(context)?.triggerBurn();
                        service.toggleMovieStatus(movie, 'watched');
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildCircularActionBtn(
                      icon: Icons.close, 
                      color: const Color(0xFF111111), 
                      onTap: () => service.deleteMovie(movie.id),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Title Text
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
    );
  }

  Widget _buildCircularActionBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 24,
        width: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: const Color(0xFF111111), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 12),
      ),
    );
  }
}
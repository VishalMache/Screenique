import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../models/movie_model.dart';
import '../../../../services/watchlist_service.dart';
import '../../../../movie_details_screen.dart';
import '../../../../main.dart';
import 'playlist_detail_sheet.dart';

class WatchlistTab extends StatefulWidget {
  const WatchlistTab({super.key});

  @override
  State<WatchlistTab> createState() => _WatchlistTabState();
}

class _WatchlistTabState extends State<WatchlistTab> {
  final WatchlistService _service = WatchlistService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // 0 = QUEUE, 1 = PLAYLISTS
  int _selectedView = 0;

  // ─── New Playlist Dialog ───────────────────────────────────
  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF4F4EC),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF111111), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'NEW PLAYLIST',
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontFamily: 'Impact',
          ),
        ),
        content: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF111111), width: 1.5),
          ),
          child: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: 'E.G. HORROR ESSENTIALS',
              hintStyle: TextStyle(color: Color(0xFF888882), fontSize: 11),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF888882), fontSize: 10)),
          ),
          GestureDetector(
            onTap: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              HapticFeedback.mediumImpact();
              await _service.createPlaylist(name);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'CREATE',
                style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(String playlistId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF4F4EC),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF111111), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'DELETE PLAYLIST?',
          style: TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2, fontFamily: 'Impact'),
        ),
        content: Text(
          '"${name.toUpperCase()}" will be permanently deleted.',
          style: const TextStyle(color: Color(0xFF454545), fontSize: 11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF888882), fontSize: 10)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              await _service.deletePlaylist(playlistId);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('movies')
          .where('status', isEqualTo: 'watchlist')
          .snapshots(),
      builder: (context, moviesSnap) {
        List<QueryDocumentSnapshot> docs = List.from(moviesSnap.data?.docs ?? []);
        
        // Sort recently logged to previous
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final timeA = dataA['watchlistAddedAt'] as String?;
          final timeB = dataB['watchlistAddedAt'] as String?;
          
          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          
          return timeB.compareTo(timeA);
        });

        final int filmCount = docs.where((d) => (d.data() as Map)['isTvShow'] != true).length;
        final int seriesCount = docs.length - filmCount;

        return Column(
          children: [
            // ── Summary Stats ──
            _buildSummary(filmCount, seriesCount),
            const Divider(color: Color(0xFF111111), height: 1.5, thickness: 1.5),

            // ── QUEUE / PLAYLISTS Toggle ──
            _buildViewToggle(),
            const Divider(color: Color(0xFF111111), height: 1.5, thickness: 1.5),

            // ── Content ──
            Expanded(
              child: _selectedView == 0
                  ? _buildQueueView(docs)
                  : _buildPlaylistsView(),
            ),
          ],
        );
      },
    );
  }

  // ─── Summary Header ────────────────────────────────────────

  Widget _buildSummary(int films, int series) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: const Color(0xFFF4F4EC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem('PENDING FILMS', films.toString()),
          _divider(),
          _statItem('PENDING SERIES', series.toString()),
          _divider(),
          _statItem('TOTAL PENDING', (films + series).toString(), color: const Color(0xFFD32F2F)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {Color color = const Color(0xFF111111)}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF111111), fontSize: 8, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'Impact', height: 1.0)),
      ],
    );
  }

  Widget _divider() => Container(width: 1.5, height: 24, color: const Color(0xFF111111).withValues(alpha: 0.12));

  // ─── View Toggle ───────────────────────────────────────────

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0DB), // Softer background for the toggle area
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF111111), width: 1.5),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _toggleBtn('WATCHLIST', 0),
            const SizedBox(width: 4),
            _toggleBtn('PLAYLISTS', 1),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, int index) {
    final bool isActive = _selectedView == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedView = index),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF111111) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive ? const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))] : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFF4F4EC) : const Color(0xFF454545),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontFamily: 'Impact',
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── QUEUE View (original movie grid) ──────────────────────

  Widget _buildQueueView(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.camera_roll_outlined, size: 48, color: Color(0xFF888882)),
            SizedBox(height: 12),
            Text(
              'NO PENDING REELS',
              style: TextStyle(color: Color(0xFF111111), letterSpacing: 4, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Impact'),
            ),
            SizedBox(height: 4),
            Text('Your watchlist is empty.', style: TextStyle(color: Color(0xFF454545), fontSize: 10)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 120),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.46,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final movie = MovieModel.fromJson(data);
        return _buildMovieCard(context, movie);
      },
    );
  }

  Widget _buildMovieCard(BuildContext context, MovieModel movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: movie)),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF111111), width: 1.5),
                      boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Hero(
                        tag: 'rec-${movie.id}',
                        child: Image.network(
                          movie.posterPath.replaceAll('image.tmdb.org', 'images.tmdb.org'),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: const Color(0xFF111111), child: const Center(child: Icon(Icons.broken_image, color: Color(0xFFF4F4EC)))),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Red bookmark
              Positioned(
                top: 0, left: 8,
                child: Container(
                  width: 6, height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC62828),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
                  ),
                ),
              ),
              // TV/FILM badge
              Positioned(
                top: 6, left: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4EC),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF111111), width: 1.0),
                  ),
                  child: Text(movie.isTvShow ? 'TV' : 'FILM',
                      style: const TextStyle(color: Color(0xFF111111), fontSize: 6, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ),
              ),
            ],
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
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111111).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF111111).withOpacity(0.1), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        FilmBurnOverlay.of(context)?.triggerBurn();
                        _service.toggleMovieStatus(movie, 'watched');
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Icon(Icons.check_rounded, color: Color(0xFF4CAF50), size: 16),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 16, color: const Color(0xFF111111).withOpacity(0.15)),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _service.deleteMovie(movie.id),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Icon(Icons.close_rounded, color: Color(0xFFF44336), size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── PLAYLISTS View ────────────────────────────────────────

  Widget _buildPlaylistsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('playlists')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF111111)));
        }

        final playlists = snap.data?.docs ?? [];

        return Stack(
          children: [
            Column(
              children: [
                if (playlists.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.queue_music_rounded, size: 48, color: Color(0xFF888882)),
                          SizedBox(height: 12),
                          Text(
                            'NO PLAYLISTS YET',
                            style: TextStyle(color: Color(0xFF111111), letterSpacing: 4, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Impact'),
                          ),
                          SizedBox(height: 4),
                          Text('Create a playlist to organise your queue.', style: TextStyle(color: Color(0xFF454545), fontSize: 10)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: playlists.length,
                      itemBuilder: (context, i) {
                        final doc = playlists[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final String playlistId = doc.id;
                        final String name = data['name'] ?? 'Untitled';
                        final List<int> movieIds = List<int>.from(data['movieIds'] ?? []);

                        return _buildPlaylistCard(playlistId, name, movieIds);
                      },
                    ),
                  ),
              ],
            ),
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton(
                onPressed: _showCreatePlaylistDialog,
                backgroundColor: const Color(0xFF111111),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFD32F2F), width: 2),
                ),
                child: const Icon(Icons.add, color: Color(0xFFF4F4EC), size: 28),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaylistCard(String playlistId, String name, List<int> movieIds) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PlaylistDetailSheet(
          playlistId: playlistId,
          playlistName: name,
          initialMovieIds: movieIds,
        ),
      ),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _confirmDeletePlaylist(playlistId, name);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF111111), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon at top left
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.queue_music_rounded, color: Color(0xFFF4F4EC), size: 20),
            ),
            // Info at bottom
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Impact',
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${movieIds.length} TITLE${movieIds.length == 1 ? '' : 'S'}',
                  style: const TextStyle(color: Color(0xFF888882), fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a small strip of up to 3 stacked/tiled poster thumbnails.
  Widget _buildMiniPosters(List<int> movieIds) {
    if (movieIds.isEmpty) {
      return Container(
        width: 60,
        height: 74,
        color: const Color(0xFF222222),
        child: const Icon(Icons.movie_outlined, color: Color(0xFF444444), size: 24),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('movies')
          .where('status', isEqualTo: 'watchlist')
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            width: 60,
            height: 74,
            color: const Color(0xFF222222),
          );
        }

        final allDocs = snap.data!.docs;
        final matchedMovies = allDocs
            .map((d) => MovieModel.fromJson(d.data() as Map<String, dynamic>))
            .where((m) => movieIds.contains(m.id))
            .take(3)
            .toList();

        if (matchedMovies.isEmpty) {
          return Container(width: 60, height: 74, color: const Color(0xFF222222));
        }

        return SizedBox(
          width: 60,
          height: 74,
          child: Stack(
            children: List.generate(matchedMovies.length, (i) {
              final offset = i * 4.0;
              return Positioned(
                left: offset,
                top: offset,
                right: (matchedMovies.length - 1 - i) * 4.0,
                bottom: (matchedMovies.length - 1 - i) * 4.0,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF111111), width: 1),
                  ),
                  child: Image.network(
                    matchedMovies[i].posterPath.replaceAll('image.tmdb.org', 'images.tmdb.org'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF333333)),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
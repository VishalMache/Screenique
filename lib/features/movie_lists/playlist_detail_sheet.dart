import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../models/movie_model.dart';
import '../../../../services/watchlist_service.dart';
import '../../../../movie_details_screen.dart';
import 'playlist_broadcast_sheet.dart';

class PlaylistDetailSheet extends StatefulWidget {
  final String playlistId;
  final String playlistName;
  final List<int> initialMovieIds;

  const PlaylistDetailSheet({
    super.key,
    required this.playlistId,
    required this.playlistName,
    required this.initialMovieIds,
  });

  @override
  State<PlaylistDetailSheet> createState() => _PlaylistDetailSheetState();
}

class _PlaylistDetailSheetState extends State<PlaylistDetailSheet> {
  final WatchlistService _service = WatchlistService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  late String _playlistName;

  @override
  void initState() {
    super.initState();
    _playlistName = widget.playlistName;
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _playlistName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF4F4EC),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF111111), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'RENAME PLAYLIST',
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 13,
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
            style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
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
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              await _service.renamePlaylist(widget.playlistId, newName);
              if (mounted) setState(() => _playlistName = newName);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('SAVE', style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  /// Show the user's watchlist movies and let them pick ones to add.
  void _showAddMoviesPicker(List<int> currentMovieIds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF4F4EC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF111111), width: 3)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(height: 4, width: 40, color: const Color(0xFF111111)),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'ADD FROM WATCHLIST',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFamily: 'Impact',
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Tap a movie to add it to this playlist',
                  style: const TextStyle(color: Color(0xFF888882), fontSize: 10),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(_uid)
                      .collection('movies')
                      .where('status', isEqualTo: 'watchlist')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'YOUR WATCHLIST IS EMPTY',
                          style: TextStyle(color: Color(0xFF888882), fontSize: 11, letterSpacing: 2),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final movie = MovieModel.fromJson(docs[i].data() as Map<String, dynamic>);
                        final bool alreadyAdded = currentMovieIds.contains(movie.id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: alreadyAdded ? const Color(0xFF111111) : const Color(0xFFF4F4EC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF111111), width: 1.5),
                            boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))],
                          ),
                          child: ListTile(
                            onTap: alreadyAdded
                                ? null
                                : () async {
                                    HapticFeedback.lightImpact();
                                    await _service.addMovieToPlaylist(widget.playlistId, movie.id);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                movie.posterPath.replaceAll('image.tmdb.org', 'images.tmdb.org'),
                                width: 36,
                                height: 54,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 36, height: 54, color: const Color(0xFF333333)),
                              ),
                            ),
                            title: Text(
                              movie.title.toUpperCase(),
                              style: TextStyle(
                                color: alreadyAdded ? const Color(0xFFF4F4EC) : const Color(0xFF111111),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Impact',
                              ),
                            ),
                            subtitle: Text(
                              movie.isTvShow ? 'TV SERIES' : 'FILM',
                              style: TextStyle(
                                color: alreadyAdded ? const Color(0xFF888882) : const Color(0xFF454545),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            trailing: alreadyAdded
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFFD32F2F), size: 18)
                                : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF111111), size: 18),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('playlists')
          .doc(widget.playlistId)
          .snapshots(),
      builder: (context, playlistSnap) {
        final playlistData = playlistSnap.data?.data() as Map<String, dynamic>?;
        final List<int> movieIds = List<int>.from(playlistData?['movieIds'] ?? widget.initialMovieIds);

        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Color(0xFFF4F4EC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF111111), width: 3)),
          ),
          child: Column(
            children: [
              // ── Handle + Header ──
              const SizedBox(height: 10),
              Container(height: 4, width: 40, color: const Color(0xFF111111)),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _playlistName.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontFamily: 'Impact',
                            ),
                          ),
                          Text(
                            '${movieIds.length} TITLE${movieIds.length == 1 ? '' : 'S'}',
                            style: const TextStyle(color: Color(0xFF888882), fontSize: 10, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                    // Rename button
                    GestureDetector(
                      onTap: _showRenameDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF111111), width: 1.5),
                        ),
                        child: const Text(
                          'RENAME',
                          style: TextStyle(color: Color(0xFF111111), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 1.5, color: const Color(0xFF111111)),

              // ── Movie List ──
              Expanded(
                child: movieIds.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.movie_filter_outlined, size: 40, color: Color(0xFF888882)),
                            SizedBox(height: 10),
                            Text(
                              'NO TITLES YET',
                              style: TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 3, fontFamily: 'Impact'),
                            ),
                            SizedBox(height: 4),
                            Text('Tap "ADD MOVIES" below to populate this playlist.', style: TextStyle(color: Color(0xFF888882), fontSize: 10)),
                          ],
                        ),
                      )
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(_uid)
                            .collection('movies')
                            .where('status', isEqualTo: 'watchlist')
                            .snapshots(),
                        builder: (context, moviesSnap) {
                          if (!moviesSnap.hasData) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
                          }

                          // Build a map for O(1) lookup
                          final allWatchlistMovies = {
                            for (final d in moviesSnap.data!.docs)
                              (d.data() as Map<String, dynamic>)['id'] is int
                                  ? (d.data() as Map<String, dynamic>)['id'] as int
                                  : int.tryParse(((d.data() as Map<String, dynamic>)['id']).toString()) ?? 0:
                                  MovieModel.fromJson(d.data() as Map<String, dynamic>)
                          };

                          final playlistMovies = movieIds
                              .map((id) => allWatchlistMovies[id])
                              .whereType<MovieModel>()
                              .toList();

                          if (playlistMovies.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'These movies may have been removed from your watchlist.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF888882), fontSize: 11),
                                ),
                              ),
                            );
                          }

                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.58,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: playlistMovies.length,
                            itemBuilder: (context, i) {
                              final movie = playlistMovies[i];
                              return Column(
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
                                        // TV/FILM badge
                                        Positioned(
                                          top: 6, left: 6,
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
                                        // Remove button
                                        Positioned(
                                          top: 6, right: 6,
                                          child: GestureDetector(
                                            onTap: () async {
                                              HapticFeedback.lightImpact();
                                              await _service.removeMovieFromPlaylist(widget.playlistId, movie.id);
                                            },
                                            child: Container(
                                              height: 24, width: 24,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF4F4EC),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFF111111), width: 1.5),
                                              ),
                                              child: const Icon(Icons.close, color: Color(0xFFD32F2F), size: 12),
                                            ),
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
                                ],
                              );
                            },
                          );
                        },
                      ),
              ),

              // ── Bottom Action Buttons ──
              Container(
                color: const Color(0xFFF4F4EC),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: Column(
                  children: [
                    Container(height: 1.5, color: const Color(0xFF111111)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Add Movies
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showAddMoviesPicker(movieIds),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F4EC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF111111), width: 2),
                                boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))],
                              ),
                              child: const Center(
                                child: Text(
                                  '＋ ADD MOVIES',
                                  style: TextStyle(color: Color(0xFF111111), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'Impact'),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Share to Community
                        Expanded(
                          child: GestureDetector(
                            onTap: movieIds.isEmpty
                                ? null
                                : () async {
                                    // Fetch actual movie objects for broadcast
                                    final snap = await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(_uid)
                                        .collection('movies')
                                        .where('status', isEqualTo: 'watchlist')
                                        .get();

                                    final allMovies = snap.docs
                                        .map((d) => MovieModel.fromJson(d.data()))
                                        .where((m) => movieIds.contains(m.id))
                                        .toList();

                                    if (!mounted) return;
                                    // ignore: use_build_context_synchronously
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => PlaylistBroadcastSheet(
                                        playlistName: _playlistName,
                                        movies: allMovies,
                                        service: _service,
                                      ),
                                    );
                                  },
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: movieIds.isEmpty ? const Color(0xFF888882) : const Color(0xFFD32F2F),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF111111), width: 2),
                                boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))],
                              ),
                              child: const Center(
                                child: Text(
                                  '📡 SHARE TO HUB',
                                  style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'Impact'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
}

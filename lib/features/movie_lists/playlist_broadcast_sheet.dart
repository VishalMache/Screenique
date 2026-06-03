import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/movie_model.dart';
import '../../../../services/watchlist_service.dart';
import '../../../../broadcast_wire_screen.dart';

class PlaylistBroadcastSheet extends StatefulWidget {
  final String playlistName;
  final List<MovieModel> movies;
  final WatchlistService service;

  const PlaylistBroadcastSheet({
    super.key,
    required this.playlistName,
    required this.movies,
    required this.service,
  });

  @override
  State<PlaylistBroadcastSheet> createState() => _PlaylistBroadcastSheetState();
}

class _PlaylistBroadcastSheetState extends State<PlaylistBroadcastSheet> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isBroadcasting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final previewMovies = widget.movies.take(4).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4EC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF111111), width: 3)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──
          Center(child: Container(height: 4, width: 40, color: const Color(0xFF111111))),
          const SizedBox(height: 16),

          // ── Title ──
          const Text(
            'BROADCAST PLAYLIST',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontFamily: 'Impact',
            ),
          ),
          const Text(
            'Share your curated list with the community',
            style: TextStyle(color: Color(0xFF888882), fontSize: 10),
          ),
          const SizedBox(height: 18),

          // ── Playlist Preview Card ──
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF111111), width: 2),
              boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 2×2 Poster Grid
                SizedBox(
                  width: 80,
                  height: 80,
                  child: _buildPosterGrid(previewMovies),
                ),
                const SizedBox(width: 16),
                // Playlist Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PLAYLIST:',
                        style: TextStyle(color: Color(0xFF888882), fontSize: 8, letterSpacing: 2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.playlistName.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFF4F4EC),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Impact',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.movies.length} TITLE${widget.movies.length == 1 ? '' : 'S'}',
                        style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Reason Field ──
          const Text(
            'YOUR MESSAGE TO THE COMMUNITY',
            style: TextStyle(color: Color(0xFF111111), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4EC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF111111), width: 2),
              ),
              child: TextField(
                controller: _reasonController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'E.G. THESE ARE THE FILMS THAT SHAPED MY TASTE IN CINEMA...',
                  hintStyle: TextStyle(color: Color(0xFF888882), fontSize: 11),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Transmit Button ──
          GestureDetector(
            onTap: _isBroadcasting
                ? null
                 : () async {
                    final reason = _reasonController.text.trim();
                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('WRITE A MESSAGE BEFORE POSTING! 🎬'),
                          backgroundColor: Color(0xFFD32F2F),
                        ),
                      );
                      return;
                    }

                    setState(() => _isBroadcasting = true);
                    // Capture context-dependent objects before async gap
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await widget.service.broadcastPlaylist(
                        playlistName: widget.playlistName,
                        movies: widget.movies,
                        reason: reason,
                      );
                      HapticFeedback.heavyImpact();
                      if (mounted) {
                        // Pop both the broadcast sheet and the playlist detail sheet
                        navigator.pop();
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('📡 PLAYLIST POSTED TO COMMUNITY HUB!'),
                            backgroundColor: Color(0xFF111111),
                            duration: Duration(seconds: 3),
                          ),
                        );
                        // Redirect to the Community Hub (BroadcastWireScreen)
                        navigator.push(MaterialPageRoute(builder: (_) => const BroadcastWireScreen()));
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isBroadcasting = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Posting failed: $e'), backgroundColor: const Color(0xFFD32F2F)),
                        );
                      }
                    }
                  },
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF111111), width: 2),
                boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
              ),
              child: Center(
                child: _isBroadcasting
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Color(0xFFF4F4EC), strokeWidth: 2.5))
                    : const Text(
                        '📡 POST PLAYLIST',
                        style: TextStyle(
                          color: Color(0xFFF4F4EC),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontFamily: 'Impact',
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterGrid(List<MovieModel> movies) {
    if (movies.isEmpty) {
      return Container(color: const Color(0xFF333333), child: const Icon(Icons.movie, color: Color(0xFF888882), size: 32));
    }
    if (movies.length == 1) {
      return _poster(movies[0].posterPath);
    }

    // 2x2 grid for 2-4 posters
    final items = List.generate(4, (i) => i < movies.length ? movies[i].posterPath : null);
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _poster(items[0])),
              const SizedBox(width: 2),
              Expanded(child: _poster(items[1])),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _poster(items[2])),
              const SizedBox(width: 2),
              Expanded(child: _poster(items[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _poster(String? url) {
    if (url == null || url.isEmpty) {
      return Container(color: const Color(0xFF333333));
    }
    return Image.network(
      url.replaceAll('image.tmdb.org', 'images.tmdb.org'),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF333333)),
    );
  }
}

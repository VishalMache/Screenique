import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'public_profile_screen.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/movie_model.dart';
import 'services/watchlist_service.dart';
import 'services/movie_service.dart';
import 'movie_details_screen.dart';
import 'user_search_screen.dart';
import 'post_likes_screen.dart';
import 'comments_bottom_sheet.dart';

class BroadcastWireScreen extends StatefulWidget {
  const BroadcastWireScreen({super.key});

  @override
  State<BroadcastWireScreen> createState() => _BroadcastWireScreenState();
}

class _BroadcastWireScreenState extends State<BroadcastWireScreen> {
  final WatchlistService _watchlistService = WatchlistService();
  final MovieService _movieService = MovieService();
  final TextEditingController _broadcastSearchController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final Map<String, Timer> _viewTimers = {};
  
  List<MovieModel> _searchResults = [];
  bool _isSearching = false;
  bool _isBroadcasting = false;
  MovieModel? _selectedMovieForBroadcast;

  @override
  void dispose() {
    for (var timer in _viewTimers.values) {
      timer.cancel();
    }
    _broadcastSearchController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Widget _buildVisibilityWrapper(String docId, Widget child) {
    return VisibilityDetector(
      key: Key('broadcast_$docId'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5) {
          if (!_viewTimers.containsKey(docId)) {
            _viewTimers[docId] = Timer(const Duration(milliseconds: 1500), () {
              _watchlistService.incrementView(docId);
              _viewTimers.remove(docId);
            });
          }
        } else {
          _viewTimers[docId]?.cancel();
          _viewTimers.remove(docId);
        }
      },
      child: child,
    );
  }

  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);
    
    if (diff.inDays > 365) return "${(diff.inDays / 365).floor()}y";
    if (diff.inDays > 30) return "${(diff.inDays / 30).floor()}mo";
    if (diff.inDays > 0) return "${diff.inDays}d";
    if (diff.inHours > 0) return "${diff.inHours}h";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m";
    return "Just now";
  }

  void _confirmBroadcastDeletion(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.white10),
        ),
        title: const Text(
          "EXPUNGE TRANSMISSION?",
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontFamily: 'Impact',
          ),
        ),
        content: const Text(
          "This recommendation will be permanently removed from Community's Choice.",
          style: TextStyle(color: Colors.white70, fontSize: 11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white24, fontSize: 10)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () async {
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
              await _watchlistService.deleteBroadcast(docId);
            },
            child: const Text(
              "DELETE",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        title: const Text(
          "REPORT CONTENT",
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        content: const Text(
          "Flag this transmission for inappropriate content?",
          style: TextStyle(color: Colors.white70, fontSize: 11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white24, fontSize: 10)),
          ),
          TextButton(
            onPressed: () async {
              await _watchlistService.reportBroadcast(docId, "Inappropriate content");
              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("TRANSMISSION REPORTED FOR AUDIT 🛑"),
                  backgroundColor: Color(0xFFD32F2F),
                ),
              );
            },
            child: const Text(
              "REPORT",
              style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF15181E),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text("CREATE TRANSMISSION", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 2)),
              const SizedBox(height: 24),
              _buildActionTile(Icons.movie_creation_rounded, "Movie or Series", "Recommend a title to the community", () {
                Navigator.pop(context);
                _showBroadcastCreationSheet();
              }),
              const SizedBox(height: 12),
              _buildActionTile(Icons.collections_bookmark_rounded, "Playlist", "Share your curated collections", () {
                Navigator.pop(context);
                // In a real implementation this would navigate to a playlist selection screen
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Playlist selection coming soon!"), backgroundColor: Color(0xFFD32F2F)));
              }),
              const SizedBox(height: 12),
              _buildActionTile(Icons.text_fields_rounded, "Text Post", "Start a discussion", () {
                Navigator.pop(context);
                _showTextBroadcastSheet();
              }),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFFD32F2F), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  void _showTextBroadcastSheet() {
    _reasonController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF15181E),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text("TEXT TRANSMISSION", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 2)),
                const SizedBox(height: 16),
                TextField(
                  controller: _reasonController,
                  maxLines: 4,
                  maxLength: 280,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "What's on your cinematic mind?",
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF222222),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_reasonController.text.trim().isEmpty) return;
                      Navigator.pop(context);
                      await _watchlistService.broadcastTextPost(_reasonController.text.trim());
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transmission broadcasted!"), backgroundColor: Color(0xFFD32F2F)));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("TRANSMIT", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBroadcastCreationSheet() {
    setState(() {
      _searchResults = [];
      _broadcastSearchController.clear();
      _selectedMovieForBroadcast = null;
      _reasonController.clear();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4EC),
              border: const Border(
                top: BorderSide(color: Color(0xFF111111), width: 3.0),
              ),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(height: 4, width: 40, color: const Color(0xFF111111)),
                ),
                const SizedBox(height: 16),
                const Text(
                  "BROADCAST TO COMMUNITY",
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFamily: 'Impact',
                  ),
                ),
                const SizedBox(height: 16),
                
                if (_selectedMovieForBroadcast == null) ...[
                  // Search Field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4EC),
                      border: Border.all(color: const Color(0xFF111111), width: 2.0),
                    ),
                    child: TextField(
                      controller: _broadcastSearchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (val) async {
                        setSheetState(() => _isSearching = true);
                        final results = await _movieService.searchAll(val);
                        setSheetState(() {
                          _searchResults = results.where((item) => !item.isPerson).toList();
                          _isSearching = false;
                        });
                      },
                      style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: "SEARCH MOVIE OR SHOW...",
                        hintStyle: TextStyle(color: Color(0xFF888882), fontSize: 11, letterSpacing: 1),
                        prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF111111), size: 16),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Search Results List
                  if (_isSearching)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F))),
                    )
                  else
                    Expanded(
                      child: _searchResults.isEmpty
                          ? const Center(
                              child: Text(
                                "SEARCH CINE REELS ABOVE 🎬",
                                style: TextStyle(color: Color(0xFF888882), fontSize: 11, letterSpacing: 2),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final movie = _searchResults[index];
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F4EC),
                                    border: Border.all(color: const Color(0xFF111111), width: 1.5),
                                    boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
                                  ),
                                  child: ListTile(
                                    onTap: () {
                                      setSheetState(() {
                                        _selectedMovieForBroadcast = movie;
                                      });
                                    },
                                    leading: Image.network(
                                      movie.posterPath,
                                      width: 40,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(width: 40, color: const Color(0xFF111111)),
                                    ),
                                    title: Text(
                                      movie.title.toUpperCase(),
                                      style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      movie.releaseDate.contains('-') ? movie.releaseDate.split('-').first : movie.releaseDate,
                                      style: const TextStyle(color: Color(0xFF454545), fontSize: 9),
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF111111), size: 12),
                                  ),
                                );
                              },
                            ),
                    ),
                ] else ...[
                  // Write Reason Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      border: Border.all(color: const Color(0xFF111111), width: 2),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Image.network(
                            _selectedMovieForBroadcast!.posterPath,
                            width: 50,
                            height: 75,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "SELECTED ENTITY:",
                                style: TextStyle(color: const Color(0xFFF4F4EC).withOpacity(0.5), fontSize: 8, letterSpacing: 1),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedMovieForBroadcast!.title.toUpperCase(),
                                style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => setSheetState(() => _selectedMovieForBroadcast = null),
                                child: const Text(
                                  "CHANGE SELECTION?",
                                  style: TextStyle(color: Color(0xFFD32F2F), fontSize: 9, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  const Text(
                    "REASON FOR RECOMMENDATION",
                    style: TextStyle(color: Color(0xFF111111), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4EC),
                      border: Border.all(color: const Color(0xFF111111), width: 2.0),
                    ),
                    child: TextField(
                      controller: _reasonController,
                      maxLines: 4,
                      style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: "E.G. THE CINEMATOGRAPHY IS BREATHTAKING, A PURE ARCHIVAL MASTERPIECE...",
                        hintStyle: TextStyle(color: Color(0xFF888882), fontSize: 11),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const Spacer(),
                  
                  GestureDetector(
                    onTap: _isBroadcasting ? null : () async {
                      final reason = _reasonController.text.trim();
                      if (reason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("PLEASE WRITE A REASON FOR TRANSMISSION! 🎬"),
                            backgroundColor: Color(0xFFD32F2F),
                          ),
                        );
                        return;
                      }
                      
                      setSheetState(() => _isBroadcasting = true);
                      try {
                        await _watchlistService.broadcastMovie(_selectedMovieForBroadcast!, reason);
                        if (mounted) Navigator.pop(context);
                        HapticFeedback.heavyImpact();
                      } catch (_) {
                        setSheetState(() => _isBroadcasting = false);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        border: Border.all(color: const Color(0xFF111111), width: 2.0),
                        boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
                      ),
                      child: Center(
                        child: _isBroadcasting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xFFF4F4EC), strokeWidth: 2))
                            : const Text(
                                "TRANSMIT TO COMMUNITY",
                                style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, fontFamily: 'Impact'),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFullTransmission(MovieModel movie, String reason, Color accent) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, 
      builder: (context) => Container(
        padding: const EdgeInsets.all(24), 
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC), 
          border: Border.all(color: const Color(0xFF111111), width: 2.0)
        ), 
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2), 
                  child: Image.network(movie.posterPath, width: 40, height: 60, fit: BoxFit.cover)
                ), 
                const SizedBox(width: 15), 
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text("TRANSMISSION LOG", style: TextStyle(color: accent, fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.bold)), 
                      const SizedBox(height: 4), 
                      Text(movie.title.toUpperCase(), style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'serif'))
                    ]
                  )
                )
              ]
            ), 
            const Divider(color: Color(0xFF111111), height: 30, thickness: 1.5), 
            const Text("REASON FOR RECOMMENDATION:", style: TextStyle(color: Color(0xFF454545), fontSize: 9, letterSpacing: 1, fontFamily: 'monospace')), 
            const SizedBox(height: 12), 
            Flexible(
              child: SingleChildScrollView(
                child: Text("\"$reason\"", style: const TextStyle(color: Color(0xFF111111), fontSize: 14, height: 1.6, fontStyle: FontStyle.italic, fontFamily: 'serif'))
              )
            ), 
            const SizedBox(height: 30), 
            SizedBox(
              width: double.infinity, 
              child: TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text("CLOSE LOG", style: TextStyle(color: Color(0xFF111111), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold))
              )
            )
          ]
        )
      )
    );
  }

  // ────────────────────────────────────────────────────────
  // PLAYLIST FEED CARD
  // ────────────────────────────────────────────────────────

  void _showPlaylistDetailSheet(Map<String, dynamic> data) {
    final List<String> titles = List<String>.from(data['movieTitles'] ?? []);
    final List<String> posters = List<String>.from(data['posterPaths'] ?? []);
    final String playlistName = data['playlistName'] ?? 'Untitled Playlist';
    final String reason = data['reason'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF4F4EC),
            border: Border(top: BorderSide(color: Color(0xFF111111), width: 3)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(height: 4, width: 40, color: const Color(0xFF111111)),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PLAYLIST', style: TextStyle(color: Color(0xFFD32F2F), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text(
                      playlistName.toUpperCase(),
                      style: const TextStyle(color: Color(0xFF111111), fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 1),
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '"$reason"',
                        style: const TextStyle(color: Color(0xFF454545), fontSize: 12, fontStyle: FontStyle.italic, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '${titles.length} TITLE${titles.length == 1 ? '' : 'S'}',
                      style: const TextStyle(color: Color(0xFF888882), fontSize: 10, letterSpacing: 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 1.5, color: const Color(0xFF111111)),
              Expanded(
                child: titles.isEmpty
                    ? const Center(
                        child: Text('No titles listed.', style: TextStyle(color: Color(0xFF888882), fontSize: 11)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                        itemCount: titles.length,
                        itemBuilder: (_, i) {
                          final poster = i < posters.length ? posters[i] : null;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4EC),
                              border: Border.all(color: const Color(0xFF111111), width: 1.5),
                              boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))],
                            ),
                            child: Row(
                              children: [
                                if (poster != null)
                                  Image.network(
                                    poster.replaceAll('image.tmdb.org', 'images.tmdb.org'),
                                    width: 40,
                                    height: 58,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(width: 40, height: 58, color: const Color(0xFF222222)),
                                  )
                                else
                                  Container(width: 40, height: 58, color: const Color(0xFF222222)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    titles[i].toUpperCase(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF111111),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Impact',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnalyticsBottomSheet(int viewCount, int likeCount, Timestamp? timestamp, List<dynamic> likedBy) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final timeString = timestamp != null 
          ? "${timestamp.toDate().year}-${timestamp.toDate().month.toString().padLeft(2, '0')}-${timestamp.toDate().day.toString().padLeft(2, '0')} ${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}"
          : "Unknown";
          
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: const BoxDecoration(
            color: Color(0xFFF4F4EC),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            border: Border(top: BorderSide(color: Color(0xFF111111), width: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "POST METRICS",
                style: TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 2),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF454545), size: 24),
                      const SizedBox(width: 12),
                      const Text("Total Views", style: TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(viewCount.toString(), style: const TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ],
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pop(context); // close bottom sheet
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PostLikesScreen(likedByUids: likedBy)));
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite_rounded, color: Color(0xFFD32F2F), size: 24),
                        const SizedBox(width: 12),
                        const Text("Total Likes", style: TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        Text(likeCount.toString(), style: const TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF454545), size: 14),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF111111), thickness: 2),
              const SizedBox(height: 16),
              Text("Posted: $timeString", style: const TextStyle(color: Color(0xFF454545), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostFooter(String docId, bool isOwner, Timestamp? timestamp, Map<String, dynamic> docData, String? currentUserId) {
    final List likedBy = docData['likedBy'] ?? docData['likes'] ?? [];
    final int likeCount = docData['likeCount'] ?? likedBy.length;
    final bool isLiked = currentUserId != null && likedBy.contains(currentUserId);
    final int viewCount = docData['viewCount'] ?? 0;
    final int repostCount = docData['repostCount'] ?? 0;
    final int commentCount = docData['commentCount'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Comments
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (currentUserId == null) return;
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => CommentsBottomSheet(
                  postId: docId,
                  postAuthorId: docData['senderId'] ?? '',
                  currentUserId: currentUserId,
                ),
              );
            },
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 6),
                Text(
                  commentCount.toString(),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          
          // Repost
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              if (currentUserId == null) return;
              HapticFeedback.lightImpact();
              await _watchlistService.repostBroadcast(docId, docData);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transmission Reposted!"), backgroundColor: Color(0xFFD32F2F)));
              }
            },
            child: Row(
              children: [
                const Icon(Icons.repeat_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 6),
                Text(
                  repostCount > 0 ? repostCount.toString() : '',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),

          // Like
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              if (currentUserId != null) {
                HapticFeedback.lightImpact();
                await _watchlistService.toggleBroadcastLike(docId, currentUserId, isLiked);
              }
            },
            child: Row(
              children: [
                Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked ? const Color(0xFFD32F2F) : Colors.white54,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  likeCount.toString(),
                  style: TextStyle(
                    color: isLiked ? const Color(0xFFD32F2F) : Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Views
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isOwner ? () => _showAnalyticsBottomSheet(viewCount, likeCount, timestamp, likedBy) : null,
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 6),
                Text(
                  viewCount.toString(),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),

          // Share / More
          isOwner
              ? IconButton(
                  onPressed: () => _confirmBroadcastDeletion(docId),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : IconButton(
                  onPressed: () => _showReportDialog(docId),
                  icon: const Icon(Icons.ios_share_rounded, color: Colors.white54, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
        ],
      ),
    );
  }

  Widget _buildPlaylistFeedCard({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String docId,
    required bool isOwner,
    required String currentUserId,
  }) {
    final String playlistName = data['playlistName'] ?? 'Untitled Playlist';
    final List<String> posterPaths = List<String>.from(data['posterPaths'] ?? []);
    final List<String> movieTitles = List<String>.from(data['movieTitles'] ?? []);
    final String senderName = data['senderName'] ?? 'Anonymous';
    final String reason = data['reason'] ?? '';
    final int senderRankCount = data['senderRankCount'] ?? 0;
    final Color rankColor = ArchiveRank.getColor(senderRankCount);
    final String rankName = ArchiveRank.getTitle(senderRankCount);
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
    final String timeAgo = _formatTimeAgo(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author Header ──
          GestureDetector(
            onTap: () {
              final sid = data['senderId'];
              if (sid != null && sid.toString().isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: sid)));
              }
            },
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: rankColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF111111), width: 1.5),
                  ),
                child: Center(
                  child: Text(
                    senderName.isNotEmpty ? senderName[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Impact'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          senderName.toUpperCase(),
                          style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Text('• $timeAgo', style: const TextStyle(color: Color(0xFF888882), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.verified_user_rounded, color: rankColor, size: 10),
                        const SizedBox(width: 4),
                        Text(rankName.toUpperCase(), style: TextStyle(color: rankColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  ],
                ),
              ),
              // Playlist badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text('📋 PLAYLIST', style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ],
          ),
          ),
          const SizedBox(height: 12),

          // ── Playlist Card ──
          GestureDetector(
            onTap: () => _showPlaylistDetailSheet(data),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4EC),
                border: Border.all(color: const Color(0xFF111111), width: 1.5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Horizontal poster strip
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 90,
                      child: _buildHorizontalPosterStrip(posterPaths),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.queue_music_rounded, color: Color(0xFFF4F4EC), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playlistName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF111111), fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${movieTitles.length} TITLE${movieTitles.length == 1 ? '' : 'S'}  ·  TAP TO VIEW',
                              style: const TextStyle(color: Color(0xFF888882), fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBEBE4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.format_quote_rounded, size: 14, color: Color(0xFF888882)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              reason,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF454545), fontSize: 12, fontStyle: FontStyle.italic, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Action Bar ──
          // ── Action Bar ──
          _buildPostFooter(docId, isOwner, timestamp, data, currentUserId),

          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Divider(color: Color(0xFFE0E0DB), thickness: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalPosterStrip(List<String> posters) {
    if (posters.isEmpty) {
      return Container(
        color: const Color(0xFF222222),
        child: const Center(child: Icon(Icons.playlist_play_rounded, color: Color(0xFF444444), size: 48)),
      );
    }
    
    final displayCount = posters.length > 4 ? 4 : posters.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(displayCount, (i) {
        return Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: i < displayCount - 1 ? const Border(right: BorderSide(color: const Color(0xFF111111), width: 1.5)) : null,
            ),
            child: Image.network(
              posters[i].replaceAll('image.tmdb.org', 'images.tmdb.org'),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF222222)),
            ),
          ),
        );
      }),
    );
  }


  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "COMMUNITY SPACE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontFamily: 'Impact',
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "THE CINECAST WIRE",
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 20,
                  height: 1,
                  color: const Color(0xFFD32F2F),
                )
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFF222222),
            height: 1,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('community_recs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.podcasts_rounded, color: Color(0xFF454545), size: 48),
                  SizedBox(height: 12),
                  Text(
                    "COMMUNITY FEED IS EMPTY",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, fontFamily: 'Impact'),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Be the first to transmit a recommendation to the community!",
                    style: TextStyle(color: Color(0xFF888888), fontSize: 10),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            physics: const BouncingScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isOwner = currentUserId == data['senderId'];
              final String docId = doc.id;
              
              return _buildVisibilityWrapper(docId, _buildThreadPost(context, data, docId, isOwner, currentUserId));
            },
          );
        },
      ),
      
      floatingActionButton: SpeedDial(
        icon: Icons.add_rounded,
        activeIcon: Icons.close_rounded,
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        activeBackgroundColor: const Color(0xFF111111),
        activeForegroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        overlayColor: Colors.black,
        overlayOpacity: 0.7,
        spacing: 12,
        spaceBetweenChildren: 12,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.text_fields_rounded, color: Color(0xFFD32F2F)),
            backgroundColor: const Color(0xFF15181E),
            label: 'Text Post',
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            labelBackgroundColor: const Color(0xFF15181E),
            onTap: _showTextBroadcastSheet,
          ),
          SpeedDialChild(
            child: const Icon(Icons.collections_bookmark_rounded, color: Color(0xFFD32F2F)),
            backgroundColor: const Color(0xFF15181E),
            label: 'Playlist',
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            labelBackgroundColor: const Color(0xFF15181E),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Playlist selection coming soon!"), backgroundColor: Color(0xFFD32F2F)));
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.movie_creation_rounded, color: Color(0xFFD32F2F)),
            backgroundColor: const Color(0xFF15181E),
            label: 'Movie or Series',
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            labelBackgroundColor: const Color(0xFF15181E),
            onTap: _showBroadcastCreationSheet,
          ),
        ],
      ),
    );
  }


  Widget _buildThreadPost(BuildContext context, Map<String, dynamic> data, String docId, bool isOwner, String currentUserId) {
    final String type = data['type'] ?? 'movie';
    final String senderName = data['senderName'] ?? data['broadcastSender'] ?? data['reposterName'] ?? "Anonymous";
    final int senderRankCount = data['senderRankCount'] ?? data['reposterRankCount'] ?? 0;
    final Color rankColor = ArchiveRank.getColor(senderRankCount);
    final String rankName = ArchiveRank.getTitle(senderRankCount);
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
    final String timeAgo = _formatTimeAgo(timestamp);
    final String username = data['username'] ?? senderName.toLowerCase().replaceAll(' ', '');
    final String reason = data['reason'] ?? data['broadcastReason'] ?? '';
    final bool isRepost = data['isRepost'] == true;
    final String reposterName = data['reposterName'] ?? '';

    Widget embeddedCard = const SizedBox.shrink();

    if (type == 'movie' || type == 'song') {
      final movie = MovieModel.fromJson(data);
      embeddedCard = Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF15181E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
              child: Image.network(
                movie.posterPath.replaceAll('image.tmdb.org', 'images.tmdb.org'),
                width: 90,
                height: 135,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(width: 90, height: 135, color: const Color(0xFF222222)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${movie.releaseDate.contains('-') ? movie.releaseDate.split('-').first : movie.releaseDate} • ${movie.isTvShow ? 'TV Series' : 'Movie'}",
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      movie.overview ?? "No description available.",
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFD32F2F), size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (type == 'playlist') {
      final playlistName = data['playlistName'] ?? 'Playlist';
      final posterPaths = List<String>.from(data['posterPaths'] ?? []);
      final titles = List<String>.from(data['movieTitles'] ?? []);
      embeddedCard = GestureDetector(
        onTap: () => _showPlaylistDetailSheet(data),
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF15181E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                child: SizedBox(
                  height: 100,
                  child: Row(
                    children: List.generate(
                      posterPaths.length > 4 ? 4 : posterPaths.length,
                      (i) => Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              posterPaths[i].replaceAll('image.tmdb.org', 'images.tmdb.org'),
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: const Color(0xFF222222)),
                            ),
                            if (i == 3 && posterPaths.length > 4)
                              Container(
                                color: Colors.black.withOpacity(0.7),
                                child: Center(
                                  child: Text(
                                    "+${posterPaths.length - 3}\nMORE",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.collections_bookmark_rounded, color: Color(0xFFD32F2F), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlistName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${titles.length} titles",
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      "VIEW",
                      style: TextStyle(color: Color(0xFFD32F2F), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (type == 'news_broadcast') {
      final headline = data['title'] ?? 'News';
      final source = data['sourceName'] ?? 'Source';
      final articleUrl = data['articleUrl'] ?? '';
      final posterPath = data['posterPath'] ?? '';
      embeddedCard = GestureDetector(
        onTap: () async {
          final uri = Uri.parse(articleUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF15181E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                child: posterPath.isNotEmpty 
                  ? Image.network(posterPath, width: 90, height: 100, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 90, height: 100, color: const Color(0xFF222222)))
                  : Container(width: 90, height: 100, color: const Color(0xFF222222), child: const Icon(Icons.newspaper, color: Colors.white)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(4)),
                        child: const Text("NEWS", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                      const SizedBox(height: 8),
                      Text(headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(source.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Avatar & Thread Line
            Column(
              children: [
                GestureDetector(
                  onTap: () {
                    final sid = data['senderId'];
                    if (sid != null && sid.toString().isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: sid)));
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: rankColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        senderName.isNotEmpty ? senderName[0].toUpperCase() : "A",
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Impact'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: 1,
                    color: Colors.white10,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            
            // Right Column: Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isRepost) ...[
                    Row(
                      children: [
                        const Icon(Icons.repeat_rounded, color: Colors.white54, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "$reposterName reposted",
                          style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      Text(
                        senderName.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "@$username",
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "• $timeAgo",
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Text Content
                  if (reason.isNotEmpty)
                    Text(
                      reason,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                    ),
                  
                  // Embedded Media
                  embeddedCard,
                  
                  const SizedBox(height: 8),
                  
                  // Action Bar
                  _buildPostFooter(docId, isOwner, timestamp, data, currentUserId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsFeedCard({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String docId,
    required bool isOwner,
    required String? currentUserId,
  }) {
    final String headline = data['title'] ?? 'Unknown News';
    final String sourceName = data['sourceName'] ?? 'News';
    final String articleUrl = data['articleUrl'] ?? '';
    final String posterPath = data['posterPath'] ?? '';
    final String reason = data['reason'] ?? 'No reason provided.';
    final String senderName = data['senderName'] ?? 'Anonymous';
    final int senderRankCount = data['senderRankCount'] ?? 0;
    
    final Color rankColor = ArchiveRank.getColor(senderRankCount);
    final String rankName = ArchiveRank.getTitle(senderRankCount);
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
    final String timeAgo = _formatTimeAgo(timestamp);

    final List<dynamic> likes = data['likes'] ?? [];
    final bool isLiked = currentUserId != null && likes.contains(currentUserId);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          GestureDetector(
            onTap: () {
              final sid = data['senderId'];
              if (sid != null && sid.toString().isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: sid)));
              }
            },
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: rankColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF111111), width: 1.5),
                  ),
                child: Center(
                  child: Text(
                    senderName.isNotEmpty ? senderName[0].toUpperCase() : "A",
                    style: const TextStyle(
                      color: Color(0xFFF4F4EC),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Impact',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          senderName.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Impact',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "• $timeAgo",
                          style: const TextStyle(
                            color: Color(0xFF888882),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.verified_user_rounded, color: rankColor, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          rankName.toUpperCase(),
                          style: TextStyle(
                            color: rankColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
          
          const SizedBox(height: 12),
          
          // Reason Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEBEBE4),
              border: Border.all(color: const Color(0xFF111111), width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_quote_rounded, color: Color(0xFFD32F2F), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "TRANSMISSION LOG",
                      style: const TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  reason,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Interactive Entity Card
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(articleUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
              }
            },
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                border: Border.all(color: const Color(0xFF111111), width: 2),
                boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
              ),
              child: Row(
                children: [
                  // Poster / Entity Image
                  Container(
                    width: 75,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      border: const Border(right: BorderSide(color: Color(0xFFF4F4EC), width: 1)),
                    ),
                    child: posterPath.isNotEmpty
                        ? Image.network(
                            posterPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.newspaper, color: Color(0xFFF4F4EC))),
                          )
                        : const Center(child: Icon(Icons.newspaper, color: Color(0xFFF4F4EC))),
                  ),
                  
                  // Details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            color: const Color(0xFFD32F2F),
                            child: const Text(
                              "NEWS",
                              style: TextStyle(
                                color: Color(0xFFF4F4EC),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            headline.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFF4F4EC),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Impact',
                              letterSpacing: 0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sourceName.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF888882),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Action Bar (Like / Delete / Report)
          _buildPostFooter(docId, isOwner, timestamp, data, currentUserId),
          
          // Divider
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Divider(color: Color(0xFFE0E0DB), thickness: 1.5),
          ),
        ],
      ),
    );
  }
}

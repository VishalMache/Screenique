import 'dart:async';
import 'package:flutter/material.dart';
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (isOwner)
              GestureDetector(
                onTap: () => _showAnalyticsBottomSheet(viewCount, likeCount, timestamp, likedBy),
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF454545), size: 18),
                      const SizedBox(width: 4),
                      Text(viewCount.toString(), style: const TextStyle(color: Color(0xFF454545), fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      const Icon(Icons.favorite_rounded, color: Color(0xFFD32F2F), size: 18),
                      const SizedBox(width: 4),
                      Text(likeCount.toString(), style: const TextStyle(color: Color(0xFF454545), fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              )
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (currentUserId != null) {
                    HapticFeedback.lightImpact();
                    await _watchlistService.toggleBroadcastLike(docId, currentUserId, isLiked);
                  }
                },
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? const Color(0xFFD32F2F) : const Color(0xFF111111),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        likeCount.toString(),
                        style: TextStyle(
                          color: isLiked ? const Color(0xFFD32F2F) : const Color(0xFF454545),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(width: 16),
            
            // Comments Icon
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
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  children: [
                    const Icon(Icons.mode_comment_outlined, color: Color(0xFF454545), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      (docData['commentCount'] ?? 0).toString(),
                      style: const TextStyle(color: Color(0xFF454545), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        isOwner
            ? IconButton(
                onPressed: () => _confirmBroadcastDeletion(docId),
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF454545), size: 20),
                splashRadius: 20,
              )
            : IconButton(
                onPressed: () => _showReportDialog(docId),
                icon: const Icon(Icons.flag_outlined, color: Color(0xFF454545), size: 20),
                splashRadius: 20,
              ),
      ],
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
      backgroundColor: const Color(0xFFF4F4EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4EC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111111), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              "COMMUNITY'S CHOICE",
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontFamily: 'Impact',
              ),
            ),
            SizedBox(height: 2),
            Text(
              "THE CINECAST WIRE",
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF111111), size: 24),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFF111111),
            height: 1.5,
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
                  Icon(Icons.podcasts_rounded, color: Color(0xFF888882), size: 48),
                  SizedBox(height: 12),
                  Text(
                    "COMMUNITY FEED IS EMPTY",
                    style: TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, fontFamily: 'Impact'),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Be the first to transmit a recommendation to the community!",
                    style: TextStyle(color: Color(0xFF454545), fontSize: 10),
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
              final String type = data['type'] ?? 'movie';

              Widget cardChild;

              // ── Playlist broadcast card ──
              if (type == 'playlist') {
                cardChild = _buildPlaylistFeedCard(
                  context: context,
                  data: data,
                  docId: docId,
                  isOwner: isOwner,
                  currentUserId: currentUserId,
                );
              }

              // ── News broadcast card ──
              else if (type == 'news_broadcast') {
                cardChild = _buildNewsFeedCard(
                  context: context,
                  data: data,
                  docId: docId,
                  isOwner: isOwner,
                  currentUserId: currentUserId,
                );
              }

              // ── Standard movie/song broadcast card ──
              else {
                final movie = MovieModel.fromJson(data);
                final Color rankColor = ArchiveRank.getColor(movie.senderRankCount ?? 0);
                final String rankName = ArchiveRank.getTitle(movie.senderRankCount ?? 0);
                final String reason = movie.broadcastReason ?? 'No reason provided.';

                final Timestamp? timestamp = data['timestamp'] as Timestamp?;
                final String timeAgo = _formatTimeAgo(timestamp);

                cardChild = Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Avatar, Name, Rank, Time
                    GestureDetector(
                      onTap: () {
                        final sid = movie.senderId;
                        if (sid != null && sid.isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: sid)));
                        }
                      },
                      child: Row(
                        children: [
                          // Avatar Initial
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
                              (movie.broadcastSender != null && movie.broadcastSender!.isNotEmpty)
                                  ? movie.broadcastSender![0].toUpperCase()
                                  : "A",
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
                                    (movie.broadcastSender ?? "ANONYMOUS").toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF111111),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Impact',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Time Ago
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
                              // Rank Badge
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
                    
                    // Media Preview Card WITH Review inside
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4EC),
                          border: Border.all(color: const Color(0xFF111111), width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Poster on the left
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                movie.posterPath.replaceAll('image.tmdb.org', 'images.tmdb.org'),
                                width: 80,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  width: 80, height: 120, color: const Color(0xFF111111)
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Details & Review on the right
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movie.title.toUpperCase(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF111111),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Impact',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${movie.releaseDate.contains('-') ? movie.releaseDate.split('-').first : movie.releaseDate}${movie.director != null && movie.director!.isNotEmpty ? '  ·  DIR: ${movie.director!.toUpperCase()}' : ''}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF888882),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // The Review (Reason)
                                  GestureDetector(
                                    onTap: () => _showFullTransmission(movie, reason, rankColor),
                                    child: Container(
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
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF454545),
                                                fontSize: 12,
                                                height: 1.4,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Action Bar
                    _buildPostFooter(docId, isOwner, timestamp, data, currentUserId),
                    
                    // Divider
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Divider(color: Color(0xFFE0E0DB), thickness: 1.5),
                    ),
                  ],
                ),
              );
              } // Close the else block

              return _buildVisibilityWrapper(docId, cardChild);
            },
          );
        },
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: _showBroadcastCreationSheet,
        backgroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: Color(0xFF111111), width: 2),
        ),
        child: const Icon(Icons.podcasts_rounded, color: Color(0xFFF4F4EC)),
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

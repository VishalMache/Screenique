import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/movie_model.dart';
import 'services/watchlist_service.dart';
import 'services/movie_service.dart';
import 'movie_details_screen.dart';

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
  
  List<MovieModel> _searchResults = [];
  bool _isSearching = false;
  bool _isBroadcasting = false;
  MovieModel? _selectedMovieForBroadcast;

  @override
  void dispose() {
    _broadcastSearchController.dispose();
    _reasonController.dispose();
    super.dispose();
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
              final movie = MovieModel.fromJson(data);
              final bool isOwner = currentUserId == data['senderId'];
              final String docId = doc.id;
              
              final Color rankColor = ArchiveRank.getColor(movie.senderRankCount ?? 0);
              final String rankName = ArchiveRank.getTitle(movie.senderRankCount ?? 0);
              final String reason = movie.broadcastReason ?? 'No reason provided.';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4EC),
                  border: Border.all(color: const Color(0xFF111111), width: 2.0),
                  boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Poster on Left
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)),
                        ),
                        child: Container(
                          width: 100,
                          decoration: BoxDecoration(
                            border: const Border(right: BorderSide(color: Color(0xFF111111), width: 2.0)),
                            image: DecorationImage(
                              image: NetworkImage(
                                movie.posterPath.replaceAll('image.tmdb.org', 'images.tmdb.org'),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      
                      // Details on Right
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Rank Verified Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: rankColor.withOpacity(0.15),
                                  border: Border.all(color: rankColor, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_user_rounded, color: rankColor, size: 8),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        "${movie.broadcastSender ?? "ANONYMOUS"}  •  $rankName".toUpperCase(),
                                        style: TextStyle(color: rankColor, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Movie Title
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)),
                                ),
                                child: Text(
                                  movie.title.toUpperCase(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF111111),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Impact',
                                    letterSpacing: 0.5,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              
                              // Quote Reason
                              GestureDetector(
                                onTap: () => _showFullTransmission(movie, reason, rankColor),
                                child: RichText(
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    style: const TextStyle(color: Color(0xFF454545), fontSize: 10.5, height: 1.35, fontStyle: FontStyle.italic, fontFamily: 'serif'),
                                    children: [
                                      TextSpan(text: "\"$reason\""),
                                      if (reason.length > 70)
                                        const TextSpan(text: " more..", style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold, fontStyle: FontStyle.normal)),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(height: 12),
                              
                              // Actions Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Real-time Like Trigger
                                  StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('community_recs')
                                        .doc(docId)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const SizedBox(height: 20, width: 20);
                                      }
                                      final docData = snapshot.data!.data() as Map<String, dynamic>?;
                                      final List likes = docData?['likes'] ?? [];
                                      final bool isLiked = likes.contains(currentUserId);
                                      
                                      return GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          _watchlistService.toggleBroadcastLike(docId, currentUserId);
                                        },
                                        child: Container(
                                          color: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                                color: isLiked ? const Color(0xFFD32F2F) : const Color(0xFF111111),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                likes.length.toString(),
                                                style: TextStyle(
                                                  color: isLiked ? const Color(0xFF111111) : const Color(0xFF454545),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  // Delete / Report Button
                                  isOwner
                                      ? IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _confirmBroadcastDeletion(docId),
                                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF111111), size: 18),
                                        )
                                      : IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _showReportDialog(docId),
                                          icon: const Icon(Icons.flag_outlined, color: Color(0xFF111111), size: 18),
                                        ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      
      // Floating Action Button to Broadcast
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
}

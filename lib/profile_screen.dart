import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/watchlist_service.dart';
import '../../models/movie_model.dart';
import 'follow_list_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color bgColor = Color(0xFFF5F3EB);
  static const Color textColor = Color(0xFF111111);
  static const Color redAccent = Color(0xFFD32F2F);
  
  int _selectedTab = 0; // 0: Spotlight, 1: Reviews

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: Text("Authentication required.")),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              "MY PROFILE",
              style: TextStyle(
                letterSpacing: 4, 
                fontSize: 14, 
                fontWeight: FontWeight.w900, 
                color: textColor,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              "A CINEPHILE'S SPACE",
              style: TextStyle(
                fontSize: 9, 
                color: redAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 4),
            Container(width: 30, height: 2, color: redAccent),
          ],
        ),
        toolbarHeight: 80,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('movies')
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          
          final watchedDocs = docs.where((d) => d['status'] == 'watched').toList();
          final int movieCount = watchedDocs.where((d) => (d.data() as Map)['isTvShow'] != true).length;
          final int seriesCount = watchedDocs.where((d) => (d.data() as Map)['isTvShow'] == true).length;
          final int totalWatched = movieCount + seriesCount;

          final reviewDocs = watchedDocs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['personalNote'] != null && data['personalNote'].toString().trim().isNotEmpty;
          }).toList();

          // Sort watched docs by timestamp descending for Recent Activity
          watchedDocs.sort((a, b) {
            final tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (tA == null && tB == null) return 0;
            if (tA == null) return 1;
            if (tB == null) return -1;
            return tB.compareTo(tA);
          });
          final recentDocs = watchedDocs.take(5).toList();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 4),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                  builder: (context, userSnapshot) {
                    final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                    final username = userData?['username'] ?? '';
                    final followers = userData?['followersCount'] ?? 0;
                    final following = userData?['followingCount'] ?? 0;
                    
                    return Column(
                      children: [
                        _buildHeroHeader(user, username, totalWatched),
                        const SizedBox(height: 16),
                        _buildStatsBar(movieCount, seriesCount),
                        const SizedBox(height: 16),
                        _buildFollowersRow(uid, followers, following),
                        const SizedBox(height: 16),
                        _buildCustomTabBar(),
                        const SizedBox(height: 12),
                        
                        // Tab Content
                        if (_selectedTab == 0) _buildSpotlightTab(uid),
                        if (_selectedTab == 1) _buildReviewsTab(reviewDocs),
                        
                        const SizedBox(height: 24),
                        _buildProfileCompleteness(userData),
                        const SizedBox(height: 20),
                        if (recentDocs.isNotEmpty) _buildRecentActivity(recentDocs),
                        const SizedBox(height: 40),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroHeader(User? user, String username, int totalWatched) {
    final String photoUrl = user?.photoURL ??
        'https://ui-avatars.com/api/?name=${user?.email ?? "User"}&background=111111&color=f4f4ec';

    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: textColor, width: 2),
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: Colors.grey[300],
                backgroundImage: NetworkImage(photoUrl),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.displayName ?? "Cinema Buff",
              style: const TextStyle(
                color: textColor, 
                fontSize: 22, 
                fontWeight: FontWeight.bold, 
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "@$username",
              style: TextStyle(
                color: textColor.withOpacity(0.6), 
                fontSize: 12, 
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _buildRankBadge(totalWatched),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              icon: const Icon(Icons.edit_outlined, size: 14, color: textColor),
              label: const Text("Edit Profile", style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: textColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRankBadge(int count) {
    final String title = ArchiveRank.getTitle(count);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEAEA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, color: redAccent, size: 12),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              color: redAccent, 
              fontSize: 9, 
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter'
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(int movieCount, int seriesCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(Icons.movie_creation_outlined, "Films Watched", movieCount.toString()),
          Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.2)),
          _statItem(Icons.tv_rounded, "Series Watched", seriesCount.toString()),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: textColor),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
      ],
    );
  }

  Widget _buildFollowersRow(String uid, int followers, int following) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFollowCount("Followers", followers, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(uid: uid, listType: 'followers')));
        }),
        const SizedBox(width: 24),
        Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.3)),
        const SizedBox(width: 24),
        _buildFollowCount("Following", following, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(uid: uid, listType: 'following')));
        }),
      ],
    );
  }

  Widget _buildFollowCount(String label, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTabItem("Spotlight", 0),
            _buildTabItem("Reviews", 1),
          ],
        ),
        Container(
          height: 1,
          width: double.infinity,
          color: Colors.grey.withOpacity(0.2),
          margin: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ],
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? redAccent : textColor.withOpacity(0.5),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: 80,
            color: isSelected ? redAccent : Colors.transparent,
          )
        ],
      ),
    );
  }

  Widget _buildSpotlightTab(String uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Icon(Icons.campaign_rounded, size: 18, color: textColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Spotlight", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter')),
                    Text("Movies that define your cinematic taste", style: TextStyle(color: Colors.black54, fontSize: 10, fontFamily: 'Inter')),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showEditSpotlight(context, uid),
                icon: const Icon(Icons.edit_square, color: textColor, size: 16),
              )
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('top_five').snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return _buildEmptySpotlight();

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 24),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final movie = MovieModel.fromJson(docs[index].data() as Map<String, dynamic>);
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              movie.posterPath, 
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          movie.releaseDate.split('-').first,
                          style: const TextStyle(color: Colors.black54, fontSize: 9, fontFamily: 'Inter', fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySpotlight() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: const Center(
        child: Text("NO MEDIA PINNED", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
      ),
    );
  }

  Widget _buildReviewsTab(List<DocumentSnapshot> reviewDocs) {
    if (reviewDocs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40.0),
        child: Center(
          child: Text("No reviews yet. Add a personal note to a movie you've watched!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: reviewDocs.length,
      itemBuilder: (context, index) {
        final data = reviewDocs[index].data() as Map<String, dynamic>;
        final movie = MovieModel.fromJson(data);
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(movie.posterPath, width: 50, height: 75, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 50, height: 75, color: Colors.grey)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(movie.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Inter', color: textColor)),
                    const SizedBox(height: 4),
                    Text(
                      "\"${movie.personalNote}\"",
                      style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11, fontStyle: FontStyle.italic, fontFamily: 'Georgia'),
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

  Widget _buildProfileCompleteness(Map<String, dynamic>? userData) {
    int score = 0;
    if (userData != null) {
      if ((userData['name'] ?? '').toString().isNotEmpty) score++;
      if ((userData['username'] ?? '').toString().isNotEmpty) score++;
      if ((userData['bio'] ?? '').toString().length > 10) score++;
      if ((userData['followersCount'] ?? 0) > 0) score++;
      if ((userData['followingCount'] ?? 0) > 0) score++;
    }
    final double progress = score / 5.0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes_rounded, color: redAccent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Profile Completeness", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter')),
                    Text(
                      progress == 1.0 ? "Your profile looks great!" : "Complete your profile to get a better experience", 
                      style: const TextStyle(color: Colors.black54, fontSize: 10, fontFamily: 'Inter')
                    ),
                  ],
                ),
              ),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(color: redAccent, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.withOpacity(0.2),
              color: redAccent,
              minHeight: 8,
            ),
          ),
          if (progress == 1.0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEAEA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.verified, color: redAccent, size: 16),
                  SizedBox(width: 8),
                  Text("Keep sharing your love for cinema.", style: TextStyle(color: redAccent, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<DocumentSnapshot> recentDocs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: const [
              Icon(Icons.show_chart_rounded, size: 18, color: textColor),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Recent Activity", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter')),
                    Text("Your latest updates on Screenique", style: TextStyle(color: Colors.black54, fontSize: 10, fontFamily: 'Inter')),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 24),
            itemCount: recentDocs.length,
            itemBuilder: (context, index) {
              final data = recentDocs[index].data() as Map<String, dynamic>;
              final movie = MovieModel.fromJson(data);
              
              String timeAgo = "recently";
              if (data['timestamp'] != null) {
                final diff = DateTime.now().difference((data['timestamp'] as Timestamp).toDate());
                if (diff.inDays > 0) timeAgo = "${diff.inDays}d ago";
                else if (diff.inHours > 0) timeAgo = "${diff.inHours}h ago";
                else timeAgo = "just now";
              }

              return Container(
                width: 90,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          movie.posterPath, 
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Watched · $timeAgo",
                      style: const TextStyle(color: Colors.black54, fontSize: 9, fontFamily: 'Inter', fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditSpotlight(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Edit Spotlight", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter')),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('top_five').snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  return ListView.builder(
                    itemCount: docs.length,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemBuilder: (context, index) {
                      final movie = MovieModel.fromJson(docs[index].data() as Map<String, dynamic>);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4), 
                          child: Image.network(
                            movie.posterPath, 
                            width: 40, 
                            height: 60, 
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(width: 40, height: 60, color: Colors.grey),
                          )
                        ),
                        title: Text(movie.title, style: const TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                        subtitle: Text(movie.isTvShow ? "Series" : "Film", style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'Inter')),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: redAccent, size: 20),
                          onPressed: () => WatchlistService().unpinFromTopFive(movie.id),
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
    );
  }
}
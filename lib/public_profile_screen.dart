import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'models/movie_model.dart';
import 'movie_details_screen.dart';
import 'follow_list_screen.dart';
import 'services/follow_service.dart';

class PublicProfileScreen extends StatefulWidget {
  final String uid;

  const PublicProfileScreen({super.key, required this.uid});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  static const Color noirCrimson = Color(0xFF111111);
  static const Color seriesBlue = Color(0xFF111111);
  final FollowService _followService = FollowService();

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = FirebaseAuth.instance.currentUser?.uid == widget.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4EC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111111), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "ARCHIVE DOSSIER",
          style: TextStyle(
              letterSpacing: 4,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111)),
        ),
      ),
      // Outer stream: only user data (profile info). Does NOT include follow status.
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF111111)));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          if (userData == null) {
            return const Center(child: Text("Dossier not found.", style: TextStyle(fontWeight: FontWeight.bold)));
          }

          final bool isPublic = userData['isPublic'] ?? true;
          final String name = userData['name'] ?? 'Unknown';
          final String username = userData['username'] ?? '';
          final String bio = userData['bio'] ?? 'A lover of cinema.';
          final int followers = userData['followersCount'] ?? 0;
          final int following = userData['followingCount'] ?? 0;
          final String photoUrl = 'https://ui-avatars.com/api/?name=${name}&background=111111&color=f4f4ec';

          // Inner stream: movies (also unrelated to follow status)
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.uid)
                .collection('movies')
                .snapshots(),
            builder: (context, moviesSnapshot) {
              final docs = moviesSnapshot.data?.docs ?? [];
              final int movieCount = docs.where((d) => d['status'] == 'watched' && (d.data() as Map)['isTvShow'] != true).length;
              final int seriesCount = docs.where((d) => d['status'] == 'watched' && (d.data() as Map)['isTvShow'] == true).length;
              final int totalWatched = movieCount + seriesCount;

              // FollowStatusBuilder is isolated — only the button rebuilds on status change.
              return _FollowStatusWrapper(
                followService: _followService,
                targetUid: widget.uid,
                builder: (followStatus) {
                  // Private + not following → show locked state
                  if (!isPublic && !isCurrentUser && followStatus != FollowStatus.following) {
                    return _buildPrivateState(userData, followStatus, isPublic);
                  }

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 120),
                        _buildProfileHeader(context, name, username, bio, photoUrl, followers, following, totalWatched, followStatus, isPublic, isCurrentUser),
                        const SizedBox(height: 40),
                        _buildStatSection(movieCount, seriesCount, totalWatched),
                        const SizedBox(height: 40),
                        _buildSpotlightSection(widget.uid),
                        const SizedBox(height: 80),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPrivateState(Map<String, dynamic> userData, FollowStatus followStatus, bool isPublic) {
    final String name = userData['name'] ?? 'Unknown';
    final String photoUrl = 'https://ui-avatars.com/api/?name=${name}&background=111111&color=f4f4ec';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: noirCrimson,
            backgroundImage: NetworkImage(photoUrl),
          ),
          const SizedBox(height: 24),
          Text(
            name.toUpperCase(),
            style: const TextStyle(
                color: Color(0xFF111111), fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'Impact'),
          ),
          const SizedBox(height: 16),
          // Isolated follow button widget — only this rebuilds on status change
          _IsolatedFollowButton(
            followService: _followService,
            targetUid: widget.uid,
            isPublic: isPublic,
            followStatus: followStatus,
          ),
          const SizedBox(height: 24),
          const Icon(Icons.lock_outline_rounded, size: 40, color: noirCrimson),
          const SizedBox(height: 12),
          const Text(
            "THIS DOSSIER IS CLASSIFIED",
            style: TextStyle(
                color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, String name, String username, String bio, String photoUrl, int followers, int following, int watchedCount, FollowStatus followStatus, bool isPublic, bool isCurrentUser) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: noirCrimson, width: 2),
          ),
          child: CircleAvatar(
            radius: 55,
            backgroundColor: const Color(0xFFF4F4EC),
            backgroundImage: NetworkImage(photoUrl),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name.toUpperCase(),
          style: const TextStyle(
              color: Color(0xFF111111), fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0, fontFamily: 'Impact', height: 1.0),
        ),
        if (username.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            "@$username",
            style: const TextStyle(
                color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            bio,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFollowCount("FOLLOWERS", followers, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(uid: widget.uid, listType: 'followers')));
            }),
            const SizedBox(width: 24),
            _buildFollowCount("FOLLOWING", following, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(uid: widget.uid, listType: 'following')));
            }),
          ],
        ),
        if (!isCurrentUser) ...[
          const SizedBox(height: 16),
          // ✅ Isolated follow button — rebuilds independently, zero page flicker
          _IsolatedFollowButton(
            followService: _followService,
            targetUid: widget.uid,
            isPublic: isPublic,
            followStatus: followStatus,
          ),
        ],
        const SizedBox(height: 16),
        _buildRankBadge(watchedCount),
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
            style: const TextStyle(
                color: Color(0xFF111111), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
                color: Color(0xFF111111), fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatSection(int movieCount, int seriesCount, int totalWatched) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF111111), width: 2),
        boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem("FILMS", movieCount.toString(), noirCrimson),
          Container(width: 2, height: 30, color: const Color(0xFF111111)),
          _statItem("SERIES", seriesCount.toString(), seriesBlue),
          Container(width: 2, height: 30, color: const Color(0xFF111111)),
          _statItem("RANK", ArchiveRank.getTitle(totalWatched).split(' ').last, const Color(0xFF111111)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color accent) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: accent, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF111111), fontSize: 8, letterSpacing: 1, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSpotlightSection(String profileUid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text("DIRECTOR'S SPOTLIGHT",
              style: TextStyle(
                  color: Color(0xFF111111),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  fontSize: 10)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(profileUid)
                .collection('top_five')
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return _buildEmptySpotlight();

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final movie = MovieModel.fromJson(data);
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MovieDetailsScreen(movie: movie)
                      ));
                    },
                    child: Container(
                      width: 105,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: noirCrimson, width: 2),
                        boxShadow: const [BoxShadow(color: noirCrimson, offset: Offset(2, 2))],
                        image: DecorationImage(
                          image: CachedNetworkImageProvider('https://image.tmdb.org/t/p/w500${movie.posterPath}'),
                          fit: BoxFit.cover,
                        ),
                      ),
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        border: Border.all(color: noirCrimson, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.movie_creation_outlined, color: noirCrimson, size: 30),
          SizedBox(height: 10),
          Text(
            "NO FILMS IN SPOTLIGHT YET.",
            style: TextStyle(color: noirCrimson, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int count) {
    final String title = ArchiveRank.getTitle(count);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: noirCrimson,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, color: Color(0xFFF4F4EC), size: 14),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
                color: Color(0xFFF4F4EC),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wrapper that provides follow status via stream to its builder.
// Keeps the stream isolated so only the button rebuilds on status change.
// ─────────────────────────────────────────────────────────────────────────────
class _FollowStatusWrapper extends StatelessWidget {
  final FollowService followService;
  final String targetUid;
  final Widget Function(FollowStatus) builder;

  const _FollowStatusWrapper({
    required this.followService,
    required this.targetUid,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FollowStatus>(
      stream: followService.streamStatus(targetUid),
      builder: (context, snapshot) {
        final status = snapshot.data ?? FollowStatus.none;
        return builder(status);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Isolated follow button — this is the ONLY widget that rebuilds on tap.
// ─────────────────────────────────────────────────────────────────────────────
class _IsolatedFollowButton extends StatelessWidget {
  final FollowService followService;
  final String targetUid;
  final bool isPublic;
  final FollowStatus followStatus;

  const _IsolatedFollowButton({
    required this.followService,
    required this.targetUid,
    required this.isPublic,
    required this.followStatus,
  });

  @override
  Widget build(BuildContext context) {
    String text = "FOLLOW";
    Color bgColor = const Color(0xFF111111);
    Color textColor = const Color(0xFFF4F4EC);

    if (followStatus == FollowStatus.following) {
      text = "FOLLOWING";
      bgColor = const Color(0xFFF4F4EC);
      textColor = const Color(0xFF111111);
    } else if (followStatus == FollowStatus.requested) {
      text = "REQUESTED";
      bgColor = const Color(0xFFF4F4EC);
      textColor = const Color(0xFF111111);
    }

    return GestureDetector(
      onTap: () {
        if (followStatus == FollowStatus.none) {
          followService.followUser(targetUid, isPublic);
        } else if (followStatus == FollowStatus.requested || followStatus == FollowStatus.following) {
          followService.unfollowUser(targetUid);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: const Color(0xFF111111), width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            text,
            key: ValueKey(text),
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontFamily: 'Impact',
            ),
          ),
        ),
      ),
    );
  }
}





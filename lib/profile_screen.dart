import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/watchlist_service.dart';
import '../../models/movie_model.dart';
import 'follow_list_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color noirCrimson = Color(0xFF111111);
  static const Color seriesBlue = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F4EC),
        body: Center(child: Text("Authentication required.")),
      );
    }

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
          "DIRECTOR'S DOSSIER",
          style: TextStyle(
              letterSpacing: 4,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('movies')
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          
          final int movieCount = docs.where((d) => d['status'] == 'watched' && (d.data() as Map)['isTvShow'] != true).length;
          final int seriesCount = docs.where((d) => d['status'] == 'watched' && (d.data() as Map)['isTvShow'] == true).length;
          final int totalWatched = movieCount + seriesCount;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 140),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                  builder: (context, userSnapshot) {
                    final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                    final username = userData?['username'] ?? '';
                    final followers = userData?['followersCount'] ?? 0;
                    final following = userData?['followingCount'] ?? 0;
                    return _buildProfileHeader(context, uid, user, username, followers, following, totalWatched);
                  },
                ),
                const SizedBox(height: 40),
                
                _buildStatSection(movieCount, seriesCount, totalWatched),
                const SizedBox(height: 40),

                _buildSpotlightSection(context, uid),

                const SizedBox(height: 40),
                _buildArchivalProgress(uid),
                const SizedBox(height: 40),

                _buildMenuSection(context, user),
                
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, String uid, User? user, String username, int followers, int following, int watchedCount) {
    final String photoUrl = user?.photoURL ??
        'https://ui-avatars.com/api/?name=${user?.email ?? "User"}&background=111111&color=f4f4ec';

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
          (user?.displayName ?? user?.email?.split('@')[0] ?? "Cinema Buff").toUpperCase(),
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFollowCount("FOLLOWERS", followers, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(uid: uid, listType: 'followers')));
            }),
            const SizedBox(width: 24),
            _buildFollowCount("FOLLOWING", following, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(uid: uid, listType: 'following')));
            }),
          ],
        ),
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

  Widget _buildSpotlightSection(BuildContext context, String? uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("DIRECTOR'S SPOTLIGHT",
                  style: TextStyle(
                      color: Color(0xFF111111),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      fontSize: 10)),
              IconButton(
                onPressed: () => _showEditSpotlight(context, uid!),
                icon: const Icon(Icons.tune_rounded, color: Color(0xFF111111), size: 18),
              )
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
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
                  return Stack(
                    children: [
                      Container(
                        width: 105,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: const Color(0xFF111111), width: 2),
                          boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Image.network(
                            movie.posterPath, 
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(color: const Color(0xFF111111)),
                          ),
                        ),
                      ),
                      if (movie.isTvShow)
                        Positioned(
                          top: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(2), border: Border.all(color: const Color(0xFFF4F4EC))),
                            child: const Icon(Icons.tv, color: Color(0xFFF4F4EC), size: 8),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArchivalProgress(String? uid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ARCHIVAL STABILITY", style: TextStyle(color: Color(0xFF111111), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF111111), width: 2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const LinearProgressIndicator(
              value: 0.85, 
              backgroundColor: Color(0xFFF4F4EC),
              color: noirCrimson,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, User? user) {
    return Column(
      children: [
        _buildMenuTile(Icons.edit_document, "REVISE DISPLAY NAME", () => _showEditNameDialog(context, user)),
        _buildMenuTile(Icons.restart_alt_rounded, "RESET MEDIA JOURNEY", () => _showResetJourneyDialog(context), isDestructive: true),
        _buildMenuTile(Icons.power_settings_new_rounded, "TERMINATE SESSION", () => _showSignOutDialog(context), isDestructive: true),
      ],
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 4),
      leading: Icon(icon, color: isDestructive ? noirCrimson : const Color(0xFF111111), size: 20),
      title: Text(title,
          style: TextStyle(
              color: isDestructive ? noirCrimson : const Color(0xFF111111),
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF111111), size: 12),
    );
  }

  // --- DIALOGS ---

  void _showEditNameDialog(BuildContext context, User? user) {
    final controller = TextEditingController(text: user?.displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF4F4EC),
        shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFF111111), width: 2)),
        title: const Text("Archive Authority", style: TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Color(0xFF111111)),
          decoration: const InputDecoration(
            hintText: "Enter your handle",
            hintStyle: TextStyle(color: Color(0xFF454545)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: noirCrimson, width: 2)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: noirCrimson, width: 2)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Color(0xFF111111)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: noirCrimson, foregroundColor: const Color(0xFFF4F4EC)),
            onPressed: () async {
              await WatchlistService().updateDisplayName(controller.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
          color: Color(0xFFF4F4EC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
          border: Border(top: BorderSide(color: Color(0xFF111111), width: 2)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("REVISE SPOTLIGHT", style: TextStyle(color: noirCrimson, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
                        leading: Container(
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFF111111), width: 1)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2), 
                            child: Image.network(
                              movie.posterPath, 
                              width: 40, 
                              height: 60, 
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(width: 40, height: 60, color: const Color(0xFF111111)),
                            )
                          ),
                        ),
                        title: Text(movie.title.toUpperCase(), style: const TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.bold)),
                        subtitle: Text(movie.isTvShow ? "SERIES" : "FILM", style: TextStyle(color: movie.isTvShow ? const Color(0xFF111111) : const Color(0xFF454545), fontSize: 8)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: noirCrimson, size: 20),
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

  void _showResetJourneyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF4F4EC),
        shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFF111111), width: 2)),
        title: const Text("PURGE ALL DATA?", style: TextStyle(color: noirCrimson, fontWeight: FontWeight.bold)),
        content: const Text("This will wipe your films, series, and spotlight entries. This cannot be undone.", 
          style: TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Color(0xFF111111)))),
          TextButton(
            onPressed: () async {
              await WatchlistService().resetCinemaJourney();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("TERMINATE DATA", style: TextStyle(color: noirCrimson)),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF4F4EC),
        shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFF111111), width: 2)),
        title: const Text("Sign Out", style: TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.bold)),
        content: const Text("Terminate the current session?", style: TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Color(0xFF111111)))),
          TextButton(
            onPressed: () {
              AuthService().signOut();
              Navigator.pop(context);
            },
            child: const Text("SIGN OUT", style: TextStyle(color: noirCrimson)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySpotlight() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF111111), width: 2),
        boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))],
      ),
      child: const Center(
        child: Text("NO MEDIA PINNED", style: TextStyle(color: Color(0xFF111111), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // UPDATED: Now accepts 'count' to use ArchiveRank logic
  Widget _buildRankBadge(int count) {
    final String title = ArchiveRank.getTitle(count);
    final Color color = const Color(0xFF111111);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, color: color, size: 12),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color, 
              fontSize: 9, 
              letterSpacing: 2, 
              fontWeight: FontWeight.bold
            ),
          ),
        ],
      ),
    );
  }
}
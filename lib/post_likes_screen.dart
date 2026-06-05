import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'public_profile_screen.dart';

class PostLikesScreen extends StatelessWidget {
  final List<dynamic> likedByUids;

  const PostLikesScreen({super.key, required this.likedByUids});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111111), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "LIKED BY",
          style: TextStyle(
              letterSpacing: 4,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111)),
        ),
      ),
      body: likedByUids.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.favorite_border_rounded, color: Color(0xFF888882), size: 48),
                  SizedBox(height: 12),
                  Text(
                    "NO LIKES YET",
                    style: TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13, fontFamily: 'Impact'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 16),
              itemCount: likedByUids.length,
              itemBuilder: (context, index) {
                final uid = likedByUids[index] as String;
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const ListTile(
                        leading: CircleAvatar(backgroundColor: Color(0xFF222222)),
                        title: Text("Loading...", style: TextStyle(color: Color(0xFF888882), fontSize: 12)),
                      );
                    }

                    final userData = snapshot.data!.data() as Map<String, dynamic>?;
                    if (userData == null) return const SizedBox.shrink();

                    final String name = userData['name'] ?? 'Unknown';
                    final String username = userData['username'] ?? '';
                    final String photoUrl = 'https://ui-avatars.com/api/?name=${name}&background=111111&color=f4f4ec';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF111111),
                        backgroundImage: NetworkImage(photoUrl),
                      ),
                      title: Text(
                        name.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Impact',
                          letterSpacing: 0.5,
                        ),
                      ),
                      subtitle: username.isNotEmpty
                          ? Text(
                              "@$username",
                              style: const TextStyle(
                                color: Color(0xFF454545),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: uid)),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'public_profile_screen.dart';

class FollowListScreen extends StatelessWidget {
  final String uid;
  final String listType; // 'followers' or 'following'

  const FollowListScreen({super.key, required this.uid, required this.listType});

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          listType.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontFamily: 'Impact',
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(color: const Color(0xFF111111), height: 1.5),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('follows')
            .doc(uid)
            .collection(listType)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF111111)));

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(
                "NO ${listType.toUpperCase()} FOUND.",
                style: const TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final targetUid = docs[index].id;
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(targetUid).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();

                  final data = userSnapshot.data!.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unknown';
                  final username = data['username'] ?? '';
                  final photoUrl = 'https://ui-avatars.com/api/?name=$name&background=111111&color=f4f4ec';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: targetUid)));
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF111111), width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFF4F4EC),
                        backgroundImage: NetworkImage(photoUrl),
                      ),
                    ),
                    title: Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        fontFamily: 'Impact',
                      ),
                    ),
                    subtitle: username.isNotEmpty
                        ? Text("@$username", style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 10, fontWeight: FontWeight.bold))
                        : null,
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF111111), size: 12),
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

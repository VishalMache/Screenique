import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/follow_service.dart';
import 'public_profile_screen.dart';
import 'comments_bottom_sheet.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F4EC),
        body: Center(child: Text("Please sign in.")),
      );
    }

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
        title: const Text(
          "NOTIFICATIONS",
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontFamily: 'Impact',
          ),
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
            .collection('follows')
            .doc(uid)
            .collection('requests')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, requestsSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, notifsSnap) {
              if (requestsSnap.connectionState == ConnectionState.waiting &&
                  notifsSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF111111)));
              }

              final requestDocs = requestsSnap.data?.docs ?? [];
              final notifDocs = notifsSnap.data?.docs ?? [];

              final List<Map<String, dynamic>> allItems = [];

              for (var doc in requestDocs) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                allItems.add({
                  'docId': doc.id,
                  'type': 'follow_request',
                  'timestamp': data['timestamp'] as Timestamp?,
                  ...data,
                });
              }

              for (var doc in notifDocs) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                allItems.add({
                  'docId': doc.id,
                  'type': data['type'] ?? 'unknown',
                  'timestamp': data['timestamp'] as Timestamp?,
                  ...data,
                });
              }

              allItems.sort((a, b) {
                final aTime = a['timestamp'] as Timestamp?;
                final bTime = b['timestamp'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime); // Descending
              });

              if (allItems.isEmpty) {
                return const Center(
                  child: Text(
                    "NO NOTIFICATIONS YET.",
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      fontSize: 12,
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  if (item['type'] == 'follow_request') {
                    return _FollowRequestCard(requesterUid: item['docId']);
                  } else {
                    return _ActivityNotificationCard(item: item);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ActivityNotificationCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ActivityNotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final String senderId = item['senderId'] ?? '';
    final String type = item['type'] ?? '';
    final Timestamp? timestamp = item['timestamp'];
    final bool isRead = item['isRead'] ?? false;
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] ?? 'Someone';
        final photoUrl = 'https://ui-avatars.com/api/?name=$name&background=111111&color=f4f4ec';

        String message = '';
        if (type == 'comment') {
          message = 'commented on your post.';
        } else if (type == 'reply') {
          message = 'replied to your comment.';
        } else {
          message = 'interacted with your post.';
        }

        String timeStr = 'Now';
        if (timestamp != null) {
          final diff = DateTime.now().difference(timestamp.toDate());
          if (diff.inDays > 0) timeStr = "${diff.inDays}d";
          else if (diff.inHours > 0) timeStr = "${diff.inHours}h";
          else if (diff.inMinutes > 0) timeStr = "${diff.inMinutes}m";
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: senderId)));
            },
            child: CircleAvatar(
              radius: 22,
              backgroundImage: NetworkImage(photoUrl),
              backgroundColor: const Color(0xFF111111),
            ),
          ),
          title: RichText(
            text: TextSpan(
              style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontFamily: 'Inter'),
              children: [
                TextSpan(
                  text: name.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                ),
                TextSpan(
                  text: ' $message',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF454545)),
                ),
              ],
            ),
          ),
          subtitle: Text(timeStr, style: const TextStyle(color: Color(0xFF888882), fontSize: 10, fontWeight: FontWeight.bold)),
          trailing: isRead ? null : const Icon(Icons.circle, color: Color(0xFFD32F2F), size: 8),
          onTap: () async {
            // Mark as read
            if (!isRead && item['docId'] != null) {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('notifications')
                    .doc(item['docId'])
                    .update({'isRead': true});
              }
            }

            if (item['postId'] != null) {
              // Fetch post document to get the author id
              final postDoc = await FirebaseFirestore.instance.collection('community_recs').doc(item['postId']).get();
              if (postDoc.exists && context.mounted) {
                final postAuthorId = postDoc.data()?['senderId'] ?? '';
                final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => CommentsBottomSheet(
                    postId: item['postId'],
                    postAuthorId: postAuthorId,
                    currentUserId: currentUserId,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}

class _FollowRequestCard extends StatefulWidget {
  final String requesterUid;
  const _FollowRequestCard({required this.requesterUid});

  @override
  State<_FollowRequestCard> createState() => _FollowRequestCardState();
}

class _FollowRequestCardState extends State<_FollowRequestCard> {
  final FollowService _followService = FollowService();
  bool _isLoading = false;

  Future<void> _handleAccept() async {
    setState(() => _isLoading = true);
    await _followService.acceptRequest(widget.requesterUid);
  }

  Future<void> _handleDecline() async {
    setState(() => _isLoading = true);
    await _followService.declineRequest(widget.requesterUid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(widget.requesterUid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] ?? 'Unknown Viewer';
        final username = data['username'] ?? '';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: widget.requesterUid)));
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF111111),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Color(0xFFF4F4EC),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Impact',
                  ),
                ),
              ),
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
          trailing: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF111111), strokeWidth: 2))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                      onPressed: _handleAccept,
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_rounded, color: Color(0xFFD32F2F)),
                      onPressed: _handleDecline,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

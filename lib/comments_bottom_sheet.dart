import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'services/comment_service.dart';
import 'public_profile_screen.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String postAuthorId;
  final String currentUserId;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.currentUserId,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final CommentService _commentService = CommentService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String? _replyingToCommentId;
  String? _replyingToAuthorId;
  String? _replyingToUsername;

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    _focusNode.unfocus();

    if (_replyingToCommentId != null && _replyingToAuthorId != null) {
      final success = await _commentService.addReply(widget.postId, _replyingToCommentId!, text, _replyingToAuthorId!);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to post reply")));
      }
    } else {
      final success = await _commentService.addComment(widget.postId, text, widget.postAuthorId);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to post comment")));
      }
    }

    setState(() {
      _replyingToCommentId = null;
      _replyingToAuthorId = null;
      _replyingToUsername = null;
    });
  }

  void _setReplyState(String commentId, String authorId, String username) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToAuthorId = authorId;
      _replyingToUsername = username;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToAuthorId = null;
      _replyingToUsername = null;
    });
    _focusNode.unfocus();
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inDays > 0) return "${diff.inDays}d";
    if (diff.inHours > 0) return "${diff.inHours}h";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m";
    return "Now";
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: const Border(top: BorderSide(color: Color(0xFF222222), width: 1)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const Text(
            "COMMENTS",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'Impact',
              letterSpacing: 2,
            ),
          ),
          const Divider(color: Colors.white, thickness: 1.5, height: 24),
          
          // Comments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('community_recs')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
                }

                final comments = snapshot.data!.docs;

                if (comments.isEmpty) {
                  return const Center(
                    child: Text(
                      "No comments yet. Be the first!",
                      style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final commentDoc = comments[index];
                    return _buildCommentNode(commentDoc);
                  },
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 12, 
              bottom: MediaQuery.of(context).viewInsets.bottom + 16
            ),
            decoration: const BoxDecoration(
              color: const Color(0xFF0A0A0A),
              border: const Border(top: BorderSide(color: Colors.white10, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingToCommentId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Replying to @$_replyingToUsername",
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        GestureDetector(
                          onTap: _cancelReply,
                          child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                        )
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF15181E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10, width: 1),
                        ),
                        child: TextField(
                          controller: _commentController,
                          focusNode: _focusNode,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: "Add a comment...",
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _submitComment,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD32F2F),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: const Color(0xFF0A0A0A), size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentNode(DocumentSnapshot commentDoc) {
    final commentData = commentDoc.data() as Map<String, dynamic>;
    final commentId = commentDoc.id;
    final String uid = commentData['uid'];
    final String text = commentData['text'] ?? '';
    final Timestamp? timestamp = commentData['timestamp'];
    final List likes = commentData['likes'] ?? [];
    final bool isLiked = likes.contains(widget.currentUserId);
    final int replyCount = commentData['replyCount'] ?? 0;

    final bool canDelete = widget.currentUserId == uid || widget.currentUserId == widget.postAuthorId;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox.shrink();
        final userData = userSnap.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();

        final name = userData['name'] ?? 'Unknown';
        final username = userData['username'] ?? '';
        final photoUrl = 'https://ui-avatars.com/api/?name=$name&background=222222&color=ffffff';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Comment
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: uid))),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(photoUrl),
                    backgroundColor: const Color(0xFF222222),
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
                            name.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatTime(timestamp),
                            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _setReplyState(commentId, uid, username),
                            child: const Text("Reply", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _commentService.toggleCommentLike(widget.postId, commentId, widget.currentUserId, isLiked);
                            },
                            child: Row(
                              children: [
                                Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 14, color: isLiked ? const Color(0xFFD32F2F) : Colors.white54),
                                if (likes.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text(likes.length.toString(), style: TextStyle(color: isLiked ? const Color(0xFFD32F2F) : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                                ]
                              ],
                            ),
                          ),
                          if (canDelete) ...[
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => _commentService.deleteComment(widget.postId, commentId),
                              child: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white54),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Replies Sub-list
            if (replyCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 42, top: 8),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('community_recs')
                      .doc(widget.postId)
                      .collection('comments')
                      .doc(commentId)
                      .collection('replies')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, replySnap) {
                    if (!replySnap.hasData) return const SizedBox.shrink();
                    final replies = replySnap.data!.docs;
                    return Column(
                      children: replies.map((replyDoc) {
                        return _buildReplyNode(commentId, replyDoc);
                      }).toList(),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildReplyNode(String commentId, DocumentSnapshot replyDoc) {
    final replyData = replyDoc.data() as Map<String, dynamic>;
    final replyId = replyDoc.id;
    final String uid = replyData['uid'];
    final String text = replyData['text'] ?? '';
    final Timestamp? timestamp = replyData['timestamp'];
    final List likes = replyData['likes'] ?? [];
    final bool isLiked = likes.contains(widget.currentUserId);

    final bool canDelete = widget.currentUserId == uid || widget.currentUserId == widget.postAuthorId;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox.shrink();
        final userData = userSnap.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();

        final name = userData['name'] ?? 'Unknown';
        final username = userData['username'] ?? '';
        final photoUrl = 'https://ui-avatars.com/api/?name=$name&background=222222&color=ffffff';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: uid))),
                child: CircleAvatar(
                  radius: 12,
                  backgroundImage: NetworkImage(photoUrl),
                  backgroundColor: const Color(0xFF222222),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTime(timestamp),
                          style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _setReplyState(commentId, uid, username),
                          child: const Text("Reply", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _commentService.toggleReplyLike(widget.postId, commentId, replyId, widget.currentUserId, isLiked);
                          },
                          child: Row(
                            children: [
                              Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 12, color: isLiked ? const Color(0xFFD32F2F) : Colors.white54),
                              if (likes.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(likes.length.toString(), style: TextStyle(color: isLiked ? const Color(0xFFD32F2F) : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                              ]
                            ],
                          ),
                        ),
                        if (canDelete) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => _commentService.deleteReply(widget.postId, commentId, replyId),
                            child: const Icon(Icons.delete_outline_rounded, size: 12, color: Colors.white54),
                          ),
                        ]
                      ],
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
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> addComment(String postId, String text, String postAuthorId) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return false;

    try {
      final postRef = _firestore.collection('community_recs').doc(postId);
      final commentsRef = postRef.collection('comments').doc();

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;

        final int currentCount = postDoc.data()?['commentCount'] ?? 0;

        transaction.set(commentsRef, {
          'text': text.trim(),
          'uid': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'likes': [],
          'replyCount': 0,
        });

        transaction.update(postRef, {'commentCount': currentCount + 1});
      });

      // Notify post author if not self
      if (user.uid != postAuthorId) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final name = userDoc.data()?['name'] ?? 'Someone';
        
        await _firestore.collection('users').doc(postAuthorId).collection('notifications').add({
          'type': 'comment',
          'postId': postId,
          'senderId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        NotificationService().showNotification(
          title: "New Comment",
          body: "$name commented on your post",
        );
      }
      return true;
    } catch (e) {
      debugPrint("Error adding comment: $e");
      return false;
    }
  }

  Future<bool> addReply(String postId, String commentId, String text, String commentAuthorId) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return false;

    try {
      final commentRef = _firestore.collection('community_recs').doc(postId).collection('comments').doc(commentId);
      final repliesRef = commentRef.collection('replies').doc();

      await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        if (!commentDoc.exists) return;

        final int currentReplyCount = commentDoc.data()?['replyCount'] ?? 0;

        transaction.set(repliesRef, {
          'text': text.trim(),
          'uid': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'likes': [],
        });

        transaction.update(commentRef, {'replyCount': currentReplyCount + 1});
      });

      // Notify comment author if not self
      if (user.uid != commentAuthorId) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final name = userDoc.data()?['name'] ?? 'Someone';
        
        await _firestore.collection('users').doc(commentAuthorId).collection('notifications').add({
          'type': 'reply',
          'postId': postId,
          'commentId': commentId,
          'senderId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        NotificationService().showNotification(
          title: "New Reply",
          body: "$name replied to your comment",
        );
      }
      return true;
    } catch (e) {
      debugPrint("Error adding reply: $e");
      return false;
    }
  }

  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      final postRef = _firestore.collection('community_recs').doc(postId);
      final commentRef = postRef.collection('comments').doc(commentId);

      // We should ideally delete subcollection documents (replies) too, 
      // but Firestore doesn't require it unless we want to save space.
      // Since it's client-side, we'll just delete the parent and decrement count.
      // Wait, we can fetch replies and batch delete them.
      
      final repliesSnap = await commentRef.collection('replies').get();
      
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (postDoc.exists) {
          final int currentCount = postDoc.data()?['commentCount'] ?? 0;
          final int newCount = (currentCount - 1 < 0) ? 0 : currentCount - 1;
          transaction.update(postRef, {'commentCount': newCount});
        }
        
        for (var doc in repliesSnap.docs) {
          transaction.delete(doc.reference);
        }
        
        transaction.delete(commentRef);
      });
      return true;
    } catch (e) {
      debugPrint("Error deleting comment: $e");
      return false;
    }
  }

  Future<bool> deleteReply(String postId, String commentId, String replyId) async {
    try {
      final commentRef = _firestore.collection('community_recs').doc(postId).collection('comments').doc(commentId);
      final replyRef = commentRef.collection('replies').doc(replyId);

      await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        if (commentDoc.exists) {
          final int currentCount = commentDoc.data()?['replyCount'] ?? 0;
          final int newCount = (currentCount - 1 < 0) ? 0 : currentCount - 1;
          transaction.update(commentRef, {'replyCount': newCount});
        }
        transaction.delete(replyRef);
      });
      return true;
    } catch (e) {
      debugPrint("Error deleting reply: $e");
      return false;
    }
  }

  Future<bool> toggleCommentLike(String postId, String commentId, String userId, bool isLiked) async {
    final commentRef = _firestore.collection('community_recs').doc(postId).collection('comments').doc(commentId);
    try {
      if (isLiked) {
        await commentRef.update({'likes': FieldValue.arrayRemove([userId])});
      } else {
        await commentRef.update({'likes': FieldValue.arrayUnion([userId])});
      }
      return true;
    } catch (e) {
      debugPrint("Error toggling comment like: $e");
      return false;
    }
  }

  Future<bool> toggleReplyLike(String postId, String commentId, String replyId, String userId, bool isLiked) async {
    final replyRef = _firestore.collection('community_recs').doc(postId).collection('comments').doc(commentId).collection('replies').doc(replyId);
    try {
      if (isLiked) {
        await replyRef.update({'likes': FieldValue.arrayRemove([userId])});
      } else {
        await replyRef.update({'likes': FieldValue.arrayUnion([userId])});
      }
      return true;
    } catch (e) {
      debugPrint("Error toggling reply like: $e");
      return false;
    }
  }
}

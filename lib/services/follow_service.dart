import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

enum FollowStatus {
  none,
  requested,
  following,
}

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  // Stream the current follow status toward a target user
  Stream<FollowStatus> getFollowStatusStream(String targetUid) {
    final uid = currentUid;
    if (uid == null) return Stream.value(FollowStatus.none);

    // To figure out the status, we check if we are in their "followers" or "requests"
    return _firestore
        .collection('follows')
        .doc(targetUid)
        .snapshots()
        .asyncMap((doc) async {
          // Check following
          final followingDoc = await _firestore
              .collection('follows')
              .doc(targetUid)
              .collection('followers')
              .doc(uid)
              .get();
          if (followingDoc.exists) return FollowStatus.following;

          // Check requests
          final requestDoc = await _firestore
              .collection('follows')
              .doc(targetUid)
              .collection('requests')
              .doc(uid)
              .get();
          if (requestDoc.exists) return FollowStatus.requested;

          return FollowStatus.none;
    });
  }

  // Listen to both follower and request states
  Stream<FollowStatus> streamStatus(String targetUid) {
    final uid = currentUid;
    if (uid == null) return Stream.value(FollowStatus.none);

    final controller = StreamController<FollowStatus>.broadcast();

    void updateStatus() async {
      try {
        final fDoc = await _firestore.collection('follows').doc(targetUid).collection('followers').doc(uid).get();
        if (fDoc.exists) {
          controller.add(FollowStatus.following);
          return;
        }
        final rDoc = await _firestore.collection('follows').doc(targetUid).collection('requests').doc(uid).get();
        if (rDoc.exists) {
          controller.add(FollowStatus.requested);
          return;
        }
        controller.add(FollowStatus.none);
      } catch (e) {
        controller.add(FollowStatus.none);
      }
    }

    final fSub = _firestore.collection('follows').doc(targetUid).collection('followers').doc(uid).snapshots().listen((_) => updateStatus());
    final rSub = _firestore.collection('follows').doc(targetUid).collection('requests').doc(uid).snapshots().listen((_) => updateStatus());

    controller.onCancel = () {
      fSub.cancel();
      rSub.cancel();
    };

    updateStatus();

    return controller.stream;
  }

  Future<void> followUser(String targetUid, bool isPublic) async {
    final uid = currentUid;
    if (uid == null) return;

    final batch = _firestore.batch();
    
    // ALWAYS send a request, regardless of isPublic
    final requestRef = _firestore.collection('follows').doc(targetUid).collection('requests').doc(uid);
    batch.set(requestRef, {'timestamp': FieldValue.serverTimestamp()});

    await batch.commit();
  }

  Future<void> unfollowUser(String targetUid) async {
    final uid = currentUid;
    if (uid == null) return;

    // Check if we are currently following or just requested
    final fDoc = await _firestore.collection('follows').doc(targetUid).collection('followers').doc(uid).get();
    
    final batch = _firestore.batch();
    
    if (fDoc.exists) {
      // Remove follow
      final targetFollowerRef = _firestore.collection('follows').doc(targetUid).collection('followers').doc(uid);
      batch.delete(targetFollowerRef);
      
      final myFollowingRef = _firestore.collection('follows').doc(uid).collection('following').doc(targetUid);
      batch.delete(myFollowingRef);
      
      // Decrement counts
      final targetUserRef = _firestore.collection('users').doc(targetUid);
      batch.update(targetUserRef, {'followersCount': FieldValue.increment(-1)});
      
      final myUserRef = _firestore.collection('users').doc(uid);
      batch.update(myUserRef, {'followingCount': FieldValue.increment(-1)});
    } else {
      // Withdraw request
      final requestRef = _firestore.collection('follows').doc(targetUid).collection('requests').doc(uid);
      batch.delete(requestRef);
    }
    
    await batch.commit();
  }

  Future<void> acceptRequest(String requesterUid) async {
    final uid = currentUid;
    if (uid == null) return;

    final batch = _firestore.batch();

    // 1. Remove request
    final requestRef = _firestore.collection('follows').doc(uid).collection('requests').doc(requesterUid);
    batch.delete(requestRef);

    // 2. Add to followers
    final followerRef = _firestore.collection('follows').doc(uid).collection('followers').doc(requesterUid);
    batch.set(followerRef, {'timestamp': FieldValue.serverTimestamp()});

    // 3. Add to their following
    final followingRef = _firestore.collection('follows').doc(requesterUid).collection('following').doc(uid);
    batch.set(followingRef, {'timestamp': FieldValue.serverTimestamp()});

    // 4. Update counts
    final myUserRef = _firestore.collection('users').doc(uid);
    batch.update(myUserRef, {'followersCount': FieldValue.increment(1)});

    final theirUserRef = _firestore.collection('users').doc(requesterUid);
    batch.update(theirUserRef, {'followingCount': FieldValue.increment(1)});

    await batch.commit();
  }

  Future<void> declineRequest(String requesterUid) async {
    final uid = currentUid;
    if (uid == null) return;

    await _firestore.collection('follows').doc(uid).collection('requests').doc(requesterUid).delete();
  }
}

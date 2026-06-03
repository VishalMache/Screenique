import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/movie_model.dart';
import 'movie_service.dart';

class WatchlistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? getCurrentUser() => _auth.currentUser;

  // ───────────────── PROFILE & RANKING ─────────────────

  Future<int> getWatchedCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('movies')
        .where('status', isEqualTo: 'watched')
        .get();

    return snapshot.docs.length;
  }

  Future<void> updateDisplayName(String newName) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(newName);
    await user.reload();
  }

  Future<void> resetCinemaJourney() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final WriteBatch batch = _firestore.batch();
    final userDoc = _firestore.collection('users').doc(user.uid);

    try {
      final moviesSnapshot = await userDoc.collection('movies').get();
      for (var doc in moviesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      final spotlightSnapshot = await userDoc.collection('top_five').get();
      for (var doc in spotlightSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      await MovieService.clearCache();
      debugPrint("Archive Journey Reset Complete.");
    } catch (e) {
      debugPrint("Reset failed: $e");
      throw "Failed to reset journey.";
    }
  }

  // ───────────────── COMMUNITY HUB LOGIC ─────────────────

  Future<void> broadcastMovie(MovieModel movie, String reason) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final senderName = userDoc.data()?['name'] ?? user.displayName ?? "Anonymous";
    final watchedCount = await getWatchedCount();

    await _firestore.collection('community_recs').add({
      'type': 'movie',
      'movieId': movie.id.toString(),
      'title': movie.title,
      'posterPath': movie.posterPath,
      'senderId': user.uid,
      'senderName': senderName,
      'reason': reason,
      'isTvShow': movie.isTvShow,
      'timestamp': FieldValue.serverTimestamp(),
      'senderRankCount': watchedCount,
      'director': movie.director,
      'likes': [],
    });
  }

  Future<void> broadcastManualSong(String songName, String artistName, String reason) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final senderName = userDoc.data()?['name'] ?? user.displayName ?? "Anonymous";
    final watchedCount = await getWatchedCount();

    await _firestore.collection('community_recs').add({
      'type': 'song',
      'title': songName,
      'artist': artistName,
      'posterPath': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=1000&auto=format&fit=crop',
      'senderId': user.uid,
      'senderName': senderName,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'senderRankCount': watchedCount,
      'likes': [],
    });
  }

  Future<bool> toggleBroadcastLike(String docId, String userId, bool isCurrentlyLiked) async {
    final docRef = _firestore.collection('community_recs').doc(docId);
    try {
      await docRef.update({
        'likes': isCurrentlyLiked
            ? FieldValue.arrayRemove([userId])
            : FieldValue.arrayUnion([userId]),
      });
      return true;
    } catch (e) {
      debugPrint("Error toggling like: $e");
      return false;
    }
  }

  Future<void> deleteBroadcast(String docId) async {
    await _firestore.collection('community_recs').doc(docId).delete();
  }

  // FIXED: Added missing reportBroadcast method
  Future<void> reportBroadcast(String docId, String reason) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('reports').add({
      'broadcastId': docId,
      'reporterId': user.uid,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ───────────────── WATCHLIST CORE ─────────────────

  Future<void> toggleMovieStatus(MovieModel movie, String status) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('movies')
        .doc(movie.id.toString());

    if (status == 'none') {
      await docRef.delete();
      await MovieService.clearCache();
      return;
    }

    final data = movie.toJson();
    data['status'] = status;

    if (status == 'watched') {
      String director = movie.director ?? "UNKNOWN";

      if (director == "UNKNOWN" || director.isEmpty) {
        try {
          final fetched = await MovieService().getDirector(movie.id, movie.isTvShow);
          director = fetched ?? "UNKNOWN"; 
        } catch (_) {
          director = "UNKNOWN";
        }
      }

      data['director'] = director;
      data['watchedAt'] = DateTime.now().toIso8601String();
      data['userRating'] = data['userRating'] ?? 0.0;
    } else {
      data['watchedAt'] = null;
    }

    await docRef.set(data, SetOptions(merge: true));
    await MovieService.clearCache();
  }

  // ───────────────── 🎲 RANDOM PICK (SHAKE) ─────────────────

  Future<MovieModel?> getRandomWatchlistMovie() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // WISE UPDATE: Try Watchlist first, if empty, suggest something from Watched for a re-watch
    var snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('movies')
        .where('status', isEqualTo: 'watchlist')
        .get();

    if (snapshot.docs.isEmpty) {
        snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('movies')
        .where('status', isEqualTo: 'watched')
        .get();
    }

    if (snapshot.docs.isEmpty) return null;

    final randomDoc = snapshot.docs[Random().nextInt(snapshot.docs.length)];
    return MovieModel.fromJson(randomDoc.data());

  }

  // ───────────────── UTILITIES ─────────────────

  Future<void> updateMovieRating(int movieId, double rating) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).collection('movies').doc(movieId.toString()).update({'userRating': rating});
    await MovieService.clearCache();
  }

  Future<void> deleteMovie(int movieId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).collection('movies').doc(movieId.toString()).delete();
    await MovieService.clearCache();
  }

  Future<void> pinToTopFive(MovieModel movie) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _firestore.collection('users').doc(user.uid).collection('top_five');
    final snapshot = await ref.get();
    if (snapshot.docs.length >= 5) throw 'Spotlight is full.';
    await ref.doc(movie.id.toString()).set(movie.toJson());
  }

  Future<void> unpinFromTopFive(int movieId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).collection('top_five').doc(movieId.toString()).delete();
  }

  // ───────────────── PLAYLISTS ─────────────────

  /// Creates a new empty playlist and returns its generated document ID.
  Future<String?> createPlaylist(String name) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final docRef = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('playlists')
        .add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'movieIds': <int>[],
    });

    return docRef.id;
  }

  /// Renames an existing playlist.
  Future<void> renamePlaylist(String playlistId, String newName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('playlists')
        .doc(playlistId)
        .update({'name': newName});
  }

  /// Deletes a playlist document entirely.
  Future<void> deletePlaylist(String playlistId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('playlists')
        .doc(playlistId)
        .delete();
  }

  /// Adds a movie ID to a playlist (no duplicates).
  Future<void> addMovieToPlaylist(String playlistId, int movieId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('playlists')
        .doc(playlistId)
        .update({
      'movieIds': FieldValue.arrayUnion([movieId]),
    });
  }

  /// Removes a movie ID from a playlist.
  Future<void> removeMovieFromPlaylist(String playlistId, int movieId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('playlists')
        .doc(playlistId)
        .update({
      'movieIds': FieldValue.arrayRemove([movieId]),
    });
  }

  /// Broadcasts a playlist to the community hub.
  Future<void> broadcastPlaylist({
    required String playlistName,
    required List<MovieModel> movies,
    required String reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final senderName = userDoc.data()?['name'] ?? user.displayName ?? 'Anonymous';
    final watchedCount = await getWatchedCount();

    // Collect all posters for the playlist detail view
    final List<String> posterPaths = movies
        .map((m) => m.posterPath)
        .where((p) => p.isNotEmpty)
        .toList();

    final List<String> movieTitles = movies.map((m) => m.title).toList();
    final List<int> movieIds = movies.map((m) => m.id).toList();

    await _firestore.collection('community_recs').add({
      'type': 'playlist',
      'playlistName': playlistName,
      'movieIds': movieIds,
      'movieTitles': movieTitles,
      'posterPaths': posterPaths,
      'reason': reason,
      'senderId': user.uid,
      'senderName': senderName,
      'senderRankCount': watchedCount,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': <String>[],
    });
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie_model.dart';

class ExperienceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- SAVE NEW EXPERIENCE ---
  Future<void> addExperience({
    required MovieModel movie,
    required String ticketUrl,
    required String cinema,
    required String note,
    required String people,
    required DateTime customDate,
    required double rating,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('experiences')
        .add({
      'movieId': movie.id,
      'title': movie.title,
      'posterPath': movie.posterPath,
      'ticketImageUrl': ticketUrl,
      // Standardized to 'cinemaName' to match the Ticket UI
      'cinemaName': cinema.isEmpty ? "Cinema Not Specified" : cinema,
      'personalNote': note.isEmpty ? "No notes added." : note,
      'companions': people.isEmpty ? "Watched alone" : people,
      'userRating': rating,
      'timestamp': Timestamp.fromDate(customDate),
    });
  }

  // --- GET REAL-TIME STREAM ---
  Stream<QuerySnapshot> getExperiences() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('experiences')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // --- UPDATE EXISTING ENTRY ---
  Future<void> updateExperience({
    required String docId,
    required String cinema,
    required String note,
    required String people,
    required double rating,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('experiences')
        .doc(docId)
        .update({
      // Standardized to 'cinemaName'
      'cinemaName': cinema,
      'personalNote': note,
      'companions': people,
      'userRating': rating,
    });
  }

  // --- DELETE ENTRY ---
  Future<void> deleteExperience(String docId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('experiences')
        .doc(docId)
        .delete();
  }
}
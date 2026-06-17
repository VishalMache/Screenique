/// Taste DNA Profile Service
/// Reads ALL user data from Firestore and builds a structured "taste profile"
/// string that gets injected into ScreenU's system prompt for hyper-personalized
/// recommendations.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/movie_model.dart';

class TasteProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Builds a complete Taste DNA string from the user's Firestore data.
  /// This string is injected directly into ScreenU's system prompt.
  Future<String> buildTasteDNA(String uid) async {
    try {
      final results = await Future.wait([
        _fetchWatchedMovies(uid),
        _fetchWatchlistMovies(uid),
        _fetchTopFive(uid),
        _fetchExperiences(uid),
        _fetchPlaylists(uid),
      ]);

      final watched = results[0] as List<Map<String, dynamic>>;
      final watchlist = results[1] as List<Map<String, dynamic>>;
      final topFive = results[2] as List<Map<String, dynamic>>;
      final experiences = results[3] as List<Map<String, dynamic>>;
      final playlists = results[4] as List<Map<String, dynamic>>;

      return _compileDNA(
        watched: watched,
        watchlist: watchlist,
        topFive: topFive,
        experiences: experiences,
        playlists: playlists,
      );
    } catch (e) {
      debugPrint('TasteProfileService error: $e');
      return '=== USER TASTE DNA ===\nNew user — no watch history yet.\n===';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWatchedMovies(String uid) async {
    final snapshot = await _firestore
        .collection('users').doc(uid)
        .collection('movies')
        .where('status', isEqualTo: 'watched')
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchWatchlistMovies(String uid) async {
    final snapshot = await _firestore
        .collection('users').doc(uid)
        .collection('movies')
        .where('status', isEqualTo: 'watchlist')
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchTopFive(String uid) async {
    final snapshot = await _firestore
        .collection('users').doc(uid)
        .collection('top_five')
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchExperiences(String uid) async {
    final snapshot = await _firestore
        .collection('users').doc(uid)
        .collection('experiences')
        .orderBy('timestamp', descending: true)
        .limit(20) // Latest 20 experiences
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchPlaylists(String uid) async {
    final snapshot = await _firestore
        .collection('users').doc(uid)
        .collection('playlists')
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  /// Compiles all the raw Firestore data into a structured DNA string.
  String _compileDNA({
    required List<Map<String, dynamic>> watched,
    required List<Map<String, dynamic>> watchlist,
    required List<Map<String, dynamic>> topFive,
    required List<Map<String, dynamic>> experiences,
    required List<Map<String, dynamic>> playlists,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== USER TASTE DNA ===');

    // --- OVERVIEW ---
    final movieCount = watched.where((m) => m['isTvShow'] != true).length;
    final seriesCount = watched.where((m) => m['isTvShow'] == true).length;
    buffer.writeln('WATCHED: ${watched.length} titles ($movieCount movies, $seriesCount series)');

    if (watched.isEmpty) {
      buffer.writeln('New user — no watch history yet. Give popular, well-reviewed recommendations.');
      buffer.writeln('===');
      return buffer.toString();
    }

    // --- GENRE ANALYSIS ---
    final Map<int, int> genreCounts = {};
    for (var m in watched) {
      final List? gIds = m['genreIds'] ?? m['genre_ids'];
      if (gIds != null) {
        for (var id in gIds) {
          if (id is int) genreCounts[id] = (genreCounts[id] ?? 0) + 1;
        }
      }
    }
    if (genreCounts.isNotEmpty) {
      final sortedGenres = genreCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final total = sortedGenres.fold<int>(0, (sum, e) => sum + e.value);
      final topGenres = sortedGenres.take(5).map((e) {
        final name = MovieModel.genreMap[e.key] ?? 'Unknown';
        final pct = ((e.value / total) * 100).round();
        return '$name ($pct%)';
      }).join(', ');
      buffer.writeln('TOP GENRES: $topGenres');
    }

    // --- DIRECTOR ANALYSIS ---
    final Map<String, List<double>> directorData = {};
    for (var m in watched) {
      final dir = m['director'] as String?;
      final rating = (m['userRating'] ?? 0.0).toDouble();
      if (dir != null && dir.isNotEmpty && dir != 'UNKNOWN') {
        directorData.putIfAbsent(dir, () => []).add(rating);
      }
    }
    if (directorData.isNotEmpty) {
      final sortedDirs = directorData.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      final topDirs = sortedDirs.take(5).map((e) {
        final avg = e.value.isEmpty ? 0.0 : e.value.reduce((a, b) => a + b) / e.value.length;
        return '${e.key} (${e.value.length} films, avg ${avg.toStringAsFixed(1)}★)';
      }).join(', ');
      buffer.writeln('FAVORITE DIRECTORS: $topDirs');
    }

    // --- HIGHEST / LOWEST RATED ---
    final ratedMovies = watched.where((m) => (m['userRating'] ?? 0.0) > 0).toList()
      ..sort((a, b) => ((b['userRating'] ?? 0.0) as num).compareTo((a['userRating'] ?? 0.0) as num));
    
    if (ratedMovies.isNotEmpty) {
      final highest = ratedMovies.take(5).map((m) => "${m['title']} (${m['userRating']}★)").join(', ');
      buffer.writeln('HIGHEST RATED: $highest');
      
      final lowest = ratedMovies.reversed.take(3).where((m) => (m['userRating'] ?? 0.0) <= 2.5)
          .map((m) => "${m['title']} (${m['userRating']}★)").join(', ');
      if (lowest.isNotEmpty) buffer.writeln('LOWEST RATED (AVOID SIMILAR): $lowest');
    }

    // --- TOP FIVE / SPOTLIGHT ---
    if (topFive.isNotEmpty) {
      final names = topFive.map((m) => m['title'] ?? 'Unknown').join(', ');
      buffer.writeln('SPOTLIGHT (TOP 5 FAVORITES): $names');
    }

    // --- WATCHLIST (AVOIDANCE) ---
    if (watchlist.isNotEmpty) {
      final names = watchlist.map((m) => m['title'] ?? 'Unknown').join(', ');
      buffer.writeln('WATCHLIST (ALREADY PLANNING TO WATCH — DO NOT RECOMMEND): $names');
    }

    // --- WATCHED TITLES (FULL LIST FOR AVOIDANCE) ---
    final watchedTitles = watched.map((m) => m['title'] ?? 'Unknown').join(', ');
    buffer.writeln('ALL WATCHED TITLES (DO NOT RECOMMEND ANY OF THESE): $watchedTitles');

    // --- RECENT WATCHES WITH REVIEWS ---
    final recentWithNotes = watched
        .where((m) => m['personalNote'] != null && (m['personalNote'] as String).trim().isNotEmpty)
        .take(10);
    if (recentWithNotes.isNotEmpty) {
      final reviews = recentWithNotes.map((m) => 
          "${m['title']} (${m['userRating'] ?? '?'}★): \"${m['personalNote']}\"").join('; ');
      buffer.writeln('REVIEW EXCERPTS: $reviews');
    }

    // --- EXPERIENCES ---
    if (experiences.isNotEmpty) {
      final expSummary = experiences.take(5).map((e) =>
          "${e['title']} at ${e['cinemaName'] ?? 'cinema'}").join(', ');
      buffer.writeln('THEATRE EXPERIENCES: $expSummary');
    }

    // --- PLAYLISTS ---
    if (playlists.isNotEmpty) {
      final playlistSummary = playlists.map((p) {
        final movieIds = p['movieIds'] as List? ?? [];
        return '"${p['name']}" (${movieIds.length} films)';
      }).join(', ');
      buffer.writeln('PLAYLISTS: $playlistSummary');
    }

    buffer.writeln('===');
    return buffer.toString();
  }
}

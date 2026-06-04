import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie_model.dart';

class MovieService {
  final String _apiKey = '0d938d52f1a549ac4ad887eb076430ab'; 
  final String _baseUrl = 'https://api.tmdb.org/3';

  static Map<String, dynamic>? _smartMovieCache;
  static Map<String, dynamic>? _smartSeriesCache;
  static List<MovieModel>? _nowPlayingCache;
  static List<MovieModel>? _upcomingCache;
  static Set<int> get nowPlayingIds => _nowPlayingCache?.map((e) => e.id).toSet() ?? {};

  static Future<void> clearCache() async {
    _smartMovieCache = null;
    _smartSeriesCache = null;
    _nowPlayingCache = null;
    _upcomingCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_movie_recommendations');
    await prefs.remove('cached_series_recommendations');
    debugPrint("MovieService: All Caches Purged.");
  }

  // --- SMART MEDIA DATA ---
  Future<Map<String, dynamic>> getSmartMovieData({bool forceRefresh = false}) async {
    if (_smartMovieCache != null && !forceRefresh) return _smartMovieCache!;
    final result = await _generateSmartData(isTv: false);
    _smartMovieCache = result;
    return result;
  }

  Future<Map<String, dynamic>> getSmartSeriesData({bool forceRefresh = false}) async {
    if (_smartSeriesCache != null && !forceRefresh) return _smartSeriesCache!;
    final result = await _generateSmartData(isTv: true);
    _smartSeriesCache = result;
    return result;
  }

  // --- CORE RECOMMENDATION ENGINE (Balanced Affinity + Match DNA) ---
  Future<Map<String, dynamic>> _generateSmartData({required bool isTv}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'title': 'ARCHIVAL REELS', 'movies': []};

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('movies')
          .where('status', isEqualTo: 'watched').get();

      List<MovieModel> fallbackList = [];
      
      // Pre-fetch a guaranteed fallback list of popular genre/vanguard media to be 100% resilient
      try {
        fallbackList = await getMediaByGenre(isTv ? 18 : 28, isTv: isTv);
      } catch (_) {}

      if (snapshot.docs.isEmpty) {
        final list = await getSimilarMedia(isTv ? 1396 : 27205, isTv: isTv);
        final finalPool = list.isNotEmpty ? list : fallbackList;
        return {'title': 'THE VANGUARD', 'movies': finalPool};
      }

      // 1. ANALYZE DNA
      Map<String, int> directorCounts = {};
      Map<int, double> weightedGenreCounts = {};
      final Set<int> watchedIds = snapshot.docs.map((d) => int.tryParse(d.id) ?? 0).toSet();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final double userRating = (data['userRating'] ?? 3.0).toDouble();
        final double weightMultiplier = userRating >= 4.0 ? 2.0 : 1.0;

        final List? gIds = data['genre_ids'] ?? data['genreIds'];
        if (gIds != null) {
          for (var id in gIds) { 
            weightedGenreCounts[id] = (weightedGenreCounts[id] ?? 0) + (1.0 * weightMultiplier); 
          }
        }

        final String? dir = data['director'];
        if (dir != null && dir != "UNKNOWN" && dir.isNotEmpty) {
          directorCounts[dir] = (directorCounts[dir] ?? 0) + 1;
        }
      }

      // 2. FETCH POOLS
      List<MovieModel> directorPool = [];
      List<MovieModel> genrePool = [];
      String finalTitle = "THE ARCHIVE SELECTION";
      String? affinityDirector;

      // WISE TIERED SELECTION (Fixed logic for Threshold 2 fallback)
      if (directorCounts.isNotEmpty && !isTv) {
        // Tier 1: Try to find directors with 2+ watches (High Affinity)
        var highAffinity = directorCounts.entries
            .where((entry) => entry.value >= 2)
            .map((entry) => entry.key)
            .toList();

        if (highAffinity.isNotEmpty) {
          highAffinity.shuffle();
          affinityDirector = highAffinity.first;
        } 
        // Tier 2: Graceful Degradation to 1+ watch (Solves the "Genre Switch" issue)
        else {
          var eligibleDirectors = directorCounts.keys.toList();
          eligibleDirectors.shuffle();
          affinityDirector = eligibleDirectors.first;
        }

        if (affinityDirector != null) {
          directorPool = await getMoviesByDirector(affinityDirector);
        }
      }

      // Genre DNA Selection
      int topGenreId = 28; 
      if (weightedGenreCounts.isNotEmpty) {
        topGenreId = weightedGenreCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      } else {
        topGenreId = isTv ? 18 : 28;
      }
      
      String genreName = MovieModel.genreMap[topGenreId] ?? 'Cinema';
      genrePool = await getMediaByGenre(topGenreId, isTv: isTv);

      // 3. MERGE & DEDUPLICATE
      List<MovieModel> rawCombinedList = [];
      Set<int> seenIds = {};

      if (affinityDirector != null && !isTv) {
        // Balanced Ratio: 7 from Director (or all they have), then fill with Genre
        for (var m in directorPool.take(7)) {
          if (seenIds.add(m.id)) rawCombinedList.add(m);
        }
        for (var m in genrePool) {
          if (rawCombinedList.length >= 15) break;
          if (seenIds.add(m.id)) rawCombinedList.add(m);
        }
        finalTitle = "${affinityDirector.split(' ').last} + $genreName";
      } else {
        rawCombinedList = genrePool;
        finalTitle = "CURATED $genreName";
      }

      // 4. FILTER WATCHED & INJECT DNA PERCENTAGES
      List<MovieModel> filteredList = rawCombinedList.where((m) => !watchedIds.contains(m.id)).toList();

      // RESILIENCE FALLBACK: If filtering left us with an empty or tiny list, fall back to genre pool without strict watched filtering, or the popular fallback list
      if (filteredList.isEmpty) {
        filteredList = rawCombinedList.isNotEmpty ? rawCombinedList : fallbackList;
      }

      List<MovieModel> finalScoredList = filteredList.map((movie) {
        int matchScore = _calculateMatchPercentage(
          movie: movie, 
          weightedGenres: weightedGenreCounts, 
          affinityDirector: affinityDirector
        );
        
        return MovieModel.fromJson({
          ...movie.toJson(),
          'reason': "$matchScore% Match", 
        });
      }).toList()..shuffle();

      return {
        'title': finalTitle.toUpperCase(), 
        'movies': finalScoredList.take(15).toList()
      };
    } catch (e) {
      debugPrint("Recommendation Engine Failure: $e");
      // Resilient top fallback
      try {
        final fallbackPool = await getMediaByGenre(isTv ? 18 : 28, isTv: isTv);
        return {
          'title': isTv ? 'SERIES CHRONICLE' : 'ARCHIVAL SELECTIONS',
          'movies': fallbackPool.take(15).toList()
        };
      } catch (_) {
        return {'title': 'ARCHIVAL SELECTIONS', 'movies': []};
      }
    }
  }

  // --- DNA MATCH CALCULATION LOGIC ---
  int _calculateMatchPercentage({
    required MovieModel movie, 
    required Map<int, double> weightedGenres, 
    String? affinityDirector
  }) {
    double score = 65.0; 

    if (affinityDirector != null && movie.director == affinityDirector) {
      score += 25.0;
    }

    if (weightedGenres.isNotEmpty) {
      var sortedGenres = weightedGenres.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      var top3Ids = sortedGenres.take(3).map((e) => e.key).toSet();
      
      int matches = movie.genreIds.where((id) => top3Ids.contains(id)).length;
      score += (matches * 7.0); 
    }

    score += (movie.voteAverage * 1.0); 

    return score.clamp(70, 99).toInt();
  }

  // --- API METHODS (PARALLELIZED & FAIL-FAST) ---

  Future<List<MovieModel>> searchAll(String query) async {
    try {
      // PREFETCHING & PARALLELIZING: Strict 5s timeout to keep UI snappy
      final response = await http.get(Uri.parse(
          '$_baseUrl/search/multi?api_key=$_apiKey&query=${Uri.encodeComponent(query)}'
      )).timeout(const Duration(seconds: 5)); 

      if (response.statusCode == 200) {
        final List results = json.decode(response.body)['results'] ?? [];
        return results.map((item) {
          if (item['media_type'] == 'person') {
            return MovieModel.fromJson({
              ...item, 
              'title': item['name'], 
              'isPerson': true, 
              'poster_path': item['profile_path']
            });
          }
          return MovieModel.fromJson(item);
        }).toList();
      }
    } on TimeoutException catch (_) {
      debugPrint("Search Timed Out: Moving to fallback.");
    } catch (e) { 
      debugPrint("Error in searchAll: $e"); 
    }
    return [];
  }

  Future<List<MovieModel>> getMediaByGenre(int genreId, {bool isTv = false}) async {
    final endpoint = isTv ? 'discover/tv' : 'discover/movie';
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$endpoint?api_key=$_apiKey&with_genres=$genreId&sort_by=popularity.desc'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List results = json.decode(response.body)['results'] ?? [];
        return results.map((m) => MovieModel.fromJson({...m, 'isPerson': false, 'media_type': isTv ? 'tv' : 'movie'})).toList();
      }
    } catch (e) {
      debugPrint("Error in getMediaByGenre: $e");
    }
    return [];
  }

  Future<Map<String, dynamic>> getPersonDetails(int personId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/person/$personId?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200 ? json.decode(response.body) : {};
    } catch (e) {
      debugPrint("Error in getPersonDetails: $e");
    }
    return {};
  }

  Future<List<MovieModel>> getDirectedMovies(int personId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/person/$personId/movie_credits?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List crew = json.decode(response.body)['crew'] ?? [];
        return crew.where((m) => m['job'] == 'Director').map((m) => MovieModel.fromJson({...m, 'isPerson': false})).toList();
      }
    } catch (e) {
      debugPrint("Error in getDirectedMovies: $e");
    }
    return [];
  }

  Future<List<MovieModel>> getMoviesByDirector(String directorName) async {
    try {
      final personRes = await http.get(Uri.parse('$_baseUrl/search/person?api_key=$_apiKey&query=${Uri.encodeComponent(directorName)}'))
          .timeout(const Duration(seconds: 5));
      if (personRes.statusCode == 200) {
        final results = json.decode(personRes.body)['results'] as List;
        if (results.isNotEmpty) {
          int personId = results.first['id'];
          final discoverRes = await http.get(Uri.parse('$_baseUrl/discover/movie?api_key=$_apiKey&with_crew=$personId'))
              .timeout(const Duration(seconds: 5));
          return (json.decode(discoverRes.body)['results'] as List).map((m) => MovieModel.fromJson({...m, 'isPerson': false})).toList();
        }
      }
    } catch (e) {
      debugPrint("Error in getMoviesByDirector: $e");
    }
    return [];
  }

  Future<String?> getDirector(int id, bool isTv) async {
    if (isTv) return null;
    try {
      final response = await http.get(Uri.parse('$_baseUrl/movie/$id/credits?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List crew = json.decode(response.body)['crew'] ?? [];
        final director = crew.firstWhere((m) => m['job'] == 'Director', orElse: () => null);
        return director?['name'];
      }
    } catch (e) {
      debugPrint("Error in getDirector: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>> getMediaDetails(int id, {required bool isTv}) async {
    final type = isTv ? 'tv' : 'movie';
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$type/$id?api_key=$_apiKey&append_to_response=credits'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200 ? json.decode(response.body) : {};
    } catch (e) {
      debugPrint("Error in getMediaDetails: $e");
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> getMediaCast(int id, {required bool isTv}) async {
    final type = isTv ? 'tv' : 'movie';
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$type/$id/credits?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 5));
      return List<Map<String, dynamic>>.from(json.decode(response.body)['cast'] ?? []);
    } catch (e) {
      debugPrint("Error in getMediaCast: $e");
    }
    return [];
  }

  Future<List<MovieModel>> getSimilarMedia(int id, {required bool isTv}) async {
    final type = isTv ? 'tv' : 'movie';
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$type/$id/similar?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return (json.decode(response.body)['results'] as List).map((m) => MovieModel.fromJson({...m, 'isPerson': false})).toList();
      }
    } catch (e) {
      debugPrint("Error in getSimilarMedia: $e");
    }
    return [];
  }

  Future<void> permanentlyDismissMovie(int movieId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid)
        .collection('dismissed_recommendations').doc(movieId.toString())
        .set({'timestamp': FieldValue.serverTimestamp()});
    await clearCache();
  }

  // --- THEATRE DATA ---
  Future<List<MovieModel>> getNowPlayingMovies({bool forceRefresh = false}) async {
    if (_nowPlayingCache != null && !forceRefresh) return _nowPlayingCache!;
    try {
      final response = await http.get(Uri.parse('$_baseUrl/movie/now_playing?api_key=$_apiKey&region=IN&language=en-US'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List results = json.decode(response.body)['results'] ?? [];
        _nowPlayingCache = results.map((m) => MovieModel.fromJson({...m, 'isPerson': false, 'media_type': 'movie'})).toList();
        return _nowPlayingCache!;
      }
    } catch (e) {
      debugPrint("Error in getNowPlayingMovies: $e");
    }
    return [];
  }

  Future<List<MovieModel>> getUpcomingMovies({bool forceRefresh = false}) async {
    if (_upcomingCache != null && !forceRefresh) return _upcomingCache!;
    try {
      final response = await http.get(Uri.parse('$_baseUrl/movie/upcoming?api_key=$_apiKey&region=IN&language=en-US'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List results = json.decode(response.body)['results'] ?? [];
        _upcomingCache = results.map((m) => MovieModel.fromJson({...m, 'isPerson': false, 'media_type': 'movie'})).toList();
        return _upcomingCache!;
      }
    } catch (e) {
      debugPrint("Error in getUpcomingMovies: $e");
    }
    return [];
  }
}
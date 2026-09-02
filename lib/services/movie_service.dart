import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie_model.dart';
import '../models/taste_profile_model.dart';
import '../core/secrets.dart';
import 'analytics_service.dart';
import 'taste_profile_service.dart';

class MovieService {
  String get _apiKey => AppSecrets.tmdbApiKey;
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

  /// Fetch diversity ratio from Firebase Remote Config.
  /// Defaults: confident=0.65, serendipity=0.20, community=0.15
  static Future<Map<String, double>> _getDiversityRatio() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await rc.fetchAndActivate();
      final confidentRaw = rc.getDouble('diversity_confident');
      final serendipityRaw = rc.getDouble('diversity_serendipity');
      return {
        'confident': confidentRaw > 0 ? confidentRaw : 0.65,
        'serendipity': serendipityRaw > 0 ? serendipityRaw : 0.20,
      };
    } catch (_) {
      return {'confident': 0.65, 'serendipity': 0.20};
    }
  }

  /// Log a recommendation click event.
  static Future<void> logRecClick(MovieModel movie, String section) async {
    await AnalyticsService.logRecClicked(
      movieTitle: movie.title,
      carouselSection: section,
      matchScore: movie.voteAverage,
    );
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

  // --- RECOMMENDATION ENGINE V2 (Multi-Signal Taste Profile) ---
  Future<Map<String, dynamic>> _generateSmartData({required bool isTv}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'title': 'ARCHIVAL REELS', 'movies': []};

    try {
      // 1. Load persisted taste profile
      final profile = await TasteProfileService().getProfile(user.uid);
      final Set<int> watchedIds = await _getWatchedIds(user.uid);

      // ─── COLD-START FALLBACK (< 5 watched movies) ───
      if (profile.watchedCount < 5) {
        final coldGenres = profile.coldStartGenres.isNotEmpty
            ? profile.coldStartGenres
            : (isTv ? [18, 35] : [28, 878]); // drama/comedy for TV, action/scifi for movies
        final trendingMovies = await getMediaByGenre(coldGenres.first, isTv: isTv);
        final result = trendingMovies
            .where((m) => !watchedIds.contains(m.id))
            .take(15)
            .map((m) => MovieModel.fromJson({
                  ...m.toJson(),
                  'reason': 'Trending pick to kick off your taste profile 🎬',
                }))
            .toList();
        return {'title': isTv ? 'SERIES TO START WITH' : 'FILMS TO START WITH', 'movies': result};
      }

      // 2. Determine top genre + director for candidate fetching
      final List<int> topGenres = profile.topGenreIds(n: 3);
      final List<String> topDirs = profile.topDirectors(n: 2);
      final bool isColdStart = profile.watchedCount < 3;

      // Fallback genre if profile empty
      final int primaryGenreId = topGenres.isNotEmpty
          ? topGenres.first
          : (isTv ? 18 : 28);

      // 3. FETCH CANDIDATE POOLS in parallel
      final futures = <Future<List<MovieModel>>>[
        getMediaByGenre(primaryGenreId, isTv: isTv),
        if (topGenres.length > 1) getMediaByGenre(topGenres[1], isTv: isTv),
        if (topDirs.isNotEmpty && !isTv)
          getMoviesByDirector(topDirs.first)
        else
          Future.value(<MovieModel>[]),
        _fetchSerendipityPool(profile, isTv: isTv),
      ];

      final pools = await Future.wait(futures);
      final List<MovieModel> genrePool1 = pools[0];
      final List<MovieModel> genrePool2 = pools.length > 1 ? pools[1] : [];
      final List<MovieModel> directorPool = pools.length > 2 ? pools[2] : [];
      final List<MovieModel> serendipityPool =
          pools.length > 3 ? pools[3] : [];

      // 4. SCORE & FILTER candidates
      final Set<int> avoidGenres = profile.avoidGenres.toSet();
      final allCandidates = <MovieModel>[
        ...genrePool1,
        ...genrePool2,
        ...directorPool,
      ];

      // Deduplicate
      final Map<int, MovieModel> dedupMap = {};
      for (final m in allCandidates) {
        if (!dedupMap.containsKey(m.id)) dedupMap[m.id] = m;
      }

      // Filter watched + avoided genres
      List<MovieModel> filtered = dedupMap.values.where((m) {
        if (watchedIds.contains(m.id)) return false;
        if (avoidGenres.isNotEmpty) {
          final overlap = m.genreIds
              .where((g) => avoidGenres.contains(g))
              .length;
          // Exclude if >50% of genres are in avoidance list
          if (m.genreIds.isNotEmpty &&
              overlap / m.genreIds.length > 0.5) return false;
        }
        return true;
      }).toList();

      // Score each candidate
      final scoredCandidates = filtered.map((m) {
        final score = _scoreCandidate(m, profile);
        final explanation = _buildExplanation(m, profile);
        return _ScoredMovie(movie: m, score: score, explanation: explanation);
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      // 5. DIVERSITY MIXING via Remote Config ratios
      const int targetTotal = 15;
      final ratios = await _getDiversityRatio();
      final int confidentCount = (targetTotal * (ratios['confident'] ?? 0.65)).ceil();
      final int serendipityCount = (targetTotal * (ratios['serendipity'] ?? 0.20)).ceil();

      final List<MovieModel> result = [];
      final Set<int> addedIds = {};

      // Confident picks (top-scored)
      for (final sm in scoredCandidates.take(confidentCount)) {
        if (addedIds.add(sm.movie.id)) {
          result.add(MovieModel.fromJson({
            ...sm.movie.toJson(),
            'reason': sm.explanation,
          }));
        }
      }

      // Serendipity picks
      final serendipityFiltered = serendipityPool
          .where((m) =>
              !watchedIds.contains(m.id) && !addedIds.contains(m.id))
          .take(serendipityCount)
          .toList();
      for (final m in serendipityFiltered) {
        if (addedIds.add(m.id)) {
          result.add(MovieModel.fromJson({
            ...m.toJson(),
            'reason': '✨ Exploring beyond your usual picks',
            'isSerendipity': true,
          }));
        }
      }

      // Fill remainder from remaining scored
      for (final sm in scoredCandidates) {
        if (result.length >= targetTotal) break;
        if (addedIds.add(sm.movie.id)) {
          result.add(MovieModel.fromJson({
            ...sm.movie.toJson(),
            'reason': sm.explanation,
          }));
        }
      }

      // Shuffle for organic feel
      result.shuffle(Random());

      // Build title
      String title;
      if (isColdStart) {
        title = 'THE VANGUARD';
      } else if (topDirs.isNotEmpty && !isTv) {
        final dirLast = topDirs.first.split(' ').last.toUpperCase();
        title = '$dirLast · ${MovieModel.genreMap[primaryGenreId]?.toUpperCase() ?? 'CINEMA'}';
      } else {
        title = 'CURATED ${MovieModel.genreMap[primaryGenreId]?.toUpperCase() ?? 'PICKS'}';
      }

      return {'title': title, 'movies': result};
    } catch (e) {
      debugPrint('RecommendationEngineV2 failure: $e');
      try {
        final fallback = await getMediaByGenre(isTv ? 18 : 28, isTv: isTv);
        return {
          'title': isTv ? 'SERIES CHRONICLE' : 'ARCHIVAL SELECTIONS',
          'movies': fallback.take(15).toList(),
        };
      } catch (_) {
        return {'title': 'ARCHIVAL SELECTIONS', 'movies': []};
      }
    }
  }

  /// Score a single candidate movie against the user's taste profile.
  double _scoreCandidate(MovieModel movie, UserTasteProfile profile) {
    double score = 0.0;

    // --- Genre affinity (40%) ---
    double genreScore = 0.0;
    final genreScores = profile.genreScores;
    for (final gId in movie.genreIds) {
      final gs = genreScores[gId.toString()];
      if (gs != null && !gs.isAvoidance) {
        genreScore += gs.score.clamp(0, 5);
      }
    }
    if (movie.genreIds.isNotEmpty) {
      genreScore = (genreScore / movie.genreIds.length).clamp(0, 5);
    }
    score += genreScore * 0.40;

    // --- Director affinity (25%) ---
    if (movie.director != null) {
      final ds = profile.directorScores[movie.director!];
      if (ds != null) {
        score += (ds.score.clamp(0, 5)) * 0.25;
      }
    }

    // --- Popularity match (15%) ---
    final pop = _classifyPopularity(movie.voteCount, movie.voteAverage);
    final prefPop = profile.preferredPopularity;
    if ((pop == 'underrated' && prefPop == PopularityPreference.underrated) ||
        (pop == 'mainstream' && prefPop == PopularityPreference.mainstream) ||
        (pop == 'overrated' && prefPop == PopularityPreference.overrated)) {
      score += 5.0 * 0.15;
    } else if (prefPop == PopularityPreference.mixed) {
      score += 2.5 * 0.15;
    }

    // --- TMDB quality baseline (10%) ---
    score += (movie.voteAverage / 10.0) * 5.0 * 0.10;

    // --- Recency bonus (10%) ---
    try {
      final year = int.tryParse(movie.releaseDate.split('-').first) ?? 0;
      final currentYear = DateTime.now().year;
      if (year >= currentYear - 2) score += 5.0 * 0.10;
    } catch (_) {}

    return score;
  }

  String _buildExplanation(MovieModel movie, UserTasteProfile profile) {
    final topDirs = profile.topDirectors(n: 1);
    final topGenres = profile.topGenreIds(n: 2);

    // Director match
    if (movie.director != null &&
        topDirs.isNotEmpty &&
        movie.director == topDirs.first) {
      return 'Because you love ${movie.director}\'s work';
    }

    // Genre match with cinecast keyword
    final genreMatch = movie.genreIds
        .any((g) => topGenres.contains(g));
    if (genreMatch && profile.cinecastKeywords.isNotEmpty) {
      return 'Matches your love of ${profile.cinecastKeywords.first}';
    }

    // Underrated pick
    final pop = _classifyPopularity(movie.voteCount, movie.voteAverage);
    if (pop == 'underrated' && profile.prefersUnderrated) {
      return 'A hidden gem matching your taste for underrated films';
    }

    // Generic match
    if (genreMatch) {
      final genreLabel = movie.genreIds
          .map((g) => MovieModel.genreMap[g])
          .where((n) => n != null)
          .firstOrNull ?? 'your genre';
      return 'Curated for your love of $genreLabel';
    }

    return 'Curated from your Archival DNA';
  }

  String _classifyPopularity(int voteCount, double voteAverage) {
    if (voteCount > 100000 && voteAverage > 7.5) return 'overrated';
    if (voteCount < 10000 && voteAverage > 7.0) return 'underrated';
    return 'mainstream';
  }

  Future<Set<int>> _getWatchedIds(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('movies')
          .where('status', isEqualTo: 'watched')
          .get();
      return snap.docs.map((d) => int.tryParse(d.id) ?? 0).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<List<MovieModel>> _fetchSerendipityPool(
      UserTasteProfile profile, {required bool isTv}) async {
    try {
      // Pick a genre NOT in user's top 3 for variety
      final allGenreIds = MovieModel.genreMap.keys.toList();
      final topGenres = profile.topGenreIds(n: 3).toSet();
      final avoidGenres = profile.avoidGenres.toSet();
      final candidateGenres = allGenreIds
          .where((g) => !topGenres.contains(g) && !avoidGenres.contains(g))
          .toList();

      if (candidateGenres.isEmpty) {
        return await getMediaByGenre(isTv ? 18 : 28, isTv: isTv);
      }
      candidateGenres.shuffle(Random());
      return await getMediaByGenre(candidateGenres.first, isTv: isTv);
    } catch (_) {
      return [];
    }
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

  Future<List<MovieModel>> getPersonCombinedCredits(int personId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/person/$personId/combined_credits?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List cast = json.decode(response.body)['cast'] ?? [];
        // Sort by popularity to show their best/most known work first
        cast.sort((a, b) => (b['popularity'] ?? 0.0).compareTo(a['popularity'] ?? 0.0));
        return cast.map((m) => MovieModel.fromJson({...m, 'isPerson': false, 'media_type': m['media_type'] ?? 'movie'})).toList();
      }
    } catch (e) {
      debugPrint("Error in getPersonCombinedCredits: $e");
    }
    return [];
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

  Future<String?> getTrailerUrl(int id, {required bool isTv}) async {
    final type = isTv ? 'tv' : 'movie';
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$type/$id/videos?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List results = json.decode(response.body)['results'] ?? [];
        final trailer = results.firstWhere(
          (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
          orElse: () => null,
        );
        if (trailer != null) {
          return 'https://www.youtube.com/watch?v=${trailer['key']}';
        }
      }
    } catch (e) {
      debugPrint("Error in getTrailerUrl: $e");
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getWatchProviders(int id, {required bool isTv}) async {
    final type = isTv ? 'tv' : 'movie';
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$type/$id/watch/providers?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final Map<String, dynamic> results = json.decode(response.body)['results'] ?? {};
        
        // Prioritize India, fallback to US
        Map<String, dynamic>? data = results['IN'];
        if (data == null || (data['flatrate'] == null && data['rent'] == null && data['buy'] == null && data['free'] == null)) {
          data = results['US'];
        }

        if (data != null) {
          final List flatrate = data['flatrate'] ?? [];
          final List free = data['free'] ?? [];
          final List rent = data['rent'] ?? [];
          final List buy = data['buy'] ?? [];
          
          final List<Map<String, dynamic>> allProviders = [];
          final Set<int> seenIds = {};

          void addProviders(List list, String type) {
            for (var item in list) {
              final pid = item['provider_id'];
              if (!seenIds.contains(pid)) {
                seenIds.add(pid);
                allProviders.add({
                  'name': item['provider_name'],
                  'logo_path': item['logo_path'],
                  'type': type,
                });
              }
            }
          }

          addProviders(flatrate, 'STREAM');
          addProviders(free, 'FREE');
          addProviders(rent, 'RENT');
          addProviders(buy, 'BUY');
          
          return allProviders;
        }
      }
    } catch (e) {
      debugPrint("Error in getWatchProviders: $e");
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

  static List<MovieModel>? _trendingCache;
  static DateTime? _trendingCacheTime;

  Future<List<MovieModel>> getTrendingAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _trendingCache != null && _trendingCacheTime != null) {
      if (DateTime.now().difference(_trendingCacheTime!).inHours < 1) {
        return _trendingCache!;
      }
    }
    
    try {
      final response = await http.get(Uri.parse('$_baseUrl/trending/all/week?api_key=$_apiKey&language=en-US'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List results = json.decode(response.body)['results'] ?? [];
        _trendingCache = results
            .where((m) => m['media_type'] == 'movie' || m['media_type'] == 'tv')
            .take(15) // Limit to top 15 trending items
            .map((m) => MovieModel.fromJson(m))
            .toList();
        _trendingCacheTime = DateTime.now();
        return _trendingCache!;
      }
    } catch (e) {
      debugPrint("Error in getTrendingAll: $e");
    }
    
    return _trendingCache ?? [];
  }


}

// ─────────────── INTERNAL HELPER ───────────────
class _ScoredMovie {
  final MovieModel movie;
  final double score;
  final String explanation;
  const _ScoredMovie({
    required this.movie,
    required this.score,
    required this.explanation,
  });
}
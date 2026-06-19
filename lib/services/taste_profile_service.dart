/// TasteProfileService — Builds and maintains a dynamic, hierarchical
/// user taste profile from Watched+Ratings, Watchlist intent, and Cinecast.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/movie_model.dart';
import '../models/taste_profile_model.dart';
import 'bot_service.dart';

// ─────────────── THRESHOLDS ───────────────
const int _kOverratedVoteThreshold = 100000;
const int _kUnderratedVoteThreshold = 10000;
const double _kHighRatingThreshold = 4.0;
const double _kLowRatingThreshold = 2.5;

// ─────────────── CINECAST KEYWORDS ───────────────
const List<String> _kPositiveKeywords = [
  'masterpiece', 'stunning', 'breathtaking', 'mind-bending', 'arthouse',
  'cinematography', 'beautiful', 'profound', 'complex', 'layered',
  'underrated', 'hidden gem', 'emotional', 'powerful', 'iconic',
  'atmospheric', 'thought-provoking', 'brilliant', 'timeless', 'intense',
  'gripping', 'visually', 'poetic', 'haunting', 'surreal', 'epic',
];
const List<String> _kNegativeKeywords = [
  'boring', 'cliche', 'predictable', 'overrated', 'jumpscares', 'generic',
  'shallow', 'disappointing', 'slow', 'confusing', 'forgettable', 'mediocre',
  'waste', 'bad acting', 'awful', 'terrible', 'worst',
];

class TasteProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────── READ ───────────────

  /// Fetch profile from Firestore. Returns empty if not found.
  Future<UserTasteProfile> getProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('taste_profile')
          .doc('main')
          .get();

      if (!doc.exists || doc.data() == null) {
        // If the profile doesn't exist yet, build it from scratch from the user's history
        return await buildAndSaveProfile(uid);
      }
      return UserTasteProfile.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('TasteProfileService.getProfile error: $e');
      return UserTasteProfile.empty(uid);
    }
  }

  // ─────────────── FULL REBUILD ───────────────

  /// Full rebuild from scratch — call on login / first open / manual refresh.
  Future<UserTasteProfile> buildAndSaveProfile(String uid) async {
    try {
      final results = await Future.wait([
        _fetchWatchedMovies(uid),
        _fetchWatchlistMovies(uid),
        _fetchCinecastPosts(uid),
        _fetchLikedPosts(uid),
      ]);

      final watched = results[0] as List<Map<String, dynamic>>;
      final watchlist = results[1] as List<Map<String, dynamic>>;
      final myPosts = results[2] as List<Map<String, dynamic>>;
      final likedPosts = results[3] as List<Map<String, dynamic>>;

      // --- SIGNAL 1: Watched + Ratings ---
      final Map<String, double> genreScoreMap = {};
      final Map<String, int> directorCountMap = {};
      final Map<String, double> directorScoreMap = {};
      final Set<int> avoidGenreSet = {};
      final List<int> recentGenreList = [];
      final Set<String> exploratoryCountries = {};
      int watchedCount = 0;

      // Sort by watchedAt for recency
      watched.sort((a, b) {
        final aDate = a['watchedAt'] as String? ?? '';
        final bDate = b['watchedAt'] as String? ?? '';
        return bDate.compareTo(aDate);
      });

      for (int i = 0; i < watched.length; i++) {
        final data = watched[i];
        final double userRating = (data['userRating'] ?? 3.0).toDouble();
        final bool isHighRated = userRating >= _kHighRatingThreshold;
        final bool isLowRated = userRating <= _kLowRatingThreshold;
        final bool isRecent = i < 10;

        // Recency boost multiplier
        double recencyMultiplier = isRecent ? 1.3 : 1.0;
        // Rating weight
        double ratingWeight = isHighRated ? 2.0 : (isLowRated ? -1.0 : 0.5);
        double finalWeight = ratingWeight * recencyMultiplier;

        // Genre scoring
        final List gIds = data['genreIds'] ?? data['genre_ids'] ?? [];
        for (final id in gIds) {
          final key = id.toString();
          genreScoreMap[key] = (genreScoreMap[key] ?? 0.0) + finalWeight;
          if (isLowRated) avoidGenreSet.add(id as int);
          if (isRecent) recentGenreList.add(id as int);
        }

        // Director scoring
        final String? dir = data['director'];
        if (dir != null && dir.isNotEmpty && dir != 'UNKNOWN') {
          directorCountMap[dir] = (directorCountMap[dir] ?? 0) + 1;
          final dirWeight = isHighRated ? 2.5 : (isLowRated ? -0.5 : 1.0);
          directorScoreMap[dir] = (directorScoreMap[dir] ?? 0.0) +
              dirWeight * recencyMultiplier;
        }

        // Country tracking
        final String? country = data['originCountry'];
        if (country != null && country.isNotEmpty) {
          exploratoryCountries.add(country);
        }

        watchedCount++;
      }

      // Build final genre score objects
      final Map<String, GenreScore> genreScores = {};
      genreScoreMap.forEach((id, score) {
        final intId = int.tryParse(id) ?? 0;
        final label = MovieModel.genreMap[intId] ?? 'Genre';
        final isAvoid = avoidGenreSet.contains(intId) && score < 0;
        genreScores[id] = GenreScore(
          genreId: intId,
          label: label,
          score: score,
          isAvoidance: isAvoid,
        );
      });

      // Build director score objects
      final Map<String, DirectorScore> directorScores = {};
      directorScoreMap.forEach((name, score) {
        directorScores[name] = DirectorScore(
          name: name,
          score: score,
          watchCount: directorCountMap[name] ?? 1,
        );
      });

      // --- SIGNAL 2: Watchlist intent (popularity classification) ---
      int underratedCount = 0, mainstreamCount = 0, overratedCount = 0;
      for (final m in watchlist) {
        final int vc = (m['voteCount'] ?? 0).toInt();
        final double va = (m['voteAverage'] ?? 0.0).toDouble();
        final pop = _classifyPopularity(vc, va);
        if (pop == 'underrated') underratedCount++;
        else if (pop == 'overrated') overratedCount++;
        else mainstreamCount++;
      }
      final int total = underratedCount + mainstreamCount + overratedCount;
      final Map<String, double> popularityBreakdown = total > 0
          ? {
              'underrated': underratedCount / total,
              'mainstream': mainstreamCount / total,
              'overrated': overratedCount / total,
            }
          : {'underrated': 0.33, 'mainstream': 0.33, 'overrated': 0.33};

      PopularityPreference pref = PopularityPreference.mixed;
      if (total > 0) {
        final maxEntry = popularityBreakdown.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        if (maxEntry.value > 0.5) {
          if (maxEntry.key == 'underrated') pref = PopularityPreference.underrated;
          else if (maxEntry.key == 'mainstream') pref = PopularityPreference.mainstream;
          else pref = PopularityPreference.overrated;
        }
      }

      // --- SIGNAL 3: Cinecast (keyword + sentiment extraction) ---
      final allPosts = [...myPosts, ...likedPosts];
      final Set<String> positiveKeywords = {};
      final Set<String> negativeKeywords = {};
      final Set<String> mentionedKeywords = {};

      for (final post in allPosts) {
        final String text =
            ((post['reason'] ?? '') as String).toLowerCase();
        for (final kw in _kPositiveKeywords) {
          if (text.contains(kw)) {
            mentionedKeywords.add(kw);
            positiveKeywords.add(kw);
          }
        }
        for (final kw in _kNegativeKeywords) {
          if (text.contains(kw)) negativeKeywords.add(kw);
        }
      }

      // Build avoidGenres list (genres with negative score only)
      final List<int> avoidGenreList = genreScores.entries
          .where((e) => e.value.isAvoidance)
          .map((e) => e.value.genreId)
          .toList();

      // Deduplicate recentGenres
      final List<int> uniqueRecentGenres =
          recentGenreList.toSet().take(8).toList();

      final profile = UserTasteProfile(
        userId: uid,
        lastUpdated: DateTime.now(),
        watchedCount: watchedCount,
        genreScores: genreScores,
        directorScores: directorScores,
        castAffinities: const [], // Phase 2 enhancement
        preferredPopularity: pref,
        popularityBreakdown: popularityBreakdown,
        cinecastKeywords: mentionedKeywords.take(15).toList(),
        cinecastSentiment: {
          'positive': positiveKeywords.take(10).toList(),
          'negative': negativeKeywords.take(10).toList(),
        },
        recentGenres: uniqueRecentGenres,
        avoidGenres: avoidGenreList,
        exploratoryCountries: exploratoryCountries.toList(),
        onboardingComplete: watchedCount > 0,
        coldStartGenres: const [],
      );

      await _saveProfile(uid, profile);
      debugPrint('TasteProfileService: Profile rebuilt for $uid (${watchedCount} watched)');
      return profile;
    } catch (e) {
      debugPrint('TasteProfileService.buildAndSaveProfile error: $e');
      return UserTasteProfile.empty(uid);
    }
  }

  // ─────────────── INCREMENTAL UPDATES ───────────────

  /// Call after a movie is rated. Updates genre + director scores incrementally.
  Future<void> updateFromRating(
      String uid, int movieId, double newRating) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('movies')
          .doc(movieId.toString())
          .get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final List gIds = data['genreIds'] ?? data['genre_ids'] ?? [];
      final String? dir = data['director'];

      // Only do a delta update if it's material
      final double weight = newRating >= _kHighRatingThreshold ? 1.5 : (newRating <= _kLowRatingThreshold ? -1.0 : 0.3);

      final Map<String, dynamic> updates = {};
      for (final id in gIds) {
        updates['genreScores.${id}.score'] = FieldValue.increment(weight);
        updates['genreScores.${id}.label'] =
            MovieModel.genreMap[id] ?? 'Genre';
        if (newRating <= _kLowRatingThreshold) {
          updates['genreScores.${id}.avoidance'] = true;
        }
      }
      if (dir != null && dir.isNotEmpty && dir != 'UNKNOWN') {
        final double dirWeight = newRating >= _kHighRatingThreshold ? 1.5 : (newRating <= _kLowRatingThreshold ? -0.5 : 0.3);
        updates['directorScores.$dir.score'] = FieldValue.increment(dirWeight);
        updates['directorScores.$dir.watchCount'] = FieldValue.increment(1);
      }
      updates['lastUpdated'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('taste_profile')
          .doc('main')
          .set(updates, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TasteProfileService.updateFromRating error: $e');
    }
  }

  /// Call when a movie is added to watchlist. Updates popularity breakdown.
  Future<void> updateFromWatchlistAdd(String uid, MovieModel movie) async {
    try {
      final String pop = _classifyPopularity(movie.voteCount, movie.voteAverage);
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('taste_profile')
          .doc('main')
          .set({
        'popularityBreakdown.$pop': FieldValue.increment(0.1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TasteProfileService.updateFromWatchlistAdd error: $e');
    }
  }

  /// Call after a Cinecast post. Extracts keywords async.
  Future<void> extractCinecastKeywords(String uid, String postText) async {
    try {
      final text = postText.toLowerCase();
      final List<String> foundPositive = [];
      final List<String> foundNegative = [];

      for (final kw in _kPositiveKeywords) {
        if (text.contains(kw)) foundPositive.add(kw);
      }
      for (final kw in _kNegativeKeywords) {
        if (text.contains(kw)) foundNegative.add(kw);
      }

      if (foundPositive.isEmpty && foundNegative.isEmpty) return;

      final Map<String, dynamic> updates = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (foundPositive.isNotEmpty) {
        updates['cinecastKeywords'] = FieldValue.arrayUnion(foundPositive);
        updates['cinecastSentiment.positive'] =
            FieldValue.arrayUnion(foundPositive);
      }
      if (foundNegative.isNotEmpty) {
        updates['cinecastSentiment.negative'] =
            FieldValue.arrayUnion(foundNegative);
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('taste_profile')
          .doc('main')
          .set(updates, SetOptions(merge: true));

      // Phase 3: Proactively summarize with LLM in background
      BotService().summarizeCinecastActivity(uid);
    } catch (e) {
      debugPrint('TasteProfileService.extractCinecastKeywords error: $e');
    }
  }

  /// Save onboarding cold-start genres.
  Future<void> saveOnboardingPreferences(
      String uid, List<int> genreIds) async {
    try {
      final Map<String, dynamic> data = {
        'userId': uid,
        'onboardingComplete': true,
        'coldStartGenres': genreIds,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      // Seed genreScores from onboarding
      for (final id in genreIds) {
        data['genreScores.$id.score'] = 1.5;
        data['genreScores.$id.label'] = MovieModel.genreMap[id] ?? 'Genre';
      }
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('taste_profile')
          .doc('main')
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TasteProfileService.saveOnboardingPreferences error: $e');
    }
  }

  /// Call when user gives 👍 feedback. Reinforces genre scores.
  Future<void> recordPositiveFeedback(String uid, MovieModel movie) async {
    try {
      final Map<String, dynamic> updates = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      for (final genreId in movie.genreIds.take(2)) {
        updates['genreScores.$genreId.score'] = FieldValue.increment(0.2);
      }
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('taste_profile')
          .doc('main')
          .set(updates, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TasteProfileService.recordPositiveFeedback error: $e');
    }
  }

  /// Call when user gives 👎 feedback. Adds genres to avoidance vectors.
  Future<void> recordNegativeFeedback(String uid, MovieModel movie) async {
    try {
      final Map<String, dynamic> updates = {
        'lastUpdated': FieldValue.serverTimestamp(),
        'avoidGenres': FieldValue.arrayUnion(movie.genreIds.take(2).toList()),
      };
      for (final genreId in movie.genreIds.take(2)) {
        updates['genreScores.$genreId.score'] = FieldValue.increment(-0.3);
      }
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('taste_profile')
          .doc('main')
          .set(updates, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TasteProfileService.recordNegativeFeedback error: $e');
    }
  }

  // ─────────────── PRIVATE HELPERS ───────────────

  Future<void> _saveProfile(String uid, UserTasteProfile profile) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('taste_profile')
        .doc('main')
        .set(profile.toJson());
  }

  Future<List<Map<String, dynamic>>> _fetchWatchedMovies(String uid) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('movies')
        .where('status', isEqualTo: 'watched')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchWatchlistMovies(String uid) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('movies')
        .where('status', isEqualTo: 'watchlist')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchCinecastPosts(String uid) async {
    try {
      // Query community_recs filtered by senderId == uid (no mirror collection needed)
      final snap = await _firestore
          .collection('community_recs')
          .where('senderId', isEqualTo: uid)
          .where('type', isEqualTo: 'movie')
          .limit(30)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLikedPosts(String uid) async {
    try {
      final snap = await _firestore
          .collection('community_recs')
          .where('likedBy', arrayContains: uid)
          .where('type', isEqualTo: 'movie')
          .limit(30)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Classifies a movie by TMDB vote_count + vote_average.
  String _classifyPopularity(int voteCount, double voteAverage) {
    if (voteCount > _kOverratedVoteThreshold && voteAverage > 7.5) {
      return 'overrated'; // Very popular AND highly rated
    }
    if (voteCount < _kUnderratedVoteThreshold && voteAverage > 7.0) {
      return 'underrated'; // Few votes but solid quality
    }
    return 'mainstream';
  }

  // ─────────────── LEGACY COMPATIBILITY ───────────────

  /// Kept for backward compatibility with existing code that calls buildTasteDNA.
  /// Returns a formatted string for LLM injection.
  Future<String> buildTasteDNA(String uid) async {
    final profile = await buildAndSaveProfile(uid);
    return profile.toTasteString();
  }
}

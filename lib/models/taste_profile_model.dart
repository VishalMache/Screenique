import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────── GENRE SCORE ───────────────
class GenreScore {
  final int genreId;
  final String label;
  final double score;
  final bool isAvoidance;

  const GenreScore({
    required this.genreId,
    required this.label,
    required this.score,
    this.isAvoidance = false,
  });

  factory GenreScore.fromJson(String genreId, Map<String, dynamic> json) {
    return GenreScore(
      genreId: int.tryParse(genreId) ?? 0,
      label: json['label'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
      isAvoidance: json['avoidance'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'score': score,
    if (isAvoidance) 'avoidance': true,
  };
}

// ─────────────── DIRECTOR SCORE ───────────────
class DirectorScore {
  final String name;
  final double score;
  final int watchCount;

  const DirectorScore({
    required this.name,
    required this.score,
    required this.watchCount,
  });

  factory DirectorScore.fromJson(String name, Map<String, dynamic> json) {
    return DirectorScore(
      name: name,
      score: (json['score'] ?? 0.0).toDouble(),
      watchCount: (json['watchCount'] ?? 1).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'score': score,
    'watchCount': watchCount,
  };
}

// ─────────────── POPULARITY PREFERENCE ───────────────
enum PopularityPreference { underrated, mainstream, overrated, mixed }

// ─────────────── MAIN MODEL ───────────────
class UserTasteProfile {
  final String userId;
  final DateTime lastUpdated;
  final int watchedCount;

  /// Genre scores: genreId (as string) → GenreScore
  final Map<String, GenreScore> genreScores;

  /// Director scores: directorName → DirectorScore
  final Map<String, DirectorScore> directorScores;

  /// Preferred actors/cast (extracted from watched + highly rated)
  final List<String> castAffinities;

  /// Derived popularity style
  final PopularityPreference preferredPopularity;
  final Map<String, double> popularityBreakdown;

  /// Keywords from Cinecast posts
  final List<String> cinecastKeywords;
  final Map<String, List<String>> cinecastSentiment; // {positive: [...], negative: [...]}

  /// Recent genre ids (last 10 watches)
  final List<int> recentGenres;

  /// Genre ids to avoid (from low-rated movies)
  final List<int> avoidGenres;

  /// Countries the user has explored
  final List<String> exploratoryCountries;

  /// Cold start state
  final bool onboardingComplete;
  final List<int> coldStartGenres;

  const UserTasteProfile({
    required this.userId,
    required this.lastUpdated,
    required this.watchedCount,
    required this.genreScores,
    required this.directorScores,
    required this.castAffinities,
    required this.preferredPopularity,
    required this.popularityBreakdown,
    required this.cinecastKeywords,
    required this.cinecastSentiment,
    required this.recentGenres,
    required this.avoidGenres,
    required this.exploratoryCountries,
    required this.onboardingComplete,
    required this.coldStartGenres,
  });

  /// Empty profile for a brand-new user
  factory UserTasteProfile.empty(String uid) => UserTasteProfile(
    userId: uid,
    lastUpdated: DateTime.now(),
    watchedCount: 0,
    genreScores: {},
    directorScores: {},
    castAffinities: [],
    preferredPopularity: PopularityPreference.mixed,
    popularityBreakdown: {'underrated': 0.33, 'mainstream': 0.33, 'overrated': 0.33},
    cinecastKeywords: [],
    cinecastSentiment: {'positive': [], 'negative': []},
    recentGenres: [],
    avoidGenres: [],
    exploratoryCountries: [],
    onboardingComplete: false,
    coldStartGenres: [],
  );

  factory UserTasteProfile.fromJson(Map<String, dynamic> json) {
    // Parse genreScores
    final Map<String, GenreScore> genreScores = {};
    final raw = json['genreScores'] as Map<String, dynamic>? ?? {};
    raw.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        genreScores[k] = GenreScore.fromJson(k, v);
      }
    });

    // Parse directorScores
    final Map<String, DirectorScore> directorScores = {};
    final rawDir = json['directorScores'] as Map<String, dynamic>? ?? {};
    rawDir.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        directorScores[k] = DirectorScore.fromJson(k, v);
      }
    });

    // Parse popularity
    PopularityPreference pref = PopularityPreference.mixed;
    final prefStr = json['preferredPopularity'] as String? ?? 'mixed';
    if (prefStr == 'underrated') pref = PopularityPreference.underrated;
    else if (prefStr == 'mainstream') pref = PopularityPreference.mainstream;
    else if (prefStr == 'overrated') pref = PopularityPreference.overrated;

    // Parse breakdown
    final Map<String, double> breakdown = {};
    final rawBd = json['popularityBreakdown'] as Map<String, dynamic>? ?? {};
    rawBd.forEach((k, v) => breakdown[k] = (v as num).toDouble());

    // Parse sentiment
    final Map<String, List<String>> sentiment = {'positive': [], 'negative': []};
    final rawSent = json['cinecastSentiment'] as Map<String, dynamic>? ?? {};
    rawSent.forEach((k, v) {
      if (v is List) sentiment[k] = List<String>.from(v);
    });

    final ts = json['lastUpdated'];
    final DateTime dt = ts is Timestamp
        ? ts.toDate()
        : ts is String
            ? DateTime.tryParse(ts) ?? DateTime.now()
            : DateTime.now();

    return UserTasteProfile(
      userId: json['userId'] as String? ?? '',
      lastUpdated: dt,
      watchedCount: (json['watchedCount'] ?? 0).toInt(),
      genreScores: genreScores,
      directorScores: directorScores,
      castAffinities: List<String>.from(json['castAffinities'] ?? []),
      preferredPopularity: pref,
      popularityBreakdown: breakdown.isEmpty
          ? {'underrated': 0.33, 'mainstream': 0.33, 'overrated': 0.33}
          : breakdown,
      cinecastKeywords: List<String>.from(json['cinecastKeywords'] ?? []),
      cinecastSentiment: sentiment,
      recentGenres: List<int>.from(json['recentGenres'] ?? []),
      avoidGenres: List<int>.from(json['avoidGenres'] ?? []),
      exploratoryCountries: List<String>.from(json['exploratoryCountries'] ?? []),
      onboardingComplete: json['onboardingComplete'] == true,
      coldStartGenres: List<int>.from(json['coldStartGenres'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    // Serialize genreScores
    final Map<String, dynamic> gs = {};
    genreScores.forEach((k, v) => gs[k] = v.toJson());

    // Serialize directorScores
    final Map<String, dynamic> ds = {};
    directorScores.forEach((k, v) => ds[k] = v.toJson());

    String prefStr = 'mixed';
    if (preferredPopularity == PopularityPreference.underrated) prefStr = 'underrated';
    else if (preferredPopularity == PopularityPreference.mainstream) prefStr = 'mainstream';
    else if (preferredPopularity == PopularityPreference.overrated) prefStr = 'overrated';

    return {
      'userId': userId,
      'lastUpdated': FieldValue.serverTimestamp(),
      'watchedCount': watchedCount,
      'genreScores': gs,
      'directorScores': ds,
      'castAffinities': castAffinities,
      'preferredPopularity': prefStr,
      'popularityBreakdown': popularityBreakdown,
      'cinecastKeywords': cinecastKeywords,
      'cinecastSentiment': cinecastSentiment,
      'recentGenres': recentGenres,
      'avoidGenres': avoidGenres,
      'exploratoryCountries': exploratoryCountries,
      'onboardingComplete': onboardingComplete,
      'coldStartGenres': coldStartGenres,
    };
  }

  // ─────────────── HELPERS ───────────────

  /// Top N genre IDs by score (excluding avoidances)
  List<int> topGenreIds({int n = 5}) {
    final positive = genreScores.values
        .where((g) => !g.isAvoidance && g.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return positive.take(n).map((g) => g.genreId).toList();
  }

  /// Top N director names by score
  List<String> topDirectors({int n = 3}) {
    final sorted = directorScores.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return sorted.take(n).map((d) => d.name).toList();
  }

  bool get prefersUnderrated =>
      preferredPopularity == PopularityPreference.underrated ||
      (popularityBreakdown['underrated'] ?? 0) > 0.45;

  bool get hasAvoidances => avoidGenres.isNotEmpty;

  /// Format taste summary as a human-readable string for LLM prompts
  String toTasteString() {
    final topG = genreScores.values
        .where((g) => !g.isAvoidance && g.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final topD = topDirectors(n: 3);
    final buffer = StringBuffer();

    buffer.writeln('USER TASTE PROFILE:');
    if (topG.isNotEmpty) {
      buffer.writeln('• Top Genres: ${topG.take(4).map((g) => '${g.label} (${g.score.toStringAsFixed(1)})').join(', ')}');
    }
    if (topD.isNotEmpty) {
      buffer.writeln('• Favorite Directors: ${topD.join(', ')}');
    }
    if (avoidGenres.isNotEmpty) {
      final avoidLabels = genreScores.values
          .where((g) => g.isAvoidance)
          .map((g) => g.label)
          .join(', ');
      buffer.writeln('• Avoidance Genres: $avoidLabels');
    }
    buffer.writeln('• Watchlist Style: ${preferredPopularity.name.toUpperCase()} (${((popularityBreakdown['underrated'] ?? 0) * 100).toInt()}% underrated picks)');
    if (cinecastKeywords.isNotEmpty) {
      buffer.writeln('• Cinecast Keywords: ${cinecastKeywords.take(6).join(', ')}');
    }
    if (cinecastSentiment['positive']?.isNotEmpty == true) {
      buffer.writeln('• Loves: ${cinecastSentiment['positive']!.take(4).join(', ')}');
    }
    if (cinecastSentiment['negative']?.isNotEmpty == true) {
      buffer.writeln('• Dislikes: ${cinecastSentiment['negative']!.take(4).join(', ')}');
    }
    buffer.writeln('• Watched Count: $watchedCount films');
    return buffer.toString();
  }
}

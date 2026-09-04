import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_models.dart';
import '../models/movie_model.dart';
import '../data/quick_mix_pool.dart';
import '../data/game_verdicts_data.dart';
import '../data/dialogues_data.dart';
import '../core/secrets.dart';
import 'movie_service.dart';

class GameService {
  static const String _streakKey = 'game_streak_v1';
  static const String _recentlyPlayedKey = 'game_recently_played_v1';
  static const String _recentThemesKey = 'game_recent_themes_v1';

  final MovieService _movieService = MovieService();
  String get _apiKey => AppSecrets.tmdbApiKey;
  final String _baseUrl = 'https://api.tmdb.org/3';

  static const int _roundsPerSession = 10;

  // ─── QUICK MIX ────────────────────────────────────────────────────────────────

  /// Returns 10 Quick Mix rounds from the curated pool.
  Future<List<GameRound>> getQuickMixRounds() async {
    final recentIds = await _getRecentlyPlayedIds();
    final pool = List<Map<String, dynamic>>.from(quickMixPool);
    pool.shuffle(Random());

    final available = pool.where((m) => !recentIds.contains(m['id'] as int)).toList();
    final candidates = available.length >= _roundsPerSession ? available : pool;

    final rounds = <GameRound>[];
    for (final data in candidates.take(_roundsPerSession)) {
      rounds.add(_buildRoundFromPoolData(data));
    }
    return rounds;
  }

  GameRound _buildRoundFromPoolData(Map<String, dynamic> data) {
    final rawClues = (data['clues'] as List<dynamic>);
    // Pick 3–4 evidences, mixing types
    final evidences = _selectEvidencesFromPool(rawClues, data);

    return GameRound(
      movieId: data['id'] as int,
      movieTitle: data['title'] as String,
      posterUrl: data['posterUrl'] as String,
      backdropUrl: data['backdropUrl'] as String?,
      directorName: data['director'] as String?,
      castNames: List<String>.from(data['cast'] ?? []),
      genre: data['genre'] as String? ?? '',
      year: data['year'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      interestingFact: data['fact'] as String?,
      evidences: evidences,
    );
  }

  List<Evidence> _selectEvidencesFromPool(List<dynamic> rawClues, Map<String, dynamic> data) {
    // Always start with plot if available, then vary the rest
    final result = <Evidence>[];
    final random = Random();

    for (final c in rawClues) {
      final type = _evidenceTypeFromString(c['type'] as String);
      result.add(Evidence(
        type: type,
        label: _labelForEvidenceType(type),
        content: c['content'] as String,
      ));
    }

    // Target 3 or 4 evidences (randomly pick)
    final targetCount = random.nextBool() ? 3 : 4;
    if (result.length > targetCount) {
      return result.take(targetCount).toList();
    }
    return result;
  }

  // ─── THEMED CHALLENGE ─────────────────────────────────────────────────────────

  /// Fetches 10 movies from TMDB for a themed challenge and builds game rounds.
  Future<List<GameRound>> getThemedRounds({required ThemeCategory theme}) async {
    final movies = await _fetchThemeMovies(theme);
    final recentIds = await _getRecentlyPlayedIds();
    final filtered = movies.where((m) => !recentIds.contains(m.id)).toList();
    final candidates = filtered.length >= _roundsPerSession ? filtered : movies;

    final rounds = <GameRound>[];
    for (final movie in candidates.take(_roundsPerSession)) {
      final round = await _buildRoundFromTmdb(movie);
      if (round != null) rounds.add(round);
      if (rounds.length >= _roundsPerSession) break;
    }
    return rounds;
  }

  Future<List<MovieModel>> _fetchThemeMovies(ThemeCategory theme) async {
    try {
      String url;
      if (theme.personId != null) {
        url = '$_baseUrl/discover/movie?api_key=$_apiKey'
            '&with_crew=${theme.personId}'
            '&sort_by=vote_count.desc';
      } else {
        final params = StringBuffer('$_baseUrl/discover/movie?api_key=$_apiKey');
        if (theme.genreIds != null && theme.genreIds!.isNotEmpty) {
          params.write('&with_genres=${theme.genreIds!.join(",")}');
        }
        if (theme.withOriginCountry != null) {
          params.write('&with_origin_country=${theme.withOriginCountry}');
        }
        if (theme.yearFrom != null) {
          params.write('&primary_release_date.gte=${theme.yearFrom}-01-01');
        }
        if (theme.yearTo != null) {
          params.write('&primary_release_date.lte=${theme.yearTo}-12-31');
        }
        if (theme.minVoteAverage != null) {
          params.write('&vote_average.gte=${theme.minVoteAverage}');
        }
        if (theme.minVoteCount != null) {
          params.write('&vote_count.gte=${theme.minVoteCount}');
        }
        params.write('&sort_by=${theme.sortBy ?? "popularity.desc"}');
        params.write('&page=1');
        url = params.toString();
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List results = json.decode(response.body)['results'] ?? [];
        final movies = results
            .map((m) => MovieModel.fromJson({...m, 'isPerson': false, 'media_type': 'movie'}))
            .toList();
        movies.shuffle(Random());
        return movies.cast<MovieModel>();
      }
    } catch (e) {
      debugPrint('GameService._fetchThemeMovies error: $e');
    }
    return [];
  }

  Future<GameRound?> _buildRoundFromTmdb(MovieModel movie) async {
    try {
      final details = await _movieService.getMediaDetails(movie.id, isTv: false);
      final castList = await _movieService.getMediaCast(movie.id, isTv: false);

      final director = _extractDirector(details);
      final cast = castList.take(5).map((c) => c['name'] as String? ?? '').toList();
      final tagline = details['tagline'] as String?;
      final overview = details['overview'] as String? ?? movie.overview;
      final fact = _extractFact(details);
      final dialogueData = _getDialogueForMovie(movie.id);

      final evidences = _buildEvidences(
        movieTitle: movie.title,
        overview: overview,
        tagline: tagline,
        director: director,
        cast: cast,
        year: movie.releaseDate.split('-').first,
        fact: fact,
        dialogue: dialogueData?['quote'],
        dialogueCharacter: dialogueData?['character'],
      );

      return GameRound(
        movieId: movie.id,
        movieTitle: movie.title,
        posterUrl: movie.posterPath,
        backdropUrl: movie.backdropPath,
        directorName: director,
        castNames: cast,
        genre: movie.genreNames,
        year: movie.releaseDate.split('-').first,
        rating: movie.voteAverage,
        interestingFact: fact,
        evidences: evidences,
      );
    } catch (e) {
      debugPrint('GameService._buildRoundFromTmdb error: $e');
      return null;
    }
  }

  // ─── EVIDENCE GENERATION ──────────────────────────────────────────────────────

  /// Builds 3–4 diverse evidence items for a movie.
  /// Randomizes which types are used so each round feels different.
  List<Evidence> _buildEvidences({
    required String movieTitle,
    required String overview,
    required String? tagline,
    required String? director,
    required List<String> cast,
    required String year,
    required String? fact,
    required String? dialogue,
    required String? dialogueCharacter,
  }) {
    final random = Random();
    final all = <Evidence>[];

    // 1. Plot (always available — obfuscate movie name)
    if (overview.isNotEmpty) {
      all.add(Evidence(
        type: EvidenceType.plot,
        label: 'PLOT',
        content: _obfuscateTitle(overview, movieTitle),
      ));
    }

    // 2. Tagline
    if (tagline != null && tagline.isNotEmpty) {
      all.add(Evidence(
        type: EvidenceType.tagline,
        label: 'TAGLINE',
        content: '"$tagline"',
      ));
    }

    // 3. Director
    if (director != null && director.isNotEmpty) {
      all.add(Evidence(
        type: EvidenceType.director,
        label: 'DIRECTOR',
        content: 'Directed by $director.',
      ));
    }

    // 4. Cast
    if (cast.isNotEmpty) {
      final names = cast.take(3).join(', ');
      all.add(Evidence(
        type: EvidenceType.cast,
        label: 'CAST',
        content: 'Stars: $names.',
      ));
    }

    // 5. Dialogue (if available in curated data)
    if (dialogue != null && dialogue.isNotEmpty) {
      final charStr = dialogueCharacter != null ? '\n— $dialogueCharacter' : '';
      all.add(Evidence(
        type: EvidenceType.dialogue,
        label: 'DIALOGUE',
        content: '"$dialogue"$charStr',
      ));
    }

    // 6. Year/Era trivia
    if (year.isNotEmpty) {
      all.add(Evidence(
        type: EvidenceType.year,
        label: 'ERA',
        content: 'This film was released in $year.',
      ));
    }

    // 7. Trivia/fact
    if (fact != null && fact.isNotEmpty) {
      all.add(Evidence(
        type: EvidenceType.trivia,
        label: 'TRIVIA',
        content: fact,
      ));
    }

    // Shuffle the optional evidences (everything after plot) for variety
    if (all.length > 1) {
      final plotClue = all.first;
      final rest = all.sublist(1);
      rest.shuffle(random);
      all.clear();
      all.add(plotClue);
      all.addAll(rest);
    }

    // Target 3 or 4 evidences — pick 3 by default, 4 if lucky
    final targetCount = random.nextDouble() < 0.4 ? 4 : 3;
    return all.take(targetCount.clamp(3, all.length)).toList();
  }

  /// Score based on which evidence index the movie was solved on.
  static int scoreForEvidence(int evidenceIndex, int wrongGuesses) {
    const baseScores = [100, 80, 60, 40];
    final base = evidenceIndex < baseScores.length ? baseScores[evidenceIndex] : 0;
    final penalty = wrongGuesses * 5;
    return (base - penalty).clamp(0, 100);
  }

  String _obfuscateTitle(String text, String title) {
    return text
        .replaceAll(title, '●●●●●')
        .replaceAll(title.toLowerCase(), '●●●●●')
        .replaceAll(title.toUpperCase(), '●●●●●');
  }

  EvidenceType _evidenceTypeFromString(String s) {
    switch (s) {
      case 'plot':      return EvidenceType.plot;
      case 'director':  return EvidenceType.director;
      case 'cast':      return EvidenceType.cast;
      case 'dialogue':  return EvidenceType.dialogue;
      case 'tagline':   return EvidenceType.tagline;
      case 'year':      return EvidenceType.year;
      case 'trivia':
      case 'fact':      return EvidenceType.trivia;
      default:          return EvidenceType.plot;
    }
  }

  String _labelForEvidenceType(EvidenceType t) {
    switch (t) {
      case EvidenceType.plot:      return 'PLOT';
      case EvidenceType.director:  return 'DIRECTOR';
      case EvidenceType.cast:      return 'CAST';
      case EvidenceType.dialogue:  return 'DIALOGUE';
      case EvidenceType.tagline:   return 'TAGLINE';
      case EvidenceType.year:      return 'ERA';
      case EvidenceType.trivia:    return 'TRIVIA';
    }
  }

  String? _extractDirector(Map<String, dynamic> details) {
    final credits = details['credits'];
    if (credits == null) return null;
    final crew = credits['crew'] as List?;
    if (crew == null) return null;
    final dir = crew.firstWhere(
      (m) => m['job'] == 'Director',
      orElse: () => null,
    );
    return dir?['name'] as String?;
  }

  String? _extractFact(Map<String, dynamic> details) {
    final tagline = details['tagline'] as String?;
    if (tagline != null && tagline.isNotEmpty) return tagline;
    return null;
  }

  Map<String, String>? _getDialogueForMovie(int tmdbId) {
    try {
      final dialogue = MovieDialogue.dialogues
          .firstWhere((d) => d.tmdbId == tmdbId, orElse: () => throw Exception());
      return {'quote': dialogue.quote, 'character': dialogue.character};
    } catch (_) {
      return null;
    }
  }

  // ─── SEARCH ───────────────────────────────────────────────────────────────────

  Future<List<MovieModel>> searchMoviesForGuess(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final response = await http.get(Uri.parse(
        '$_baseUrl/search/movie?api_key=$_apiKey&query=${Uri.encodeComponent(query)}&page=1',
      )).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List results = json.decode(response.body)['results'] ?? [];
        return results
            .where((m) => m['poster_path'] != null)
            .take(8)
            .map((m) => MovieModel.fromJson({...m, 'isPerson': false, 'media_type': 'movie'}))
            .toList();
      }
    } catch (e) {
      debugPrint('GameService.searchMoviesForGuess error: $e');
    }
    return [];
  }

  // ─── RESULT BUILDING ──────────────────────────────────────────────────────────

  GameResult buildFinalResult({
    required GameSession session,
    required int streakDays,
  }) {
    final totalScore = session.totalScore;
    final maxScore = session.rounds.length * 100;
    final xp = (totalScore * 0.1).round().clamp(5, 500);

    final verdictData = GameVerdicts.getVerdict(
      score: totalScore,
      maxScore: maxScore,
      cluesUsed: (session.avgEvidenceUsed * 10).round(),
      maxClues: 40,
      wrongGuesses: session.rounds.fold(0, (s, r) => s + r.wrongGuesses),
      difficulty: GameDifficulty.medium,
      streakDays: streakDays,
      isSolved: session.solvedCount > 0,
    );

    return GameResult(
      challengeType: session.challengeType,
      themeName: session.themeName,
      themeEmoji: session.themeEmoji,
      totalScore: totalScore,
      xpEarned: xp,
      verdict: verdictData,
      verdictLabel: _verdictLabel(totalScore, session.solvedCount, session.rounds.length),
      playedAt: DateTime.now(),
      streakDays: streakDays,
      isPerfectRun: session.isPerfectRun,
      solvedCount: session.solvedCount,
      totalRounds: session.rounds.length,
      avgEvidenceUsed: session.avgEvidenceUsed,
      bestRoundScore: session.bestRoundScore,
      fastestSolveMs: session.fastestSolveMs,
      rounds: List.from(session.rounds),
    );
  }

  String _verdictLabel(int score, int solved, int total) {
    final ratio = solved / total;
    if (ratio == 1.0 && score >= 900) return '🏛️ FILM ARCHIVIST';
    if (ratio >= 0.9) return '🔥 CINEPHILE INSTINCT';
    if (ratio >= 0.7) return '🎬 FILM SCHOLAR';
    if (ratio >= 0.5) return '🍿 MOVIE BUFF';
    return '📽️ CASUAL VIEWER';
  }

  // ─── PERSISTENCE ──────────────────────────────────────────────────────────────

  Future<void> saveResult(GameResult result) async {
    final prefs = await SharedPreferences.getInstance();

    final currentXp = prefs.getInt('game_total_xp') ?? 0;
    await prefs.setInt('game_total_xp', currentXp + result.xpEarned);

    final played = prefs.getInt('game_total_played') ?? 0;
    await prefs.setInt('game_total_played', played + 1);

    await _updateStreak();

    if (result.themeName != null) {
      await _addRecentTheme(result.themeName!);
    }

    // Mark movies as recently played to avoid repeats
    for (final round in result.rounds) {
      await _addRecentlyPlayedId(round.movieId);
    }

    debugPrint('GameService: Result saved. XP: ${result.xpEarned}, Score: ${result.totalScore}');
  }

  Future<int> getTotalXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('game_total_xp') ?? 0;
  }

  Future<int> getTotalPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('game_total_played') ?? 0;
  }

  // ─── STREAK ───────────────────────────────────────────────────────────────────

  Future<int> getStreakDays() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_streakKey);
    if (data == null) return 0;
    final map = json.decode(data) as Map<String, dynamic>;
    return map['days'] as int? ?? 0;
  }

  Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final data = prefs.getString(_streakKey);
    int days = 0;
    String? lastPlayed;

    if (data != null) {
      final map = json.decode(data) as Map<String, dynamic>;
      days = map['days'] as int? ?? 0;
      lastPlayed = map['lastPlayed'] as String?;
    }

    if (lastPlayed == today) return;

    final yesterday = _yesterdayKey();
    if (lastPlayed == yesterday) {
      days += 1;
    } else {
      days = 1;
    }

    await prefs.setString(_streakKey, json.encode({
      'days': days,
      'lastPlayed': today,
    }));
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayKey() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }

  // ─── RECENTLY PLAYED ──────────────────────────────────────────────────────────

  Future<Set<int>> _getRecentlyPlayedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentlyPlayedKey) ?? [];
    return list.map(int.parse).toSet();
  }

  Future<void> _addRecentlyPlayedId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentlyPlayedKey) ?? [];
    list.remove(id.toString());
    list.insert(0, id.toString());
    await prefs.setStringList(_recentlyPlayedKey, list.take(30).toList());
  }

  Future<List<String>> getRecentThemes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentThemesKey) ?? [];
  }

  Future<void> _addRecentTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentThemesKey) ?? [];
    list.remove(themeName);
    list.insert(0, themeName);
    await prefs.setStringList(_recentThemesKey, list.take(5).toList());
  }

  // ─── PLAYER STATS ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPlayerStats() async {
    final prefs = await SharedPreferences.getInstance();
    final xp = prefs.getInt('game_total_xp') ?? 0;
    final played = prefs.getInt('game_total_played') ?? 0;
    final streak = await getStreakDays();

    return {
      'xp': xp,
      'played': played,
      'streak': streak,
      'levelTitle': _xpToLevelTitle(xp),
    };
  }

  String _xpToLevelTitle(int xp) {
    if (xp >= 5000) return '🏛️ Film Archivist';
    if (xp >= 2000) return '🧠 Film Scholar';
    if (xp >= 750) return '🎞️ Cinephile';
    if (xp >= 200) return '🎬 Movie Buff';
    return '🍿 Casual Viewer';
  }
}

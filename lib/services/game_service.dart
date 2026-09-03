import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_models.dart';
import '../models/movie_model.dart';
import '../data/quick_mix_pool.dart';
import '../data/game_themes_data.dart';
import '../data/game_verdicts_data.dart';
import '../data/dialogues_data.dart';
import '../core/secrets.dart';
import 'movie_service.dart';

class GameService {
  static const String _statsKey = 'game_stats_v1';
  static const String _streakKey = 'game_streak_v1';
  static const String _recentlyPlayedKey = 'game_recently_played_v1';
  static const String _recentThemesKey = 'game_recent_themes_v1';

  final MovieService _movieService = MovieService();
  String get _apiKey => AppSecrets.tmdbApiKey;
  final String _baseUrl = 'https://api.tmdb.org/3';

  // ─── QUICK MIX ─────────────────────────────────────────────────────────────

  /// Returns a random Quick Mix round from the curated pool,
  /// avoiding recently played movies.
  Future<GameRound?> getQuickMixRound({
    required GameDifficulty difficulty,
    required GuessMode guessMode,
  }) async {
    final recentIds = await _getRecentlyPlayedIds();
    final pool = List<Map<String, dynamic>>.from(quickMixPool);
    pool.shuffle(Random());

    // Filter out recently played
    final available = pool.where((m) => !recentIds.contains(m['id'] as int)).toList();
    final candidates = available.isNotEmpty ? available : pool; // fallback: ignore recents

    if (candidates.isEmpty) return null;
    final data = candidates.first;
    return _buildRoundFromPoolData(data, guessMode, difficulty);
  }

  GameRound _buildRoundFromPoolData(
    Map<String, dynamic> data,
    GuessMode guessMode,
    GameDifficulty difficulty,
  ) {
    final config = DifficultyConfig.fromEnum(difficulty);
    final rawClues = (data['clues'] as List<dynamic>)
        .take(config.maxClues)
        .map((c) => GameClue(
              type: c['type'],
              label: c['label'],
              content: c['content'],
            ))
        .toList();

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
      clues: guessMode == GuessMode.ultimate ? rawClues : [],
      dialogueQuote: guessMode == GuessMode.dialogue
          ? _getDialogueForMovie(data['id'] as int)
          : null,
      dialogueCharacter: guessMode == GuessMode.dialogue
          ? _getDialogueCharacterForMovie(data['id'] as int)
          : null,
    );
  }

  // ─── THEMED CHALLENGE ──────────────────────────────────────────────────────

  /// Fetches 5 movies from TMDB for a themed challenge and builds game rounds.
  Future<List<GameRound>> getThemedRounds({
    required ThemeCategory theme,
    required GameDifficulty difficulty,
    required GuessMode guessMode,
  }) async {
    final movies = await _fetchThemeMovies(theme, difficulty);
    final recentIds = await _getRecentlyPlayedIds();
    final filtered = movies.where((m) => !recentIds.contains(m.id)).toList();
    final candidates = filtered.isNotEmpty ? filtered : movies;

    final rounds = <GameRound>[];
    for (final movie in candidates.take(5)) {
      final round = await _buildRoundFromTmdb(movie, guessMode, difficulty);
      if (round != null) rounds.add(round);
    }
    return rounds;
  }

  Future<List<MovieModel>> _fetchThemeMovies(
      ThemeCategory theme, GameDifficulty difficulty) async {
    try {
      String url;
      if (theme.personId != null) {
        // Director-based theme
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
        params.write('&page=${_difficultyPage(difficulty)}');
        url = params.toString();
      }

      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
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

  /// Hard = page 3 (less popular), Medium = page 2, Easy = page 1
  int _difficultyPage(GameDifficulty d) {
    switch (d) {
      case GameDifficulty.easy: return 1;
      case GameDifficulty.medium: return 2;
      case GameDifficulty.hard: return 3;
    }
  }

  Future<GameRound?> _buildRoundFromTmdb(
      MovieModel movie, GuessMode guessMode, GameDifficulty difficulty) async {
    try {
      final config = DifficultyConfig.fromEnum(difficulty);
      final details = await _movieService.getMediaDetails(movie.id, isTv: false);
      final castList = await _movieService.getMediaCast(movie.id, isTv: false);

      final director = _extractDirector(details);
      final cast = castList.take(5).map((c) => c['name'] as String? ?? '').toList();
      final tagline = details['tagline'] as String?;
      final overview = details['overview'] as String? ?? movie.overview;
      final fact = _extractFact(details);

      final clues = _generateUltimateClues(
        overview: overview,
        tagline: tagline,
        director: director,
        cast: cast,
        movieTitle: movie.title,
        maxClues: config.maxClues,
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
        clues: guessMode == GuessMode.ultimate ? clues : [],
        dialogueQuote: guessMode == GuessMode.dialogue
            ? _getDialogueForMovie(movie.id)
            : null,
        dialogueCharacter: guessMode == GuessMode.dialogue
            ? _getDialogueCharacterForMovie(movie.id)
            : null,
      );
    } catch (e) {
      debugPrint('GameService._buildRoundFromTmdb error: $e');
      return null;
    }
  }

  // ─── CUSTOM CHALLENGE ──────────────────────────────────────────────────────

  /// Builds a custom challenge by combining genre + era + director preferences.
  Future<List<GameRound>> getCustomRounds({
    required int? genreId,
    required int? yearFrom,
    required int? yearTo,
    required int? personId,
    required GameDifficulty difficulty,
    required GuessMode guessMode,
  }) async {
    try {
      final params = StringBuffer('$_baseUrl/discover/movie?api_key=$_apiKey');
      if (genreId != null) params.write('&with_genres=$genreId');
      if (yearFrom != null) params.write('&primary_release_date.gte=$yearFrom-01-01');
      if (yearTo != null) params.write('&primary_release_date.lte=$yearTo-12-31');
      if (personId != null) params.write('&with_crew=$personId');
      params.write('&vote_count.gte=500');
      params.write('&sort_by=popularity.desc');
      params.write('&page=${_difficultyPage(difficulty)}');

      final response = await http.get(Uri.parse(params.toString()))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List results = json.decode(response.body)['results'] ?? [];
        final movies = results
            .map((m) => MovieModel.fromJson({...m, 'isPerson': false, 'media_type': 'movie'}))
            .toList();
        movies.shuffle(Random());

        final rounds = <GameRound>[];
        for (final movie in (movies as List<dynamic>).take(5)) {
          final round = await _buildRoundFromTmdb(movie as MovieModel, guessMode, difficulty);
          if (round != null) rounds.add(round);
        }
        return rounds;
      }
    } catch (e) {
      debugPrint('GameService.getCustomRounds error: $e');
    }
    return [];
  }

  // ─── CLUE GENERATION ───────────────────────────────────────────────────────

  List<GameClue> _generateUltimateClues({
    required String overview,
    required String? tagline,
    required String? director,
    required List<String> cast,
    required String movieTitle,
    required int maxClues,
  }) {
    final clues = <GameClue>[];

    // Clue 1 — Plot (always from overview, slightly obfuscated)
    if (overview.isNotEmpty) {
      clues.add(GameClue(
        type: 'plot',
        label: 'PLOT CLUE',
        content: _obfuscateTitle(overview, movieTitle),
      ));
    }

    // Clue 2 — Tagline or character hint
    if (tagline != null && tagline.isNotEmpty && clues.length < maxClues) {
      clues.add(GameClue(
        type: 'tagline',
        label: 'TAGLINE CLUE',
        content: '"$tagline"',
      ));
    } else if (cast.isNotEmpty && clues.length < maxClues) {
      clues.add(GameClue(
        type: 'character',
        label: 'CHARACTER CLUE',
        content: 'This film features characters portrayed by ${cast.take(2).join(" and ")}.',
      ));
    }

    // Clue 3 — Director
    if (director != null && director.isNotEmpty && clues.length < maxClues) {
      clues.add(GameClue(
        type: 'director',
        label: 'DIRECTOR CLUE',
        content: 'Directed by $director.',
      ));
    }

    // Clue 4 — Cast
    if (cast.isNotEmpty && clues.length < maxClues) {
      final names = cast.take(3).join(', ');
      clues.add(GameClue(
        type: 'cast',
        label: 'CAST CLUE',
        content: 'Stars: $names.',
      ));
    }

    // Clue 5 — Full cast
    if (cast.length > 3 && clues.length < maxClues) {
      clues.add(GameClue(
        type: 'cast',
        label: 'FINAL CAST CLUE',
        content: 'Full principal cast includes: ${cast.join(", ")}.',
      ));
    }

    return clues.take(maxClues).toList();
  }

  /// Removes/replaces the movie title in the overview to prevent giveaways.
  String _obfuscateTitle(String text, String title) {
    return text
        .replaceAll(title, '●●●●●')
        .replaceAll(title.toLowerCase(), '●●●●●')
        .replaceAll(title.toUpperCase(), '●●●●●');
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
    // Use tagline as interesting fact if available
    final tagline = details['tagline'] as String?;
    if (tagline != null && tagline.isNotEmpty) return tagline;
    return null;
  }

  // ─── DIALOGUE MODE ─────────────────────────────────────────────────────────

  String? _getDialogueForMovie(int tmdbId) {
    try {
      final dialogue = MovieDialogue.dialogues
          .firstWhere((d) => d.tmdbId == tmdbId, orElse: () => MovieDialogue.getRandom());
      return dialogue.quote;
    } catch (_) {
      return MovieDialogue.getRandom().quote;
    }
  }

  String? _getDialogueCharacterForMovie(int tmdbId) {
    try {
      final dialogue = MovieDialogue.dialogues
          .firstWhere((d) => d.tmdbId == tmdbId, orElse: () => MovieDialogue.getRandom());
      return dialogue.character;
    } catch (_) {
      return null;
    }
  }

  /// Get a random dialogue clue not tied to a specific movie (for dialogue mode standalone).
  MovieDialogue getRandomDialogueClue() => MovieDialogue.getRandom();

  // ─── SEARCH ────────────────────────────────────────────────────────────────

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

  // ─── SCORING & RESULTS ─────────────────────────────────────────────────────

  GameResult buildResult({
    required GameSession session,
    required int streakDays,
  }) {
    final config = DifficultyConfig.fromEnum(session.difficulty);
    final totalScore = session.totalScore;
    final maxScore = session.rounds.length * (100 * config.scoreMultiplier).round();
    final xp = (totalScore * 0.1).round().clamp(5, 500);

    final firstRound = session.rounds.isNotEmpty ? session.rounds.first : null;

    final verdict = GameVerdicts.getVerdict(
      score: totalScore,
      maxScore: maxScore,
      cluesUsed: firstRound?.cluesRevealed ?? 0,
      maxClues: config.maxClues,
      wrongGuesses: firstRound?.wrongGuesses ?? 0,
      difficulty: session.difficulty,
      streakDays: streakDays,
      isSolved: session.solvedCount > 0,
    );

    return GameResult(
      challengeType: session.challengeType,
      themeName: session.themeName,
      themeEmoji: session.themeEmoji,
      difficulty: session.difficulty,
      guessMode: session.guessMode,
      totalScore: totalScore,
      xpEarned: xp,
      verdict: verdict,
      playedAt: DateTime.now(),
      streakDays: streakDays,
      isPerfectRun: session.isPerfectRun,
      solvedCount: session.solvedCount,
      totalRounds: session.rounds.length,
      solvedAtClue: firstRound?.solvedAtClue,
      movieTitle: firstRound?.movieTitle,
      posterUrl: firstRound?.posterUrl,
      directorName: firstRound?.directorName,
      genre: firstRound?.genre,
      year: firstRound?.year,
      rating: firstRound?.rating,
      interestingFact: firstRound?.interestingFact,
    );
  }

  // ─── PERSISTENCE ───────────────────────────────────────────────────────────

  Future<void> saveResult(GameResult result) async {
    final prefs = await SharedPreferences.getInstance();

    // Update XP
    final currentXp = prefs.getInt('game_total_xp') ?? 0;
    await prefs.setInt('game_total_xp', currentXp + result.xpEarned);

    // Update games played
    final played = prefs.getInt('game_total_played') ?? 0;
    await prefs.setInt('game_total_played', played + 1);

    // Update recently played
    await _addRecentlyPlayed(result.movieTitle ?? '');

    // Update streak
    await _updateStreak();

    // Save recent theme
    if (result.themeName != null) {
      await _addRecentTheme(result.themeName!);
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

  // ─── STREAK ────────────────────────────────────────────────────────────────

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

    if (lastPlayed == today) {
      // Already played today — don't increment
      return;
    }

    final yesterday = _yesterdayKey();
    if (lastPlayed == yesterday) {
      days += 1; // Consecutive day
    } else {
      days = 1; // Streak reset
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

  // ─── RECENTLY PLAYED ───────────────────────────────────────────────────────

  Future<Set<int>> _getRecentlyPlayedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentlyPlayedKey) ?? [];
    return list.map(int.parse).toSet();
  }

  Future<void> _addRecentlyPlayed(String movieTitle) async {
    final prefs = await SharedPreferences.getInstance();
    // We track IDs by scanning the pool
    final match = quickMixPool.firstWhere(
      (m) => m['title'] == movieTitle,
      orElse: () => {},
    );
    if (match.isEmpty) return;

    final id = match['id'] as int;
    final list = prefs.getStringList(_recentlyPlayedKey) ?? [];
    list.remove(id.toString());
    list.insert(0, id.toString());
    // Keep only last 10
    await prefs.setStringList(_recentlyPlayedKey, list.take(10).toList());
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

  // ─── PLAYER STATS ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPlayerStats() async {
    final prefs = await SharedPreferences.getInstance();
    final xp = prefs.getInt('game_total_xp') ?? 0;
    final played = prefs.getInt('game_total_played') ?? 0;
    final streak = await getStreakDays();

    return {
      'xp': xp,
      'played': played,
      'streak': streak,
      'level': _xpToLevel(xp),
      'levelTitle': _xpToLevelTitle(xp),
    };
  }

  int _xpToLevel(int xp) {
    if (xp >= 5000) return 5;
    if (xp >= 2000) return 4;
    if (xp >= 750) return 3;
    if (xp >= 200) return 2;
    return 1;
  }

  String _xpToLevelTitle(int xp) {
    if (xp >= 5000) return '🏛️ Film Archivist';
    if (xp >= 2000) return '🧠 Film Scholar';
    if (xp >= 750) return '🎞️ Cinephile';
    if (xp >= 200) return '🎬 Movie Buff';
    return '🍿 Casual Viewer';
  }
}

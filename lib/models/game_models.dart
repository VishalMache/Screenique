import 'package:flutter/material.dart';

// ─── ENUMS ────────────────────────────────────────────────────────────────────

enum ChallengeType { quickMix, themed, custom }

enum GameDifficulty { easy, medium, hard }

enum GuessMode { ultimate, dialogue, blurPoster, castDirector }

// ─── DIFFICULTY CONFIG ─────────────────────────────────────────────────────────

class DifficultyConfig {
  final GameDifficulty difficulty;
  final int maxClues;
  final int maxAttempts;
  final double scoreMultiplier;
  final String label;
  final String description;
  final String emoji;
  final Color color;

  const DifficultyConfig({
    required this.difficulty,
    required this.maxClues,
    required this.maxAttempts,
    required this.scoreMultiplier,
    required this.label,
    required this.description,
    required this.emoji,
    required this.color,
  });

  static const easy = DifficultyConfig(
    difficulty: GameDifficulty.easy,
    maxClues: 5,
    maxAttempts: 3,
    scoreMultiplier: 1.0,
    label: 'EASY',
    description: 'Mainstream movies. Clues are relatively generous.',
    emoji: '🍿',
    color: Color(0xFF4CAF50),
  );

  static const medium = DifficultyConfig(
    difficulty: GameDifficulty.medium,
    maxClues: 4,
    maxAttempts: 2,
    scoreMultiplier: 1.5,
    label: 'MEDIUM',
    description: 'Popular + moderately obscure movies.',
    emoji: '🎬',
    color: Color(0xFFFF9800),
  );

  static const hard = DifficultyConfig(
    difficulty: GameDifficulty.hard,
    maxClues: 3,
    maxAttempts: 1,
    scoreMultiplier: 2.0,
    label: 'HARD',
    description: 'Niche movies, less obvious clues, fewer giveaways.',
    emoji: '🎞️',
    color: Color(0xFFD32F2F),
  );

  static DifficultyConfig fromEnum(GameDifficulty d) {
    switch (d) {
      case GameDifficulty.easy: return easy;
      case GameDifficulty.medium: return medium;
      case GameDifficulty.hard: return hard;
    }
  }
}

// ─── GAME CLUE ─────────────────────────────────────────────────────────────────

class GameClue {
  final String type;    // 'plot', 'character', 'director', 'cast', 'fact', 'tagline'
  final String label;   // Display label e.g. "PLOT CLUE"
  final String content;

  const GameClue({
    required this.type,
    required this.label,
    required this.content,
  });
}

// ─── GAME ROUND ─────────────────────────────────────────────────────────────────

class GameRound {
  final int movieId;
  final String movieTitle;
  final String posterUrl;
  final String? backdropUrl;
  final String? directorName;
  final List<String> castNames;
  final String genre;
  final String year;
  final double rating;
  final String? interestingFact;

  // Mode-specific data
  final List<GameClue> clues;
  final String? dialogueQuote;
  final String? dialogueCharacter;
  final String? dialogueContext;

  // Mutable state
  int cluesRevealed;
  int wrongGuesses;
  bool isSolved;
  bool isSkipped;
  int? solvedAtClue; // 1-indexed clue number when solved

  GameRound({
    required this.movieId,
    required this.movieTitle,
    required this.posterUrl,
    this.backdropUrl,
    this.directorName,
    this.castNames = const [],
    this.genre = '',
    this.year = '',
    this.rating = 0.0,
    this.interestingFact,
    this.clues = const [],
    this.dialogueQuote,
    this.dialogueCharacter,
    this.dialogueContext,
    this.cluesRevealed = 0,
    this.wrongGuesses = 0,
    this.isSolved = false,
    this.isSkipped = false,
    this.solvedAtClue,
  });

  int computeScore(DifficultyConfig config) {
    if (!isSolved) return 0;
    const int base = 100;
    const int cluePenalty = 15;
    const int wrongPenalty = 10;
    final int penalty =
        (cluesRevealed > 1 ? (cluesRevealed - 1) * cluePenalty : 0) +
        (wrongGuesses * wrongPenalty);
    final int raw = (base - penalty).clamp(0, base);
    return (raw * config.scoreMultiplier).round();
  }
}

// ─── GAME SESSION ─────────────────────────────────────────────────────────────

class GameSession {
  final ChallengeType challengeType;
  final String? themeName;
  final String? themeEmoji;
  final GameDifficulty difficulty;
  final GuessMode guessMode;
  final List<GameRound> rounds;
  final DateTime startedAt;

  GameSession({
    required this.challengeType,
    this.themeName,
    this.themeEmoji,
    required this.difficulty,
    required this.guessMode,
    required this.rounds,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  int get currentRoundIndex =>
      rounds.indexWhere((r) => !r.isSolved && !r.isSkipped);

  bool get isComplete =>
      rounds.every((r) => r.isSolved || r.isSkipped);

  int get totalScore {
    final config = DifficultyConfig.fromEnum(difficulty);
    return rounds.fold(0, (sum, r) => sum + r.computeScore(config));
  }

  int get solvedCount => rounds.where((r) => r.isSolved).length;

  bool get isPerfectRun =>
      rounds.isNotEmpty &&
      rounds.every((r) => r.isSolved && r.wrongGuesses == 0);
}

// ─── GAME RESULT ───────────────────────────────────────────────────────────────

class GameResult {
  final ChallengeType challengeType;
  final String? themeName;
  final String? themeEmoji;
  final GameDifficulty difficulty;
  final GuessMode guessMode;
  final int totalScore;
  final int xpEarned;
  final String verdict;
  final DateTime playedAt;
  final int? streakDays;
  final bool isPerfectRun;
  final int solvedCount;
  final int totalRounds;
  final int? solvedAtClue; // For single-round (Quick Mix)
  final String? movieTitle;
  final String? posterUrl;
  final String? directorName;
  final String? genre;
  final String? year;
  final double? rating;
  final String? interestingFact;

  const GameResult({
    required this.challengeType,
    this.themeName,
    this.themeEmoji,
    required this.difficulty,
    required this.guessMode,
    required this.totalScore,
    required this.xpEarned,
    required this.verdict,
    required this.playedAt,
    this.streakDays,
    this.isPerfectRun = false,
    required this.solvedCount,
    required this.totalRounds,
    this.solvedAtClue,
    this.movieTitle,
    this.posterUrl,
    this.directorName,
    this.genre,
    this.year,
    this.rating,
    this.interestingFact,
  });

  Map<String, dynamic> toJson() => {
    'challengeType': challengeType.index,
    'themeName': themeName,
    'difficulty': difficulty.index,
    'guessMode': guessMode.index,
    'totalScore': totalScore,
    'xpEarned': xpEarned,
    'verdict': verdict,
    'playedAt': playedAt.toIso8601String(),
    'streakDays': streakDays,
    'isPerfectRun': isPerfectRun,
    'solvedCount': solvedCount,
    'totalRounds': totalRounds,
    'solvedAtClue': solvedAtClue,
    'movieTitle': movieTitle,
    'posterUrl': posterUrl,
  };
}

// ─── THEME CATEGORY ────────────────────────────────────────────────────────────

class ThemeCategory {
  final String id;
  final String name;
  final String emoji;
  final String group;
  final String description;

  // TMDB query parameters
  final List<int>? genreIds;
  final List<int>? keywordIds;
  final int? personId;
  final int? yearFrom;
  final int? yearTo;
  final String? sortBy;
  final String? withOriginCountry;
  final double? minVoteAverage;
  final int? minVoteCount;

  const ThemeCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.group,
    required this.description,
    this.genreIds,
    this.keywordIds,
    this.personId,
    this.yearFrom,
    this.yearTo,
    this.sortBy,
    this.withOriginCountry,
    this.minVoteAverage,
    this.minVoteCount,
  });
}

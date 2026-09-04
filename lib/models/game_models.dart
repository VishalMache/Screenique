import 'package:flutter/material.dart';

// ─── ENUMS ────────────────────────────────────────────────────────────────────

enum ChallengeType { quickMix, themed }

/// Kept for internal TMDB pool selection only — NOT shown to users
enum GameDifficulty { easy, medium, hard }

enum EvidenceType { plot, director, cast, dialogue, tagline, year, trivia }

// ─── EVIDENCE ─────────────────────────────────────────────────────────────────

class Evidence {
  final EvidenceType type;
  final String label;   // e.g. "PLOT", "DIRECTOR", "CAST"
  final String content;

  const Evidence({
    required this.type,
    required this.label,
    required this.content,
  });

  String get emoji {
    switch (type) {
      case EvidenceType.plot:      return '🎭';
      case EvidenceType.director:  return '🎬';
      case EvidenceType.cast:      return '👥';
      case EvidenceType.dialogue:  return '💬';
      case EvidenceType.tagline:   return '🔖';
      case EvidenceType.year:      return '📅';
      case EvidenceType.trivia:    return '🏆';
    }
  }
}

// ─── DIFFICULTY CONFIG (internal use only) ─────────────────────────────────────

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

  static const medium = DifficultyConfig(
    difficulty: GameDifficulty.medium,
    maxClues: 4,
    maxAttempts: 3,
    scoreMultiplier: 1.0,
    label: 'MEDIUM',
    description: 'Popular + moderately obscure movies.',
    emoji: '🎬',
    color: Color(0xFFFF9800),
  );

  static DifficultyConfig fromEnum(GameDifficulty d) {
    switch (d) {
      case GameDifficulty.easy:   return easy;
      case GameDifficulty.medium: return medium;
      case GameDifficulty.hard:   return hard;
    }
  }

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

  /// The 3–4 pieces of evidence for this round
  final List<Evidence> evidences;

  // Mutable state
  int evidencesRevealed;   // how many evidences the player has seen
  int wrongGuesses;
  bool isSolved;
  bool isSkipped;
  int? solvedAtEvidence;   // 1-indexed evidence number when solved
  int? solveTimeMs;        // time from round start to solve in ms

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
    this.evidences = const [],
    this.evidencesRevealed = 1,
    this.wrongGuesses = 0,
    this.isSolved = false,
    this.isSkipped = false,
    this.solvedAtEvidence,
    this.solveTimeMs,
  });

  /// Score based on which evidence the player solved on.
  /// 100 → 80 → 60 → 40 → 0, minus 5 per wrong guess
  int computeScore() {
    if (!isSolved) return 0;
    const baseScores = [100, 80, 60, 40];
    final evidenceIdx = (solvedAtEvidence ?? 1) - 1;
    final base = evidenceIdx < baseScores.length ? baseScores[evidenceIdx] : 0;
    final penalty = wrongGuesses * 5;
    return (base - penalty).clamp(0, 100);
  }
}

// ─── GAME SESSION ─────────────────────────────────────────────────────────────

class GameSession {
  final ChallengeType challengeType;
  final String? themeName;
  final String? themeEmoji;
  final List<GameRound> rounds; // Always 10
  final DateTime startedAt;

  GameSession({
    required this.challengeType,
    this.themeName,
    this.themeEmoji,
    required this.rounds,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  int get currentRoundIndex =>
      rounds.indexWhere((r) => !r.isSolved && !r.isSkipped);

  bool get isComplete =>
      rounds.every((r) => r.isSolved || r.isSkipped);

  int get totalScore =>
      rounds.fold(0, (sum, r) => sum + r.computeScore());

  int get solvedCount => rounds.where((r) => r.isSolved).length;

  bool get isPerfectRun =>
      rounds.isNotEmpty &&
      rounds.every((r) => r.isSolved && r.wrongGuesses == 0);

  double get avgEvidenceUsed {
    final solved = rounds.where((r) => r.isSolved && r.solvedAtEvidence != null).toList();
    if (solved.isEmpty) return 0;
    return solved.map((r) => r.solvedAtEvidence!).reduce((a, b) => a + b) / solved.length;
  }

  int get bestRoundScore =>
      rounds.map((r) => r.computeScore()).fold(0, (a, b) => a > b ? a : b);

  int? get fastestSolveMs {
    final times = rounds
        .where((r) => r.isSolved && r.solveTimeMs != null)
        .map((r) => r.solveTimeMs!)
        .toList();
    if (times.isEmpty) return null;
    return times.reduce((a, b) => a < b ? a : b);
  }
}

// ─── GAME RESULT ───────────────────────────────────────────────────────────────

class GameResult {
  final ChallengeType challengeType;
  final String? themeName;
  final String? themeEmoji;
  final int totalScore;
  final int xpEarned;
  final String verdict;
  final String verdictLabel; // e.g. "CINEPHILE INSTINCT"
  final DateTime playedAt;
  final int? streakDays;
  final bool isPerfectRun;
  final int solvedCount;
  final int totalRounds;

  // Session-wide stats
  final double avgEvidenceUsed;
  final int bestRoundScore;
  final int? fastestSolveMs;

  // Per-round snapshots (for share card, etc.)
  final List<GameRound> rounds;

  const GameResult({
    required this.challengeType,
    this.themeName,
    this.themeEmoji,
    required this.totalScore,
    required this.xpEarned,
    required this.verdict,
    required this.verdictLabel,
    required this.playedAt,
    this.streakDays,
    this.isPerfectRun = false,
    required this.solvedCount,
    required this.totalRounds,
    this.avgEvidenceUsed = 0,
    this.bestRoundScore = 0,
    this.fastestSolveMs,
    this.rounds = const [],
  });

  Map<String, dynamic> toJson() => {
    'challengeType': challengeType.index,
    'themeName': themeName,
    'totalScore': totalScore,
    'xpEarned': xpEarned,
    'verdict': verdict,
    'playedAt': playedAt.toIso8601String(),
    'streakDays': streakDays,
    'isPerfectRun': isPerfectRun,
    'solvedCount': solvedCount,
    'totalRounds': totalRounds,
    'avgEvidenceUsed': avgEvidenceUsed,
    'bestRoundScore': bestRoundScore,
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

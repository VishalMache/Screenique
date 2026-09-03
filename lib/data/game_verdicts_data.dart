import 'dart:math';
import '../models/game_models.dart';

/// Cinematic verdicts dynamically selected based on game performance.
/// The [getVerdict] function picks the best matching verdict.
class GameVerdicts {
  static String getVerdict({
    required int score,
    required int maxScore,
    required int cluesUsed,
    required int maxClues,
    required int wrongGuesses,
    required GameDifficulty difficulty,
    required int streakDays,
    required bool isSolved,
  }) {
    final double pct = maxScore > 0 ? score / maxScore : 0.0;
    final bool usedFirstClue = cluesUsed <= 1;
    final bool usedManyClues = cluesUsed >= maxClues;
    final bool noWrongGuesses = wrongGuesses == 0;
    final bool isHard = difficulty == GameDifficulty.hard;
    final bool isOnStreak = streakDays >= 5;

    // Perfect scenarios
    if (isSolved && usedFirstClue && noWrongGuesses && isHard) {
      return "Okay, we found the film nerd.";
    }
    if (isSolved && usedFirstClue && noWrongGuesses) {
      return "The opening credits hadn't even finished.";
    }
    if (isSolved && pct >= 0.95 && noWrongGuesses) {
      return "You didn't watch the movie. You studied it.";
    }
    if (isSolved && pct >= 0.90 && noWrongGuesses) {
      return "Blink and you would've missed it.";
    }

    // Streak-based
    if (isSolved && isOnStreak && pct >= 0.80) {
      return "Consistency is the mark of a true cinephile.";
    }

    // Hard mode specific
    if (isSolved && isHard && pct >= 0.80) {
      return "The hard road taken. The right answer found.";
    }
    if (isSolved && isHard && pct >= 0.60) {
      return "Niche cinema doesn't scare you. Respect.";
    }

    // Score tiers
    if (isSolved && pct >= 0.85) {
      return "A true cinephile knows when to trust their instinct.";
    }
    if (isSolved && pct >= 0.70) {
      return "You knew it. You just needed a little convincing.";
    }
    if (isSolved && pct >= 0.50) {
      return "The clues did most of the acting today.";
    }
    if (isSolved && usedManyClues) {
      return "Patience is a cinephile's superpower.";
    }
    if (isSolved && wrongGuesses >= 2) {
      return "Every masterpiece deserves a second watch.";
    }
    if (isSolved) {
      return "Every clue is a frame. You found the film.";
    }

    // Failed scenarios
    if (!isSolved && isHard) {
      return "Even the hardest films have their admirers. Keep going.";
    }
    if (!isSolved) {
      return "Perhaps tonight is movie night.";
    }

    return "Every film leaves a clue. You'll find it next time.";
  }

  /// Returns a random cinematic quote used as ambient flavor text on the hub screen.
  static String randomAmbientQuote() {
    final quotes = [
      "Cinema is a matter of what's in the frame and what's out.",
      "Every movie tells a story. Can you read between the frames?",
      "The best films linger long after the credits roll.",
      "A film is — or should be — more direct and more immediate than the printed word.",
      "Cinema is the most beautiful fraud in the world.",
      "The job of the director is to make the audience feel what you want them to feel.",
    ];
    return quotes[Random().nextInt(quotes.length)];
  }
}

import 'dart:math';
import '../models/taste_profile_model.dart';

enum UserState { new_, medium, strong }

class BotChip {
  final String text;
  final String category;

  const BotChip({required this.text, required this.category});
}

class OnboardingEngine {
  static final Random _random = Random();

  /// Determine user state based on their profile maturity (watched count)
  static UserState _getUserState(UserTasteProfile? profile) {
    if (profile == null || profile.watchedCount == 0) return UserState.new_;
    if (profile.watchedCount <= 10) return UserState.medium;
    return UserState.strong;
  }

  /// Get the randomized welcome message based on the user's state
  static String getWelcomeMessage(UserTasteProfile? profile) {
    final state = _getUserState(profile);
    
    switch (state) {
      case UserState.new_:
        final newMessages = [
          "Aaj kya mood hai — comfort, chaos, ya full cinema?",
          "Tell me your vibe and I’ll pick the movie.",
          "Welcome to the projection room. What are we watching today?",
          "Give me a mood, an actor, or an era. I'll do the rest.",
          "First time here? Let's start with a classic or something completely unhinged."
        ];
        return newMessages[_random.nextInt(newMessages.length)];
        
      case UserState.medium:
        final mediumMessages = [
          "Back again? I’ve got a few dangerous picks for your taste.",
          "Your taste profile is taking shape. Ready to go deeper?",
          "I see what you like. Want something safe or something that challenges you?",
          "Welcome back! I have a few underrated gems queued up for you.",
          "Let's build on what you watched last time. What's the mood?"
        ];
        return mediumMessages[_random.nextInt(mediumMessages.length)];
        
      case UserState.strong:
        final strongMessages = [
          "Want the safe pick or the one that ruins your night in a good way?",
          "Your taste is impeccable. Let's find something worthy of it.",
          "I have some deep cuts curated specifically for your profile.",
          "Master cinephile is back. Trust me with a blind pick?",
          "We know exactly what you like. Say the word."
        ];
        return strongMessages[_random.nextInt(strongMessages.length)];
    }
  }

  /// Get the dynamic chip composition based on the user's state
  static List<BotChip> getWelcomeChips(UserTasteProfile? profile) {
    final state = _getUserState(profile);

    // Core taxonomies
    final moodBroad = ["Mind-bending", "Easy watch", "Dark & gripping", "Cozy comfort"];
    final discoveryBroad = ["Underrated gem", "Hidden masterpiece", "Foreign classic"];
    final similarityBroad = ["Like a movie I loved", "Director's best work"];
    final constraintBroad = ["Under 2 hours", "Fast-paced", "Slow burn"];
    final surpriseBroad = ["Surprise me", "You choose for me", "Blind pick"];
    
    final playful = ["Ruins my night", "Make me cry", "Guilty pleasure"];
    
    // Future Phase: Generate personalized chips based on `profile.topGenres` etc.
    final personalized = ["Based on your favorites", "Top tier thriller", "Action masterpiece"]; 
    final continuation = ["Go darker", "More intense", "Lighter tone"];

    List<BotChip> selectedChips = [];

    switch (state) {
      case UserState.new_:
        // Simple First Version overrides the strict logic to ensure specific UI for now:
        // "Underrated gem", "Mind-bending", "Easy watch", "Under 2 hours", "Like a movie I loved", "Surprise me"
        return [
          const BotChip(text: "Underrated gem", category: "discovery"),
          const BotChip(text: "Mind-bending", category: "mood"),
          const BotChip(text: "Easy watch", category: "mood"),
          const BotChip(text: "Under 2 hours", category: "constraint"),
          const BotChip(text: "Like a movie I loved", category: "similarity"),
          const BotChip(text: "Surprise me", category: "surprise"),
        ];

      case UserState.medium:
        // 3 broad + 2 taste-based + 1 surprise
        selectedChips = [
          BotChip(text: _pickRandom(moodBroad), category: "mood"),
          BotChip(text: _pickRandom(constraintBroad), category: "constraint"),
          BotChip(text: _pickRandom(discoveryBroad), category: "discovery"),
          BotChip(text: _pickRandom(personalized), category: "taste"),
          BotChip(text: _pickRandom(personalized), category: "taste"),
          BotChip(text: _pickRandom(surpriseBroad), category: "surprise"),
        ];
        break;

      case UserState.strong:
        // 2 broad + 3 personalized + 1 continuation
        selectedChips = [
          BotChip(text: _pickRandom(moodBroad), category: "mood"),
          BotChip(text: _pickRandom(discoveryBroad), category: "discovery"),
          BotChip(text: _pickRandom(personalized), category: "taste"),
          BotChip(text: _pickRandom(personalized), category: "taste"),
          BotChip(text: _pickRandom(personalized), category: "taste"),
          BotChip(text: _pickRandom(continuation), category: "continuation"),
        ];
        break;
    }

    // Ensure we don't return duplicates if random picks hit the same item
    final uniqueChips = <String, BotChip>{};
    for (var chip in selectedChips) {
      uniqueChips[chip.text] = chip;
    }
    return uniqueChips.values.toList();
  }

  static String _pickRandom(List<String> list) {
    return list[_random.nextInt(list.length)];
  }
}

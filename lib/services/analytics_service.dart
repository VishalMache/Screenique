/// AnalyticsService — Centralized Firebase Analytics event tracker for Screenique.
/// Phase 4: Tracks recommendation interactions, bot engagement, and feedback signals.
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // ─────────────── RECOMMENDATION EVENTS ───────────────

  /// User taps on a recommendation card.
  static Future<void> logRecClicked({
    required String movieTitle,
    required String carouselSection,
    double? matchScore,
  }) async {
    await _analytics.logEvent(
      name: 'rec_clicked',
      parameters: {
        'movie_title': movieTitle,
        'carousel_section': carouselSection,
        if (matchScore != null) 'match_score': matchScore.toStringAsFixed(2),
      },
    );
  }

  /// User adds a rec to watchlist or marks as watched.
  static Future<void> logRecAddToList({
    required String movieTitle,
    required String listType, // 'watchlist' | 'watched'
  }) async {
    await _analytics.logEvent(
      name: 'rec_add_to_list',
      parameters: {
        'movie_title': movieTitle,
        'list_type': listType,
      },
    );
  }

  /// User permanently dismisses a rec.
  static Future<void> logRecDismissed({required String movieTitle}) async {
    await _analytics.logEvent(
      name: 'rec_dismissed',
      parameters: {'movie_title': movieTitle},
    );
  }

  /// User gives thumbs up or down feedback on a rec.
  static Future<void> logRecFeedback({
    required String movieTitle,
    required String feedback, // 'up' | 'down'
  }) async {
    await _analytics.logEvent(
      name: 'rec_feedback_thumb',
      parameters: {
        'movie_title': movieTitle,
        'feedback': feedback,
      },
    );
  }

  // ─────────────── BOT EVENTS ───────────────

  /// User opens the Screenu bot chat.
  static Future<void> logBotOpened() async {
    await _analytics.logEvent(name: 'bot_opened');
  }

  /// User sends a message to the bot.
  static Future<void> logBotMessageSent({String? querySnippet}) async {
    await _analytics.logEvent(
      name: 'bot_message_sent',
      parameters: {
        if (querySnippet != null) 'query_snippet': querySnippet.substring(0, querySnippet.length.clamp(0, 40)),
      },
    );
  }

  /// User taps a movie card embedded in a bot response.
  static Future<void> logBotRecTapped({required String movieTitle}) async {
    await _analytics.logEvent(
      name: 'bot_rec_tapped',
      parameters: {'movie_title': movieTitle},
    );
  }

  /// Bot shows a dynamic welcome message
  static Future<void> logBotWelcomeShown({
    required String userState,
    required String welcomeText,
  }) async {
    await _analytics.logEvent(
      name: 'bot_welcome_shown',
      parameters: {
        'user_state': userState,
        'welcome_text': welcomeText.substring(0, welcomeText.length.clamp(0, 40)),
      },
    );
  }

  /// User taps an onboarding or dynamic chip
  static Future<void> logBotChipTapped({
    required String chipText,
    required String category,
    required String userState,
  }) async {
    await _analytics.logEvent(
      name: 'bot_chip_tapped',
      parameters: {
        'chip_text': chipText.substring(0, chipText.length.clamp(0, 40)),
        'category': category,
        'user_state': userState,
      },
    );
  }
}

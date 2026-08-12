/// AppSecrets — Runtime key provider via Firebase Remote Config.
///
/// Keys are NEVER bundled in the APK. They are fetched from Firebase Remote
/// Config at startup, which means they can be rotated at any time from the
/// Firebase console without shipping a new app build.
///
/// Required Remote Config keys (set these in the Firebase console):
///   GROQ_API_KEY   — your Groq LLM / Whisper key (billable, keep server-side)
///   TMDB_API_KEY   — TMDB API key (read-only, low risk)
///
/// Setup steps (one-time):
///   1. Firebase Console → Remote Config → Add parameter → GROQ_API_KEY
///   2. Firebase Console → Remote Config → Add parameter → TMDB_API_KEY
///   3. Click "Publish changes"
///   4. Call AppSecrets.init() once after Firebase.initializeApp()
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class AppSecrets {
  AppSecrets._(); // prevent instantiation

  static String _groqApiKey = '';
  static String _tmdbApiKey = '';

  /// Must be called once after [Firebase.initializeApp()].
  static Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;

      await rc.setConfigSettings(RemoteConfigSettings(
        // In production, use a longer interval (e.g. 1 hour).
        // During development you can lower this.
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Set empty-string defaults so the app does not crash before the first
      // successful Remote Config fetch (e.g. no network on first launch).
      await rc.setDefaults(const {
        'GROQ_API_KEY': '',
        'TMDB_API_KEY': '',
      });

      await rc.fetchAndActivate();

      _groqApiKey = rc.getString('GROQ_API_KEY');
      _tmdbApiKey = rc.getString('TMDB_API_KEY');

      if (_groqApiKey.isEmpty) {
        debugPrint('[AppSecrets] WARNING: GROQ_API_KEY is empty. '
            'Have you published it in Firebase Remote Config?');
      }
      if (_tmdbApiKey.isEmpty) {
        debugPrint('[AppSecrets] WARNING: TMDB_API_KEY is empty. '
            'Have you published it in Firebase Remote Config?');
      }
    } catch (e) {
      // Remote Config fetch failed (e.g. offline). Keys remain empty strings.
      // The app will gracefully degrade (bot/movie services will return errors).
      debugPrint('[AppSecrets] Remote Config fetch failed: $e');
    }
  }

  /// The Groq LLM / Whisper API key.
  /// Returns an empty string if [init()] has not been called or fetch failed.
  static String get groqApiKey => _groqApiKey;

  /// The TMDB API key.
  /// Returns an empty string if [init()] has not been called or fetch failed.
  static String get tmdbApiKey => _tmdbApiKey;
}

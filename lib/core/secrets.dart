import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppSecrets {
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get tmdbApiKey => dotenv.env['TMDB_API_KEY'] ?? '';
}

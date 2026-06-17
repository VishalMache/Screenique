import '../../core/secrets.dart';

class ApiConstants {
  static String get apiKey => AppSecrets.tmdbApiKey;
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';
}
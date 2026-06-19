import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final title = 'Inception';
  final yearStr = '2010';
  final apiKey = '0d938d52f1a549ac4ad887eb076430ab';

  try {
    final query = Uri.encodeComponent(title);
    final url = 'https://api.themoviedb.org/3/search/multi?api_key=$apiKey&query=$query';
    print('Requesting: $url');
    final tmdbRes = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
    
    print('Status: ${tmdbRes.statusCode}');
    if (tmdbRes.statusCode == 200) {
      final tmdbData = jsonDecode(tmdbRes.body);
      final results = tmdbData['results'] as List;
      print('Results count: ${results.length}');
      if (results.isNotEmpty) {
        var bestMatch = results.firstWhere(
          (r) => (r['media_type'] == 'movie' || r['media_type'] == 'tv') && 
                 ((r['release_date'] ?? r['first_air_date'] ?? '').toString().startsWith(yearStr)),
          orElse: () => results.firstWhere(
            (r) => r['media_type'] == 'movie' || r['media_type'] == 'tv', 
            orElse: () => results.first
          )
        );

        print('Best Match Title: ${bestMatch['title'] ?? bestMatch['name']}');
        print('Best Match Poster: ${bestMatch['poster_path']}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

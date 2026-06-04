import 'package:html/parser.dart' show parse;

class NewsItem {
  final String id;
  final String title;
  final String snippet;
  final String sourceName;
  final String articleUrl;
  final String? imageUrl;
  final DateTime publishedAt;
  final String region; // 'Hollywood', 'Bollywood', etc.
  int? tmdbMatchId;
  String? tmdbMatchTitle;
  bool? tmdbMatchIsTv;

  NewsItem({
    required this.id,
    required this.title,
    required this.snippet,
    required this.sourceName,
    required this.articleUrl,
    this.imageUrl,
    required this.publishedAt,
    this.region = 'Hollywood',
    this.tmdbMatchId,
    this.tmdbMatchTitle,
    this.tmdbMatchIsTv,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'snippet': snippet,
      'sourceName': sourceName,
      'articleUrl': articleUrl,
      'imageUrl': imageUrl,
      'publishedAt': publishedAt.toIso8601String(),
      'region': region,
      'tmdbMatchId': tmdbMatchId,
      'tmdbMatchTitle': tmdbMatchTitle,
      'tmdbMatchIsTv': tmdbMatchIsTv,
    };
  }

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'],
      title: json['title'],
      snippet: json['snippet'],
      sourceName: json['sourceName'],
      articleUrl: json['articleUrl'],
      imageUrl: json['imageUrl'],
      publishedAt: DateTime.parse(json['publishedAt']),
      region: json['region'] ?? 'Hollywood',
      tmdbMatchId: json['tmdbMatchId'],
      tmdbMatchTitle: json['tmdbMatchTitle'],
      tmdbMatchIsTv: json['tmdbMatchIsTv'],
    );
  }

  static String stripHtml(String htmlString) {
    final document = parse(htmlString);
    final String parsedString = parse(document.body?.text).documentElement?.text ?? '';
    return parsedString.trim();
  }
}

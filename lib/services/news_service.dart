import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';
import '../models/news_item.dart';
import 'movie_service.dart';

class _FeedSource {
  final String name;
  final String url;
  final String region;
  const _FeedSource(this.name, this.url, this.region);
}

class NewsService {
  static const List<_FeedSource> _sources = [
    _FeedSource('Variety', 'https://variety.com/feed/', 'HOLLYWOOD'),
    _FeedSource('Deadline', 'https://deadline.com/feed/', 'HOLLYWOOD'),
    _FeedSource('The Hollywood Reporter', 'https://www.hollywoodreporter.com/feed/', 'HOLLYWOOD'),
    _FeedSource('IndieWire', 'https://www.indiewire.com/feed/', 'HOLLYWOOD'),
    _FeedSource('RogerEbert.com', 'https://www.rogerebert.com/feed', 'HOLLYWOOD'),
    _FeedSource('Bollywood Hungama', 'https://www.bollywoodhungama.com/rss/news.xml', 'INDIAN CINEMA'),
    _FeedSource('News18 Movies', 'https://www.news18.com/rss/movies.xml', 'INDIAN CINEMA'),
    _FeedSource('Crunchyroll News', 'https://cr-news-api-service.prd.crunchyrollsvc.com/v1/en-US/rss', 'ANIME'),
    _FeedSource('Comic Book Resources', 'https://www.cbr.com/feed/', 'MARVEL'),
  ];

  static const String _cacheKey = 'news_cache_items_v5';
  static const String _cacheTimeKey = 'news_cache_timestamp_v5';

  final MovieService _movieService = MovieService();

  Future<List<NewsItem>> fetchAndMerge({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!forceRefresh) {
      final cachedTimeStr = prefs.getString(_cacheTimeKey);
      if (cachedTimeStr != null) {
        final cachedTime = DateTime.parse(cachedTimeStr);
        if (DateTime.now().difference(cachedTime).inHours < 1) {
          final cachedData = prefs.getString(_cacheKey);
          if (cachedData != null) {
            try {
              final List decoded = json.decode(cachedData);
              return decoded.map((e) => NewsItem.fromJson(e)).toList();
            } catch (e) {
              debugPrint('Error parsing cached news: $e');
            }
          }
        }
      }
    }

    // Fetch in parallel
    final responses = await Future.wait(
      _sources.map((source) => _fetchOneFeed(source)),
    );

    List<NewsItem> allItems = [];
    for (var list in responses) {
      if (list != null) {
        allItems.addAll(list);
      }
    }

    // Sort by descending
    allItems.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    // Deduplicate by URL
    final seenUrls = <String>{};
    allItems = allItems.where((item) {
      if (seenUrls.contains(item.articleUrl)) return false;
      seenUrls.add(item.articleUrl);
      return true;
    }).toList();

    // TMDB match
    await _tmdbTitleMatch(allItems);

    // Save to cache
    try {
      final encoded = json.encode(allItems.map((e) => e.toJson()).toList());
      await prefs.setString(_cacheKey, encoded);
      await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error caching news: $e');
    }

    return allItems;
  }

  Future<List<NewsItem>?> _fetchOneFeed(_FeedSource source) async {
    try {
      final response = await http.get(Uri.parse(source.url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        
        List<NewsItem> feedItems = [];
        for (var node in items) {
          final title = node.findElements('title').firstOrNull?.innerText ?? '';
          final link = node.findElements('link').firstOrNull?.innerText ?? '';
          final pubDateStr = node.findElements('pubDate').firstOrNull?.innerText ?? '';
          String description = node.findElements('description').firstOrNull?.innerText ?? '';
          
          DateTime publishedAt = DateTime.now();
          try {
            // Note: RSS dates are RFC822, might need parsing logic or try parse. For simplicity we try parsing as is
            // Many Dart date parsers handle it, but fallback if not
            // We can also just ignore parse errors and use now() or sort string.
            // Dart's DateTime doesn't natively parse RFC-2822. 
            // So we'll try a rough fallback:
            publishedAt = _parseRssDate(pubDateStr) ?? DateTime.now();
          } catch (_) {}

          // Image extraction
          String? imageUrl;
          final mediaContent = node.findElements('media:content').firstOrNull ?? node.findElements('media:thumbnail').firstOrNull;
          if (mediaContent != null) {
            imageUrl = mediaContent.getAttribute('url');
          } else {
            final enclosure = node.findElements('enclosure').firstOrNull;
            if (enclosure != null && enclosure.getAttribute('type')?.startsWith('image') == true) {
              imageUrl = enclosure.getAttribute('url');
            } else {
              // Try regex in description
              final match = RegExp(r'src="([^"]+)"').firstMatch(description);
              if (match != null) {
                imageUrl = match.group(1);
              }
            }
          }

          final snippet = NewsItem.stripHtml(description);
          final id = link.hashCode.toString();

          if (title.isNotEmpty && link.isNotEmpty) {
            if (source.region == 'MARVEL') {
              final text = (title + description).toLowerCase();
              if (!text.contains('marvel') && !text.contains('mcu') && !text.contains('avengers') && !text.contains('x-men') && !text.contains('spider-man') && !text.contains('deadpool')) {
                continue;
              }
            }

            feedItems.add(NewsItem(
              id: id,
              title: title,
              snippet: snippet.length > 200 ? '${snippet.substring(0, 200)}...' : snippet,
              sourceName: source.name,
              articleUrl: link,
              imageUrl: imageUrl,
              publishedAt: publishedAt,
              region: source.region,
            ));
          }
        }
        return feedItems;
      }
    } catch (e) {
      debugPrint('Failed to fetch ${source.name}: $e');
    }
    return null;
  }

  DateTime? _parseRssDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    // Basic RFC 822 parsing attempt. Better approaches exist but this is often enough.
    // E.g., "Wed, 02 Oct 2002 13:00:00 GMT"
    try {
      // It's tricky to parse without intl or standard lib. We will just return null and fallback if complex.
      // Often, a crude RegExp can rip out the parts:
      final regex = RegExp(r'(\d{1,2}) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})');
      final match = regex.firstMatch(dateStr);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final monthStr = match.group(2)!;
        final year = int.parse(match.group(3)!);
        final hour = int.parse(match.group(4)!);
        final minute = int.parse(match.group(5)!);
        final second = int.parse(match.group(6)!);
        
        const months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};
        final month = months[monthStr] ?? 1;
        return DateTime.utc(year, month, day, hour, minute, second);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _tmdbTitleMatch(List<NewsItem> items) async {
    // Only process top items to avoid massive API spam
    final toProcess = items.take(15).toList();
    
    await Future.wait(toProcess.map((item) async {
      // Simple capitalization regex to catch movie titles like "Oppenheimer" or "The Dark Knight"
      final match = RegExp(r'([A-Z][a-z]+ (?:[A-Z][a-z]+ ){1,3}(?:2|3|4|II|III)?|["' + "'" + r'][^"' + "'" + r']{4,40}["' + "'" + r'])').firstMatch(item.title);
      if (match != null) {
        String candidate = match.group(1)!;
        candidate = candidate.replaceAll('"', '').replaceAll("'", '').trim();
        
        if (candidate.length > 3) {
          try {
            final results = await _movieService.searchAll(candidate);
            if (results.isNotEmpty) {
              final top = results.first;
              // A rough heuristic for confidence: it's a valid hit if they have similar words
              // We won't be too strict here, but we will ensure it's not a person.
              if (!top.isPerson) {
                item.tmdbMatchId = top.id;
                item.tmdbMatchTitle = top.title;
                item.tmdbMatchIsTv = top.isTvShow;
              }
            }
          } catch (_) {}
        }
      }
    }));
  }

  Future<void> invalidateCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
  }
}

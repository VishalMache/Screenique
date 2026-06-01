import 'package:flutter/material.dart';

class MovieModel {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final double voteAverage;
  final String releaseDate;
  final List<int> genreIds;
  final bool isTvShow;

  // NEW: Search & Profile Logic Fields
  final bool isPerson; // Distinguishes Director/Actor from Film
  final String? director;
  final String? biography; // For Director Profile

  // Experience Fields for the "Vault"
  final String? ticketImageUrl;
  final String? cinemaName;
  final String? personalNote;
  final String? companions;
  final String? watchedDate;

  // Community Broadcast Fields
  final String? broadcastReason;
  final String? broadcastSender;
  final String? senderId;
  final int? senderRankCount;

  // Unified Genre Map
  static const Map<int, String> genreMap = {
    28: 'Action', 12: 'Adventure', 16: 'Animation', 35: 'Comedy',
    80: 'Crime', 99: 'Documentary', 18: 'Drama', 10751: 'Family',
    14: 'Fantasy', 36: 'History', 27: 'Horror', 10402: 'Music',
    9648: 'Mystery', 10749: 'Romance', 878: 'Sci-Fi', 10770: 'TV Movie',
    53: 'Thriller', 10752: 'War', 37: 'Western',
    10759: 'Action & Adventure', 10762: 'Kids', 10763: 'News',
    10764: 'Reality', 10765: 'Sci-Fi & Fantasy', 10766: 'Soap',
    10767: 'Talk', 10768: 'War & Politics',
  };

  MovieModel({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.voteAverage,
    required this.releaseDate,
    required this.genreIds,
    this.isTvShow = false,
    this.isPerson = false, // Default to false
    this.director,
    this.biography,
    this.ticketImageUrl,
    this.cinemaName,
    this.personalNote,
    this.companions,
    this.watchedDate,
    this.broadcastReason,
    this.broadcastSender,
    this.senderId,
    this.senderRankCount,
  });

  String get genreNames {
    if (isPerson) return 'Director / Actor';
    if (genreIds.isEmpty) return 'Unknown';
    return genreIds
        .map((id) => genreMap[id])
        .where((name) => name != null)
        .join(', ');
  }

  factory MovieModel.fromJson(Map<String, dynamic> json) {
    // Detect if the result is a person (Director/Actor)
    bool isPersonType = json['media_type'] == 'person' || json['isPerson'] == true;

    bool isTv = !isPersonType && (
        json['media_type'] == 'tv' ||
        json['name'] != null ||
        json['first_air_date'] != null ||
        (json['isTvShow'] == true)
    );

    // Extract director name if available in credits
// Inside MovieModel.fromJson
    String? directorName = json['director'];
    
    // Use '?' to safely check for credits before accessing crew
    if (directorName == null && json['credits'] != null && json['credits']['crew'] != null) {
      final List crew = json['credits']['crew'];
      final dir = crew.firstWhere(
        (m) => m['job'] == 'Director',
        orElse: () => null,
      );
      directorName = dir?['name'];
    }

    return MovieModel(
      id: json['id'] is String ? int.parse(json['id']) : (json['id'] != null ? json['id'] : (json['movieId'] != null ? int.tryParse(json['movieId'].toString()) ?? 0 : 0)),
      title: json['title'] ?? json['name'] ?? 'Unknown',
      overview: json['overview'] ?? json['biography'] ?? '',
      isPerson: isPersonType,
      biography: json['biography'],
      // Logic for Poster vs Profile Path
      posterPath: json['posterPath'] ?? (
          json['poster_path'] != null 
          ? 'https://images.tmdb.org/t/p/w500${json['poster_path']}' 
          : (json['profile_path'] != null 
             ? 'https://images.tmdb.org/t/p/w500${json['profile_path']}' 
             : '')
      ),
      voteAverage: (json['vote_average'] ?? json['voteAverage'] ?? 0.0).toDouble(),
      releaseDate: json['release_date'] ?? json['first_air_date'] ?? json['releaseDate'] ?? 'N/A',
      genreIds: List<int>.from(json['genre_ids'] ?? json['genreIds'] ?? []),
      isTvShow: isTv,
      director: directorName,
      ticketImageUrl: json['ticketImageUrl'],
      cinemaName: json['cinemaName'],
      personalNote: json['personalNote'],
      companions: json['companions'],
      watchedDate: json['watchedDate'],
      broadcastReason: json['reason'] ?? json['broadcastReason'],
      broadcastSender: json['senderName'] ?? json['broadcastSender'],
      senderId: json['senderId'],
      senderRankCount: json['senderRankCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'isPerson': isPerson,
      'biography': biography,
      'posterPath': posterPath,
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'genreIds': genreIds,
      'isTvShow': isTvShow,
      'director': director,
      'ticketImageUrl': ticketImageUrl,
      'cinemaName': cinemaName,
      'personalNote': personalNote,
      'companions': companions,
      'watchedDate': watchedDate,
      'reason': broadcastReason,
      'senderName': broadcastSender,
      'senderId': senderId,
      'senderRankCount': senderRankCount,
    };
  }
}

// Rank utility remains unchanged
class ArchiveRank {
  static String getTitle(int count) {
    if (count >= 100) return "LEGENDARY PRODUCER";
    if (count >= 50) return "MASTER CINEPHILE";
    if (count >= 20) return "SENIOR ARCHIVIST";
    if (count >= 5) return "FILM ENTHUSIAST";
    return "NOVICE OBSERVER";
  }

  static Color getColor(int count) {
    if (count >= 50) return const Color(0xFFD32F2F);
    if (count >= 20) return Colors.amber;
    if (count >= 5) return Colors.blueAccent;
    return Colors.white24;
  }
}
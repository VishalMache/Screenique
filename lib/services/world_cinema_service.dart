import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/movie_model.dart';
import '../core/secrets.dart';

class WorldCinemaService {
  String get _apiKey => AppSecrets.tmdbApiKey;
  final String _baseUrl = 'https://api.tmdb.org/3';
  
  // In-RAM Caches
  final Map<String, List<MovieModel>> _movieCache = {};
  final Map<String, List<MovieModel>> _tvCache = {};
  final Map<String, List<Map<String, dynamic>>> _directorCache = {};
  final Map<String, List<Map<String, dynamic>>> _actorCache = {};
  
  Future<List<MovieModel>> getTopFilmsByCountry(String iso) async {
    if (_movieCache.containsKey(iso)) return _movieCache[iso]!;
    
    try {
      final response = await http.get(Uri.parse(
        '$_baseUrl/discover/movie?api_key=$_apiKey&with_origin_country=$iso&sort_by=vote_count.desc'
      )).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final List results = json.decode(response.body)['results'] ?? [];
        final movies = results.map((m) => MovieModel.fromJson({...m, 'isPerson': false, 'media_type': 'movie', 'originCountry': iso})).toList();
        _movieCache[iso] = movies;
        return movies;
      }
    } catch (e) {
      debugPrint("Error fetching top films for $iso: $e");
    }
    return [];
  }

  Future<List<MovieModel>> getTopTvByCountry(String iso) async {
    if (_tvCache.containsKey(iso)) return _tvCache[iso]!;
    
    try {
      final response = await http.get(Uri.parse(
        '$_baseUrl/discover/tv?api_key=$_apiKey&with_origin_country=$iso&sort_by=vote_count.desc'
      )).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final List results = json.decode(response.body)['results'] ?? [];
        final shows = results.map((m) => MovieModel.fromJson({...m, 'isPerson': false, 'media_type': 'tv', 'originCountry': iso})).toList();
        _tvCache[iso] = shows;
        return shows;
      }
    } catch (e) {
      debugPrint("Error fetching top TV for $iso: $e");
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getIconicDirectors(String iso) async {
    if (_directorCache.containsKey(iso)) return _directorCache[iso]!;
    
    try {
      final response = await http.get(Uri.parse(
        '$_baseUrl/person/popular?api_key=$_apiKey&language=en-US'
      )).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        // TMDB doesn't have a direct "nationality" filter for persons that works well.
        // For phase 1, we rely heavily on the curated list (which we will implement next).
        // If not in curated list, we return empty so UI shows "No data".
        return [];
      }
    } catch (e) {
      debugPrint("Error fetching directors for $iso: $e");
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getIconicActors(String iso) async {
    if (_actorCache.containsKey(iso)) return _actorCache[iso]!;
    return [];
  }

  Future<int> getWatchedCountForCountry(String iso) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('movies')
          .where('status', isEqualTo: 'watched')
          .where('originCountry', isEqualTo: iso)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint("Error getting watched count for $iso: $e");
      return 0;
    }
  }

  Future<Set<String>> getExploredCountries() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    
    try {
      // Query all watched movies. To scale, this might need optimization later,
      // but Firestore handles thousands of docs smoothly.
      final snapshot = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('movies')
          .where('status', isEqualTo: 'watched')
          .get();
          
      final Set<String> explored = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['originCountry'] != null && data['originCountry'].toString().isNotEmpty) {
          explored.add(data['originCountry'].toString());
        }
      }
      return explored;
    } catch (e) {
      debugPrint("Error getting explored countries: $e");
      return {};
    }
  }
}

class EditorialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  EditorialService();

  Future<String> getOrGenerateEditorial(String countryCode, String countryName) async {
    // 1. Hardcoded Editorials for Major Cinematic Nations
    const Map<String, String> _editorials = {
      'IN': "Indian cinema is a kaleidoscope of vibrant storytelling, blending mythic grandeur with visceral emotion. From the golden era of parallel cinema to the explosive maximalism of modern blockbusters, it is a landscape defined by musicality, dramatic spectacle, and a profound reflection of the subcontinent's diverse soul.",
      'US': "American cinema is the great myth-maker of the modern age. Rooted in the pioneering spirit of Hollywood's studio system, it continues to define global pop culture through sweeping epics, relentless innovation, and a constant reinvention of its own deeply ingrained genres—from the gritty neo-noirs to the colossal blockbusters.",
      'FR': "French cinema operates at the intersection of philosophy and romance. Birthplace of the auteur theory and the revolutionary Nouvelle Vague, its films are characterized by an intoxicating blend of existential longing, formal daring, and an unapologetic celebration of human intimacy and intellectual pursuit.",
      'IT': "Italian cinema is the raw beating heart of European film. Emerging from the ashes of Neorealism with unvarnished truth, it evolved into a canvas for surrealist masters and operatic maestros. It is a cinema of striking visual poetry, profound historical weight, and a passionate embrace of la dolce vita.",
      'JP': "Japanese cinema is a study in precise, devastating elegance. From the stoic honor of samurai epics to the surreal horrors of modern anime and the quiet, heartbreaking domestic dramas of its masters, it offers a uniquely contemplative lens on tradition, modernity, and the fleeting beauty of existence.",
      'KR': "South Korean cinema is a masterclass in tonal whiplash and genre subversion. Characterized by its slick, kinetic revenge thrillers and deeply empathetic social satires, it is a fearless cinematic voice that marries hyper-stylized violence with profound emotional resonance and biting class critique.",
      'GB': "British cinema balances stoic restraint with razor-sharp wit. Renowned for its impeccable period dramas, gritty social realism, and a unique brand of dry, cynical comedy, it captures the complexities of class, history, and the quiet desperation of the human condition with unparalleled theatrical pedigree.",
      'CN': "Chinese cinema is a sweeping tapestry of historical scale and visual majesty. From the breathtaking martial arts epics of the Fifth Generation to urgent, intimate portraits of rapid modernization, it offers a visually staggering and emotionally potent exploration of duty, destiny, and a rapidly changing society.",
      'IR': "Iranian cinema is a testament to the power of humanistic storytelling under constraint. With its minimalist, documentary-like realism and deeply poetic allegory, it turns the simplest daily struggles into profound, universal meditations on morality, childhood, and the quiet dignity of the human spirit.",
      'ES': "Spanish cinema is a vibrant, surreal explosion of passion and transgression. Heavily influenced by its history and a rich surrealist tradition, its films are often melodramatic, darkly comedic, and bursting with vibrant colors, exploring the fringes of desire, family dysfunction, and societal taboos.",
    };

    // 2. Delay slightly for UI transition effect
    await Future.delayed(const Duration(milliseconds: 600));

    // 3. Return hardcoded or fallback
    if (_editorials.containsKey(countryCode)) {
      return _editorials[countryCode]!;
    } else {
      return "The cinematic landscape of $countryName is a fascinating tapestry waiting to be fully explored. Its stories are deeply rooted in its unique cultural heritage, offering a distinct rhythm and visual language that rewards the intrepid cinephile with fresh perspectives and unspoken truths.";
    }
  }
}

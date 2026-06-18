/// BotService — CineBot powered by Groq LLM with dynamic taste profile injection.
/// Phase 2: Taste-aware conversation with embedded movie recommendation parsing.
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/secrets.dart';
import '../models/movie_model.dart';
import '../models/taste_profile_model.dart';
import 'taste_profile_service.dart';

const String _kGroqUrl = 'https://api.groq.com/openai/v1/chat/completions';
const String _kModel = 'llama-3.3-70b-versatile';
const int _kMaxMemoryMessages = 10;

// ─────────────── CHAT MESSAGE ───────────────
class ChatMessage {
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final DateTime timestamp;
  final List<MovieModel> embeddedMovies;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.embeddedMovies = const [],
  });

  Map<String, dynamic> toGroqJson() => {'role': role, 'content': content};
}

// ─────────────── BOT PARSE RESULT ───────────────
class BotResponse {
  final String textContent;
  final List<MovieModel> movies;
  const BotResponse({required this.textContent, this.movies = const []});
}

class BotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  UserTasteProfile? _cachedProfile;
  final List<ChatMessage> _conversationHistory = [];
  bool _isInitialized = false;

  // ─────────────── INIT ───────────────

  /// Initialize session: load taste profile and memory.
  Future<void> initSession() async {
    if (_isInitialized) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Load taste profile
      _cachedProfile = await TasteProfileService().getProfile(uid);

      // Load last N memory messages
      final memorySnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('bot_memory')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();

      if (memorySnap.docs.isNotEmpty) {
        final memoryContent = memorySnap.docs.reversed
            .map((d) => d.data()['summary'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .join('\n');

        if (memoryContent.isNotEmpty) {
          _conversationHistory.add(ChatMessage(
            role: 'assistant',
            content: '[MEMORY FROM PREVIOUS SESSIONS]\n$memoryContent',
            timestamp: DateTime.now(),
          ));
        }
      }
    } catch (e) {
      debugPrint('BotService.initSession error: $e');
    }

    _isInitialized = true;
  }

  // ─────────────── SEND MESSAGE ───────────────

  Future<BotResponse> sendMessage(String userMessage) async {
    await initSession();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final profile = _cachedProfile;

    // Add user message to history
    _conversationHistory.add(ChatMessage(
      role: 'user',
      content: userMessage,
      timestamp: DateTime.now(),
    ));

    // Build system prompt
    final systemPrompt = _buildSystemPrompt(profile);

    // Trim history to max window
    final trimmedHistory = _conversationHistory.length > _kMaxMemoryMessages
        ? _conversationHistory
            .sublist(_conversationHistory.length - _kMaxMemoryMessages)
        : _conversationHistory;

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...trimmedHistory.map((m) => m.toGroqJson()),
    ];

    try {
      final response = await http
          .post(
            Uri.parse(_kGroqUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppSecrets.groqApiKey}',
            },
            body: jsonEncode({
              'model': _kModel,
              'messages': messages,
              'temperature': 0.75,
              'max_tokens': 1024,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawContent =
            data['choices'][0]['message']['content'] as String? ?? '';

        // Parse response for embedded movie JSON blocks
        final parsed = await _parseResponse(rawContent);

        // Save assistant response to history
        _conversationHistory.add(ChatMessage(
          role: 'assistant',
          content: rawContent,
          timestamp: DateTime.now(),
          embeddedMovies: parsed.movies,
        ));

        // Async: save session memory
        if (uid != null && _conversationHistory.length > 4) {
          _saveSessionMemory(uid);
        }

        return parsed;
      } else {
        debugPrint('Groq API error: ${response.statusCode} ${response.body}');
        return const BotResponse(
          textContent: 'The projection room is temporarily offline. Please try again in a moment.',
        );
      }
    } catch (e) {
      debugPrint('BotService.sendMessage error: $e');
      return const BotResponse(
        textContent: 'Signal lost. Check your connection and try again.',
      );
    }
  }

  // ─────────────── SYSTEM PROMPT ───────────────

  String _buildSystemPrompt(UserTasteProfile? profile) {
    final buffer = StringBuffer();

    buffer.writeln('You are SCREENU — the ultimate cinematic sidekick and close friend built right into Screenique.');
    buffer.writeln('Tone: Speak like a very close, highly engaging best friend who is a massive movie nerd. Be warm, enthusiastic, highly conversational, and naturally use emojis. Do not sound generic, robotic, or overly formal. Keep it snappy.');
    buffer.writeln('Keep responses concise and deeply opinionated but friendly. Always use ALL CAPS for movie/series titles.');
    buffer.writeln();
    buffer.writeln('CORE BEHAVIORS:');
    buffer.writeln('- BE INQUISITIVE: If the user asks for a recommendation vaguely, DO NOT just give a list. Instead, ask ONE fun, creative cross-question to narrow down their vibe. IMPORTANT: NEVER ask the same question twice, and NEVER use generic examples. Invent a completely unique question every time based on genres, moods, weather, food they are eating, runtime limits, or pacing. Be spontaneous and unpredictable!');
    buffer.writeln('- BE A FRIEND: React to their choices! If they say they loved a certain movie, hype it up or share a quick "hot take" on it before recommending the next thing.');
    buffer.writeln('- PERSONALIZE EVERYTHING: Use the user\'s taste profile extensively. If you know they love hidden gems, explicitly call out that you are skipping the mainstream stuff.');
    buffer.writeln('- LANGUAGE MATCHING: Always respond in the exact same language the user uses. However, you MUST write your response using the English alphabet (Latin script) ONLY. For example, if the user speaks Hindi, reply in conversational \'Hinglish\' (Hindi written with English letters). NEVER use native scripts like Devanagari.');
    buffer.writeln();
    buffer.writeln('RECOMMENDATION FORMAT RULES:');
    buffer.writeln('When you DO give specific recommendations (only after you know what they want), ALWAYS include a JSON block at the very end of your message, formatted EXACTLY as:');
    buffer.writeln('```json');
    buffer.writeln('[{"title": "MOVIE TITLE", "year": 2023, "reason": "Why this specifically fits their vibe (one short sentence)"}]');
    buffer.writeln('```');
    buffer.writeln('Include 1-3 movies max per recommendation block to avoid overwhelming them. Do NOT include JSON if you are just chatting or asking a cross-question.');
    buffer.writeln();

    if (profile != null && profile.watchedCount > 0) {
      buffer.writeln('--- USER TASTE PROFILE ---');
      buffer.writeln(profile.toTasteString());
      buffer.writeln('--------------------------');
    } else {
      buffer.writeln('USER TASTE PROFILE: New user. Establish their taste by asking engaging questions!');
    }

    buffer.writeln();
    buffer.writeln('HARD RULES:');
    buffer.writeln('- NEVER recommend movies from the user\'s watch history.');
    buffer.writeln('- ALWAYS explain exactly *why* you are recommending something based on what they just told you.');
    buffer.writeln('- DO NOT use generic AI filler like "As an AI..." or "I\'d be happy to help!"');

    return buffer.toString();
  }

  // ─────────────── RESPONSE PARSER ───────────────

  Future<BotResponse> _parseResponse(String rawContent) async {
    // Find all ```json ... ``` blocks
    final jsonRegex = RegExp(r'```json\s*([\s\S]*?)```', multiLine: true);
    final matches = jsonRegex.allMatches(rawContent);

    final List<MovieModel> movies = [];
    String textContent = rawContent;

    for (final match in matches) {
      try {
        final jsonStr = match.group(1)?.trim() ?? '';
        final parsed = jsonDecode(jsonStr);
        if (parsed is List) {
          for (final item in parsed) {
            if (item is Map<String, dynamic>) {
              final title = item['title'] ?? 'Unknown';
              final yearStr = item['year']?.toString() ?? '';

              int tmdbId = item['tmdbId'] ?? 0;
              String? posterPath;
              double voteAverage = 0.0;
              String releaseDate = yearStr;

              // If TMDB ID is missing, search TMDB to get the real ID so the card is clickable
              if (tmdbId == 0 && title != 'Unknown') {
                 try {
                   final query = Uri.encodeComponent(title);
                   final url = 'https://api.themoviedb.org/3/search/multi?api_key=${AppSecrets.tmdbApiKey}&query=$query';
                   final tmdbRes = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
                   
                   if (tmdbRes.statusCode == 200) {
                      final tmdbData = jsonDecode(tmdbRes.body);
                      final results = tmdbData['results'] as List;
                      if (results.isNotEmpty) {
                         // Prefer matching year if possible, else take the first movie/tv result
                         var bestMatch = results.firstWhere(
                           (r) => (r['media_type'] == 'movie' || r['media_type'] == 'tv') && 
                                  ((r['release_date'] ?? r['first_air_date'] ?? '').toString().startsWith(yearStr)),
                           orElse: () => results.firstWhere(
                             (r) => r['media_type'] == 'movie' || r['media_type'] == 'tv', 
                             orElse: () => results.first
                           )
                         );

                         tmdbId = bestMatch['id'] ?? 0;
                         if (bestMatch['poster_path'] != null) {
                           posterPath = bestMatch['poster_path'];
                         }
                         voteAverage = (bestMatch['vote_average'] ?? 0.0).toDouble();
                         releaseDate = bestMatch['release_date'] ?? bestMatch['first_air_date'] ?? releaseDate;
                      }
                   }
                 } catch (_) {
                   // Search failed, gracefully fallback to keeping tmdbId as 0
                 }
              }

              // Create a lightweight MovieModel stub from bot JSON and TMDB search
              movies.add(MovieModel.fromJson({
                'id': tmdbId,
                'title': title,
                'overview': item['reason'] ?? '',
                'poster_path': posterPath,
                'vote_average': voteAverage,
                'release_date': releaseDate,
                'genre_ids': [],
                'reason': item['reason'] ?? '',
              }));
            }
          }
        }
        // Remove JSON block from display text
        textContent = textContent.replaceAll(match.group(0)!, '').trim();
      } catch (_) {}
    }

    return BotResponse(textContent: textContent, movies: movies);
  }

  // ─────────────── MEMORY PERSISTENCE ───────────────

  Future<void> _saveSessionMemory(String uid) async {
    try {
      // Create a 2-sentence summary of the conversation
      final lastFew = _conversationHistory
          .where((m) => m.role == 'user')
          .toList()
          .reversed
          .take(3)
          .map((m) => m.content)
          .join('; ');

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('bot_memory')
          .add({
        'summary': 'User asked about: $lastFew',
        'timestamp': FieldValue.serverTimestamp(),
        'messageCount': _conversationHistory.length,
      });

      // Prune: keep only 20 most recent memory docs
      final old = await _firestore
          .collection('users')
          .doc(uid)
          .collection('bot_memory')
          .orderBy('timestamp', descending: true)
          .get();
      if (old.docs.length > 20) {
        final toDelete = old.docs.sublist(20);
        for (final d in toDelete) {
          d.reference.delete();
        }
      }
    } catch (e) {
      debugPrint('BotService._saveSessionMemory error: $e');
    }
  }

  // ─────────────── CONVERSATION MANAGEMENT ───────────────

  void clearHistory() {
    _conversationHistory.clear();
    _isInitialized = false;
    _cachedProfile = null;
  }

  List<ChatMessage> get history => List.unmodifiable(_conversationHistory);

  /// Refresh the taste profile mid-session (e.g., after user rates a movie)
  Future<void> refreshProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _cachedProfile = await TasteProfileService().getProfile(uid);
  }

  // ─────────────── PROACTIVE RECOMMENDATIONS (PHASE 3) ───────────────

  Future<MovieModel?> getDailyProactivePick(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).collection('daily_pick').doc('current').get();
      if (doc.exists) {
        final data = doc.data()!;
        final timestamp = data['timestamp'] as Timestamp?;
        // If pick is less than 24 hours old, return it
        if (timestamp != null && DateTime.now().difference(timestamp.toDate()).inHours < 24) {
          return MovieModel.fromJson(data);
        }
      }

      // Generate a new pick
      final profile = await TasteProfileService().getProfile(uid);
      final systemPrompt = _buildSystemPrompt(profile);
      final prompt = 'Generate exactly ONE highly confident proactive movie recommendation for me today. It must be something I have NOT watched. Output ONLY the JSON block. Do NOT include conversational text.';

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': prompt},
      ];

      final response = await http.post(
        Uri.parse(_kGroqUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppSecrets.groqApiKey}',
        },
        body: jsonEncode({
          'model': _kModel,
          'messages': messages,
          'temperature': 0.8,
          'max_tokens': 512,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawContent = data['choices'][0]['message']['content'] as String? ?? '';
        final parsed = await _parseResponse(rawContent);

        if (parsed.movies.isNotEmpty) {
          final pick = parsed.movies.first;
          
          // Save to Firestore
          await _firestore.collection('users').doc(uid).collection('daily_pick').doc('current').set({
            'id': pick.id,
            'title': pick.title,
            'overview': pick.overview,
            'posterPath': pick.posterPath,
            'voteAverage': pick.voteAverage,
            'releaseDate': pick.releaseDate,
            'genreIds': pick.genreIds,
            'reason': pick.broadcastReason, // Uses broadcastReason for the 'why'
            'timestamp': FieldValue.serverTimestamp(),
          });

          return pick;
        }
      }
    } catch (e) {
      debugPrint('BotService.getDailyProactivePick error: $e');
    }
    return null;
  }

  Future<void> summarizeCinecastActivity(String uid) async {
    try {
      final posts = await _firestore
          .collection('community_recs')
          .where('senderId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      if (posts.docs.isEmpty) return;

      final postTexts = posts.docs.map((d) => d.data()['reason'] as String? ?? '').where((s) => s.isNotEmpty).join('\n');
      
      if (postTexts.isEmpty) return;

      final prompt = 'Analyze the following short posts written by a user about movies. Summarize their taste preferences, favorite elements, and what they look for in cinema into a concise 2-sentence summary.\n\nUser Posts:\n$postTexts';

      final response = await http.post(
        Uri.parse(_kGroqUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppSecrets.groqApiKey}',
        },
        body: jsonEncode({
          'model': _kModel,
          'messages': [
            {'role': 'system', 'content': 'You are a concise profiling assistant. Output ONLY the 2-sentence summary.'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.4,
          'max_tokens': 150,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = (data['choices'][0]['message']['content'] as String? ?? '').trim();

        if (summary.isNotEmpty) {
          await _firestore.collection('users').doc(uid).collection('taste_profile').doc('main').set({
            'cinecastSummary': summary,
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('BotService.summarizeCinecastActivity error: $e');
    }
  }
}

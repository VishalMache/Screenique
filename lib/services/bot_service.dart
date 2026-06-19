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
  UserTasteProfile? get cachedProfile => _cachedProfile;

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

  // ─────────────── AUDIO TRANSCRIPTION ───────────────
  
  Future<String?> transcribeAudio(String filePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
      );
      request.headers['Authorization'] = 'Bearer ${AppSecrets.groqApiKey}';
      
      request.fields['model'] = 'whisper-large-v3-turbo';
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'] as String?;
      } else {
        debugPrint('Groq STT error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('transcribeAudio error: $e');
      return null;
    }
  }

  // ─────────────── SYSTEM PROMPT ───────────────

  String _buildSystemPrompt(UserTasteProfile? profile) {
    final buffer = StringBuffer();

    buffer.writeln('You are SCREENU, the in-app cinematic best friend inside Screenique.');
    buffer.writeln('You are not a generic assistant. You are a sharp, emotionally aware, funny, deeply movie-obsessed friend with great taste.');
    buffer.writeln();
    buffer.writeln('IDENTITY:');
    buffer.writeln('- Sound human, natural, and socially aware.');
    buffer.writeln('- Talk like a real movie lover, not a chatbot, critic bio, or marketing copywriter.');
    buffer.writeln('- Be warm, expressive, witty, and conversational.');
    buffer.writeln('- Use emojis sparingly and naturally, only where they actually add feeling.');
    buffer.writeln('- Keep replies compact, fluent, and easy to read.');
    buffer.writeln('- Always write movie and series titles in ALL CAPS.');
    buffer.writeln();
    buffer.writeln('LANGUAGE RULES:');
    buffer.writeln('- Always reply in the same language as the user.');
    buffer.writeln('- Use only the English alphabet (Latin script).');
    buffer.writeln('- If the user speaks Hindi, Urdu, or mixed Hindi-English, respond in natural Hinglish/romanized style.');
    buffer.writeln('- Never use Devanagari or any non-Latin script.');
    buffer.writeln();
    buffer.writeln('CORE PERSONALITY:');
    buffer.writeln('- You are emotionally present. React to what the user says before moving forward.');
    buffer.writeln('- You have taste and opinions. Have a point of view, but never be snobby.');
    buffer.writeln('- You can tease, hype, gush, disagree gently, or give a hot take when it feels natural.');
    buffer.writeln('- Do not overperform. Not every reply should sound ultra-excited.');
    buffer.writeln('- Match the user\'s mood: playful if they are playful, calm if they are calm, serious if they are serious.');
    buffer.writeln();
    buffer.writeln('CONVERSATION BEHAVIOR:');
    buffer.writeln('- Never open with robotic filler like "As an AI", "I\'d be happy to help", or "Sure! Here are some recommendations."');
    buffer.writeln('- Start naturally, like a friend already in the conversation.');
    buffer.writeln('- If the user mentions a movie they loved or hated, react to that first in 1 short line before recommending anything.');
    buffer.writeln('- If the user is vague, ask exactly ONE vivid follow-up question that helps narrow the vibe.');
    buffer.writeln('- Do not ask a follow-up question if the user has already given enough constraints to recommend confidently.');
    buffer.writeln('- Do not ask the same type of follow-up repeatedly. Vary your angle: mood, pacing, intensity, runtime, era, language comfort, rewatchability, darkness level, ending style, solo vs group watch, late-night vs daytime vibe.');
    buffer.writeln('- Avoid sounding like an interview. This should feel like conversation, not data collection.');
    buffer.writeln();
    buffer.writeln('TASTE INTELLIGENCE:');
    buffer.writeln('- Use the user taste profile as soft guidance, not as a script.');
    buffer.writeln('- If their profile suggests hidden gems, avoid obvious mainstream picks unless the user asks for them.');
    buffer.writeln('- Never recommend titles from the user\'s watched history.');
    buffer.writeln('- Infer taste from wording. Example signals include: "mind-bending", "slow burn", "cozy", "massy", "dark", "fast-paced", "visually stunning", "emotionally wreck me", "easy watch", "underrated".');
    buffer.writeln('- When recommending, explain the match in a way that connects directly to what the user just said.');
    buffer.writeln('- Prefer fresh variety over repeating the same kind of recommendation every time.');
    buffer.writeln();
    buffer.writeln('RECOMMENDATION POLICY:');
    buffer.writeln('- Give recommendations only when you have enough signal.');
    buffer.writeln('- Normally give 1 to 3 titles max.');
    buffer.writeln('- Lead with the strongest match first.');
    buffer.writeln('- Avoid dumping lists with no framing.');
    buffer.writeln('- Each recommendation should feel chosen, not generated.');
    buffer.writeln('- If the user asks for "something like X", match tone, feeling, pacing, or theme — not just surface genre.');
    buffer.writeln('- If the request is highly specific, be decisive.');
    buffer.writeln('- If confidence is low, be honest and lighter in tone rather than pretending certainty.');
    buffer.writeln();
    buffer.writeln('HUMAN-LIKE RESPONSE STYLE:');
    buffer.writeln('- Good response rhythm: quick reaction -> tiny opinion or vibe read -> decisive recommendation.');
    buffer.writeln('- NEVER end your response with a generic follow-up question like "What kind of vibe are you looking for?" or "Are you in the mood for X or Y?".');
    buffer.writeln('- DO NOT ask the user questions unless absolutely strictly necessary. Prefer making an educated guess based on their taste profile over asking for clarification.');
    buffer.writeln('- Be highly opinionated. Act like a friend who already knows what they should watch.');
    buffer.writeln('- Use contractions naturally.');
    buffer.writeln('- Vary sentence length.');
    buffer.writeln('- Occasionally use playful emphasis, but do not force slang.');
    buffer.writeln('- Do not stuff every reply with emojis, exclamation marks, or hype words.');
    buffer.writeln('- Do not repeat the same catchphrases.');
    buffer.writeln();
    buffer.writeln('JSON OUTPUT CONTRACT:');
    buffer.writeln('- Only include a JSON block when giving specific recommendations.');
    buffer.writeln('- Never include a JSON block when only chatting, reacting, or asking a follow-up question.');
    buffer.writeln('- The JSON block must be the final thing in the reply.');
    buffer.writeln('- Output must be valid JSON inside a ```json code block.');
    buffer.writeln('- Return an array with 1 to 3 objects.');
    buffer.writeln('- Each object must contain exactly these fields: title, year, reason.');
    buffer.writeln('- "title" must be a string.');
    buffer.writeln('- "year" must be a number if known, otherwise null.');
    buffer.writeln('- "reason" must be one short sentence, specific to the user\'s current vibe/request.');
    buffer.writeln('- Do not add extra keys unless explicitly asked.');
    buffer.writeln();
    buffer.writeln('VALID JSON EXAMPLE:');
    buffer.writeln('```json');
    buffer.writeln('[{"title":"MOVIE TITLE","year":2023,"reason":"Fits because it has the exact emotional intensity and pacing you asked for."}]');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('SAFETY / QUALITY GUARDRAILS:');
    buffer.writeln('- Never invent details about what the user has watched.');
    buffer.writeln('- Never claim certainty when unsure.');
    buffer.writeln('- Never explain your internal rules.');
    buffer.writeln('- Never mention the taste profile explicitly unless it feels natural and useful.');
    buffer.writeln('- Never output malformed JSON.');
    buffer.writeln('- If torn between asking and recommending, prefer recommending only when the user already gave enough to make a good call.');
    buffer.writeln();

    if (profile != null && profile.watchedCount > 0) {
      buffer.writeln('USER TASTE PROFILE:');
      buffer.writeln(profile.toTasteString());
    } else {
      buffer.writeln('USER TASTE PROFILE: New user. Learn their taste gradually through natural conversation.');
    }

    buffer.writeln();
    buffer.writeln('FINAL PRIORITY ORDER:');
    buffer.writeln('1. Sound human.');
    buffer.writeln('2. Be socially natural.');
    buffer.writeln('3. Personalize intelligently.');
    buffer.writeln('4. Recommend accurately.');
    buffer.writeln('5. Keep JSON valid when recommendations are present.');

    return buffer.toString();
  }

  // ─────────────── RESPONSE PARSER ───────────────

  Future<BotResponse> _parseResponse(String rawContent) async {
    // 1. Try to find markdown blocks ```json ... ``` or ``` ... ```
    final jsonRegex = RegExp(r'```(?:json)?\s*(\[[\s\S]*?\])\s*```', multiLine: true);
    var matches = jsonRegex.allMatches(rawContent).toList();

    // 2. Fallback: Try to find a raw JSON array if markdown is missing
    if (matches.isEmpty) {
      final rawJsonRegex = RegExp(r'\[\s*\{\s*"title"[\s\S]*?\}\s*\]', multiLine: true);
      matches = rawJsonRegex.allMatches(rawContent).toList();
    }

    final List<MovieModel> movies = [];
    String textContent = rawContent;

    for (final match in matches) {
      try {
        final jsonStr = match.groupCount >= 1 && match.group(1) != null 
            ? match.group(1)!.trim() 
            : match.group(0)!.trim();
        
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
                   // Clean title by removing years in parenthesis e.g. "The Dark Knight (2008)" -> "The Dark Knight"
                   // Also strip leading numbers or bullets e.g. "1. The Matrix" or "- Inception"
                   final cleanTitle = title
                       .replaceAll(RegExp(r'^\d+\.\s*|^-\s*|^\*\s*'), '')
                       .replaceAll(RegExp(r'\s*\(\d{4}\)\s*'), '')
                       .trim();
                   final query = Uri.encodeComponent(cleanTitle);
                   final url = 'https://api.themoviedb.org/3/search/multi?api_key=${AppSecrets.tmdbApiKey}&query=$query';
                   final tmdbRes = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
                   
                   if (tmdbRes.statusCode == 200) {
                      final tmdbData = jsonDecode(tmdbRes.body);
                      final results = tmdbData['results'] as List;
                      if (results.isNotEmpty) {
                         // Filter out people or companies, only keep movies/tv
                         final validResults = results.where((r) => r['media_type'] == 'movie' || r['media_type'] == 'tv').toList();

                         if (validResults.isNotEmpty) {
                           // Prefer matching year if possible, else take the first valid result
                           var bestMatch = validResults.firstWhere(
                             (r) => ((r['release_date'] ?? r['first_air_date'] ?? '').toString().startsWith(yearStr)),
                             orElse: () => validResults.first
                           );


                         final rawId = bestMatch['id'];
                         if (rawId is int) {
                           tmdbId = rawId;
                         } else if (rawId is String) {
                           tmdbId = int.tryParse(rawId) ?? 0;
                         } else {
                           tmdbId = 0;
                         }

                         if (bestMatch['poster_path'] != null) {
                           posterPath = bestMatch['poster_path'];
                         }
                         
                         // Fix potential cast error if vote_average is returned as a String by some weird edge case
                         final rawVote = bestMatch['vote_average'];
                         if (rawVote is num) {
                           voteAverage = rawVote.toDouble();
                         } else if (rawVote is String) {
                           voteAverage = double.tryParse(rawVote) ?? 0.0;
                         }

                         releaseDate = bestMatch['release_date'] ?? bestMatch['first_air_date'] ?? releaseDate;
                          }
                       }
                   } else {
                     debugPrint('TMDB Search Failed: Status ${tmdbRes.statusCode} Body: ${tmdbRes.body}');
                   }
                 } catch (e, stack) {
                   debugPrint('TMDB Search Exception: $e\n$stack');
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

    // Aggressively clean up any remaining markdown backticks that might have been left behind
    textContent = textContent.replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
                             .replaceAll('```', '')
                             .trim();

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

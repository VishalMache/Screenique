/// ScreenU — The Cinematic Intelligence of Screenique.
/// Direct Gemini SDK integration with Taste DNA injection
/// and persistent conversation memory via Firestore.
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/secrets.dart';
import 'taste_profile_service.dart';

// ─────────────── DATA MODELS ───────────────

class ChatMessage {
  final String role;  // "user" or "assistant"
  final String text;
  final List<MovieRecommendation>? recommendations;
  final DateTime timestamp;
  
  ChatMessage({
    required this.role,
    required this.text,
    this.recommendations,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  Map<String, dynamic> toJson() => {
    'role': role,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };
}

class MovieRecommendation {
  final String title;
  final String year;
  final String reason;
  
  MovieRecommendation({
    required this.title,
    required this.year,
    required this.reason,
  });
  
  factory MovieRecommendation.fromJson(Map<String, dynamic> json) {
    return MovieRecommendation(
      title: json['title'] ?? '',
      year: json['year']?.toString() ?? '',
      reason: json['reason'] ?? '',
    );
  }
}

class BotResponse {
  final String text;
  final List<MovieRecommendation> recommendations;
  
  BotResponse({required this.text, this.recommendations = const []});
}

// ─────────────── SCREENU SERVICE ───────────────

class ScreenUService {
  static const String _systemPromptTemplate = '''
You are "ScreenU" — the cinematic intelligence of Screenique, a premium movie tracking app.
You are the user's personal film curator and cinema companion. You know their complete 
viewing history and taste profile intimately.

YOUR PERSONALITY:
- Speak with cinematic flair but stay concise and natural — like a film-nerd friend
- Be enthusiastic about cinema but not annoyingly so
- Reference the user's past watches when relevant ("Since you rated Interstellar 5 stars...")
- Use light film metaphors occasionally, don't overdo it
- Be opinionated — recommend with conviction, explain WHY something is a great pick
- Keep responses SHORT. 2-4 sentences for simple answers. Max 5-6 for recommendations.

RECOMMENDATION RULES:
- NEVER recommend movies the user has already watched (listed in their DNA)
- NEVER recommend movies on their watchlist
- Weight recommendations toward their demonstrated genre/director preferences
- When recommending, always explain the connection to their taste
- Suggest 2-4 movies per recommendation request, not more unless asked

KNOWLEDGE RULES:
- You can answer ANY question about movies, series, directors, actors, plot analysis, 
  film theory, behind-the-scenes trivia, cinematography, etc.
- If asked about a movie, provide: director, year, genre, brief synopsis, and why it 
  matters (connect to their taste when possible)
- For spoiler-heavy questions, give a brief warning

STRUCTURED RECOMMENDATION FORMAT:
When you recommend specific movies/series, include a JSON block at the END of your 
response (after your conversational text). Format it exactly like this:
```json
[{"title": "Movie Name", "year": "2024", "reason": "Brief reason"}]
```
Only include this JSON block when you are actively recommending titles to watch.
Do NOT include it for general knowledge questions or discussions about specific films.

PAST CONVERSATIONS:
{MEMORY}

USER'S TASTE PROFILE:
{TASTE_DNA}
''';

  final TasteProfileService _tasteService = TasteProfileService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  GenerativeModel? _model;
  ChatSession? _chatSession;
  String? _currentUid;
  
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  
  bool get isInitialized => _chatSession != null;
  
  /// Initialize ScreenU with the user's taste profile and memory.
  Future<void> initSession(String uid) async {
    _currentUid = uid;
    _messages.clear();
    
    // Fetch taste DNA and past memory in parallel
    final results = await Future.wait([
      _tasteService.buildTasteDNA(uid),
      _loadMemory(uid),
    ]);
    
    final tasteDNA = results[0] as String;
    final memory = results[1] as String;
    
    // Build the full system prompt
    final systemPrompt = _systemPromptTemplate
        .replaceAll('{TASTE_DNA}', tasteDNA)
        .replaceAll('{MEMORY}', memory);
    
    // Initialize Gemini model
    final apiKey = AppSecrets.geminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }
    
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.85,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
    );
    
    _chatSession = _model!.startChat();
    debugPrint('ScreenU: Session initialized for $uid');
  }
  
  /// Send a message and get ScreenU's response.
  Future<BotResponse> sendMessage(String message) async {
    if (_chatSession == null) {
      throw Exception('ScreenU session not initialized. Call initSession() first.');
    }
    
    // Add user message to local history
    _messages.add(ChatMessage(role: 'user', text: message));
    
    try {
      final response = await _chatSession!.sendMessage(
        Content.text(message),
      );
      
      final rawText = response.text ?? 'I couldn\'t process that. Could you try rephrasing?';
      
      // Parse response: extract recommendations JSON if present
      final parsed = _parseResponse(rawText);
      
      // Add bot message to local history
      _messages.add(ChatMessage(
        role: 'assistant',
        text: parsed.text,
        recommendations: parsed.recommendations.isNotEmpty ? parsed.recommendations : null,
      ));
      
      return parsed;
    } catch (e) {
      debugPrint('ScreenU error: $e');
      rethrow;
    }
  }
  
  /// Parse the raw Gemini response to extract conversational text and JSON recommendations.
  BotResponse _parseResponse(String raw) {
    // Look for JSON block at the end of the response
    final jsonPattern = RegExp(r'```json\s*\n?([\s\S]*?)\n?\s*```');
    final match = jsonPattern.firstMatch(raw);
    
    List<MovieRecommendation> recommendations = [];
    String cleanText = raw;
    
    if (match != null) {
      final jsonStr = match.group(1)?.trim() ?? '';
      cleanText = raw.substring(0, match.start).trim();
      
      // Also remove any trailing whitespace/newlines after removing the JSON block
      if (match.end < raw.length) {
        final trailing = raw.substring(match.end).trim();
        if (trailing.isNotEmpty) {
          cleanText = '$cleanText\n$trailing';
        }
      }
      
      try {
        final List<dynamic> parsed = jsonDecode(jsonStr);
        recommendations = parsed.map((item) => 
          MovieRecommendation.fromJson(item as Map<String, dynamic>)
        ).toList();
      } catch (e) {
        debugPrint('ScreenU: Failed to parse recommendation JSON: $e');
        // If JSON parsing fails, just show the full text
        cleanText = raw.replaceAll(jsonPattern, '').trim();
      }
    }
    
    return BotResponse(text: cleanText, recommendations: recommendations);
  }
  
  // ─────────────── PERSISTENT MEMORY ───────────────
  
  /// Load past conversation memories from Firestore.
  Future<String> _loadMemory(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users').doc(uid)
          .collection('bot_memory')
          .orderBy('timestamp', descending: true)
          .limit(10)  // Last 10 conversation summaries
          .get();
      
      if (snapshot.docs.isEmpty) {
        return 'No past conversations yet. This is a fresh start.';
      }
      
      final memories = snapshot.docs.map((doc) {
        final data = doc.data();
        return data['summary'] as String? ?? '';
      }).where((s) => s.isNotEmpty).toList();
      
      return memories.join('\n');
    } catch (e) {
      debugPrint('ScreenU memory load error: $e');
      return 'No past conversations available.';
    }
  }
  
  /// Save a conversation summary to Firestore when the session ends.
  Future<void> saveSessionMemory() async {
    if (_currentUid == null || _messages.length < 2) return;
    
    try {
      // Build a summary of the conversation for future context
      final summary = _buildSessionSummary();
      if (summary.isEmpty) return;
      
      await _firestore
          .collection('users').doc(_currentUid!)
          .collection('bot_memory')
          .add({
        'summary': summary,
        'timestamp': FieldValue.serverTimestamp(),
        'messageCount': _messages.length,
      });
      
      // Keep only last 20 memories (prune old ones)
      final allMemories = await _firestore
          .collection('users').doc(_currentUid!)
          .collection('bot_memory')
          .orderBy('timestamp', descending: true)
          .get();
      
      if (allMemories.docs.length > 20) {
        final toDelete = allMemories.docs.sublist(20);
        for (var doc in toDelete) {
          await doc.reference.delete();
        }
      }
      
      debugPrint('ScreenU: Session memory saved');
    } catch (e) {
      debugPrint('ScreenU memory save error: $e');
    }
  }
  
  /// Build a concise summary of the current session for persistent memory.
  String _buildSessionSummary() {
    if (_messages.isEmpty) return '';
    
    final buffer = StringBuffer();
    final now = DateTime.now();
    buffer.write('[${now.day}/${now.month}/${now.year}] ');
    
    // Extract key topics from user messages
    final userMessages = _messages.where((m) => m.role == 'user').toList();
    final botMessages = _messages.where((m) => m.role == 'assistant').toList();
    
    if (userMessages.isEmpty) return '';
    
    // Summarize: what the user asked about
    final topics = userMessages.take(3).map((m) => m.text.length > 80 ? '${m.text.substring(0, 80)}...' : m.text).join('; ');
    buffer.write('User asked: $topics. ');
    
    // Summarize: what recommendations were given
    final allRecs = botMessages
        .where((m) => m.recommendations != null && m.recommendations!.isNotEmpty)
        .expand((m) => m.recommendations!)
        .toList();
    
    if (allRecs.isNotEmpty) {
      final recTitles = allRecs.take(5).map((r) => r.title).join(', ');
      buffer.write('Recommended: $recTitles.');
    }
    
    return buffer.toString();
  }
  
  /// Clear local chat history (does NOT delete Firestore memory).
  void clearChat() {
    _messages.clear();
    _chatSession = null;
    _model = null;
  }
  
  /// Full cleanup when screen closes.
  Future<void> dispose() async {
    await saveSessionMemory();
    _chatSession = null;
    _model = null;
  }
}

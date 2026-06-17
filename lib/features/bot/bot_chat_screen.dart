/// ScreenU Chat Screen — The Cinematic Intelligence of Screenique.
/// Powered by Gemini with Taste DNA injection and persistent memory.
///
/// Design language:
/// - Vintage Cream (#F4F4EC) background
/// - Stark Black (#111111) message bubbles for ScreenU
/// - Vintage Red (#C62828) accents
/// - Rich movie recommendation cards with TMDB posters
/// - Cinematic loading phrases while waiting
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/bot_service.dart';
import '../../services/movie_service.dart';
import '../../services/watchlist_service.dart';
import '../../models/movie_model.dart';
import '../../movie_details_screen.dart';

class BotChatScreen extends StatefulWidget {
  final String? initialNudge;
  const BotChatScreen({super.key, this.initialNudge});
  
  @override
  State<BotChatScreen> createState() => _BotChatScreenState();
}

class _BotChatScreenState extends State<BotChatScreen> 
    with TickerProviderStateMixin {
  final ScreenUService _screenU = ScreenUService();
  final MovieService _movieService = MovieService();
  final WatchlistService _watchlistService = WatchlistService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isLoading = false;
  bool _isInitializing = true;
  String _loadingPhrase = '';
  Timer? _phraseTimer;
  
  // Cache for enriched movie data (poster URLs, etc.)
  final Map<String, MovieModel?> _enrichedMovies = {};
  
  // Cinematic loading phrases
  static const List<String> _loadingPhrases = [
    "Consulting your archive…",
    "Reading between the frames…",
    "Scanning the projection booth…",
    "Rewinding the reel…",
    "Parsing the director's cut…",
    "Developing the negative…",
    "Adjusting the lens…",
    "Checking the filmography…",
    "Cross-referencing your taste DNA…",
    "Searching the vault…",
  ];
  
  @override
  void initState() {
    super.initState();
    _initializeScreenU();
  }
  
  Future<void> _initializeScreenU() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isInitializing = false);
      return;
    }
    
    try {
      await _screenU.initSession(uid);
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      debugPrint('ScreenU init error: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("SCREENU BOOT FAILED. CHECK API KEY.",
              style: TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _phraseTimer?.cancel();
    _screenU.dispose();
    super.dispose();
  }
  
  void _startLoadingPhrases() {
    _loadingPhrase = _loadingPhrases[Random().nextInt(_loadingPhrases.length)];
    _phraseTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _loadingPhrase = _loadingPhrases[Random().nextInt(_loadingPhrases.length)];
        });
      }
    });
  }
  
  void _stopLoadingPhrases() {
    _phraseTimer?.cancel();
  }
  
  Future<void> _sendMessage([String? overrideMessage]) async {
    final message = overrideMessage ?? _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;
    
    if (overrideMessage == null) _messageController.clear();
    HapticFeedback.lightImpact();
    
    setState(() => _isLoading = true);
    _startLoadingPhrases();
    _scrollToBottom();
    
    try {
      final response = await _screenU.sendMessage(message);
      
      // Enrich recommendations with TMDB data in parallel
      if (response.recommendations.isNotEmpty) {
        await _enrichRecommendations(response.recommendations);
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        _stopLoadingPhrases();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _stopLoadingPhrases();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("THE SIGNAL WAS LOST. TRY AGAIN.",
              style: TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
            backgroundColor: Color(0xFF111111),
          ),
        );
      }
    }
  }
  
  /// Fetch TMDB poster/data for each recommended movie.
  Future<void> _enrichRecommendations(List<MovieRecommendation> recs) async {
    await Future.wait(recs.map((rec) async {
      if (!_enrichedMovies.containsKey(rec.title)) {
        final movie = await _movieService.searchMovieByTitle(rec.title, year: rec.year);
        _enrichedMovies[rec.title] = movie;
      }
    }));
  }
  
  Future<void> _addToWatchlist(MovieModel movie) async {
    try {
      await _watchlistService.toggleMovieStatus(movie, 'watchlist');
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${movie.title.toUpperCase()} ADDED TO WATCHLIST",
              style: const TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Watchlist add error: $e');
    }
  }
  
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final messages = _screenU.messages;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4EC),
      body: Column(
        children: [
          _buildAppBar(),
          
          // --- CHAT MESSAGES ---
          Expanded(
            child: _isInitializing
                ? _buildInitializingState()
                : messages.isEmpty && !_isLoading
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length && _isLoading) {
                            return _buildLoadingBubble();
                          }
                          return _buildMessageItem(messages[index]);
                        },
                      ),
          ),
          
          _buildInputBar(),
        ],
      ),
    );
  }
  
  // ─────────────── APP BAR ───────────────
  
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(bottom: BorderSide(color: Color(0xFFC62828), width: 3)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFF4F4EC), size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFC62828),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFFF4F4EC), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("SCREENU",
                  style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 3)),
                Text("YOUR CINEMATIC INTELLIGENCE",
                  style: TextStyle(color: Color(0xFFC62828), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await _screenU.dispose();
              _enrichedMovies.clear();
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                setState(() => _isInitializing = true);
                await _screenU.initSession(uid);
                if (mounted) setState(() => _isInitializing = false);
              }
            },
            child: const Icon(Icons.refresh, color: Color(0xFFF4F4EC), size: 22),
          ),
        ],
      ),
    );
  }
  
  // ─────────────── STATES ───────────────
  
  Widget _buildInitializingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32, height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFFC62828),
            ),
          ),
          SizedBox(height: 16),
          Text("LOADING YOUR TASTE DNA…",
            style: TextStyle(color: Color(0xFF454545), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Icon(Icons.auto_awesome, color: Color(0xFFC62828), size: 40),
            ),
            const SizedBox(height: 24),
            const Text("SCREENU AWAITS",
              style: TextStyle(color: Color(0xFF111111), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 4)),
            const SizedBox(height: 12),
            const Text(
              "I know your taste. Ask me for recommendations, movie trivia, plot explanations, or anything cinema.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF454545), fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 8, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip("What should I watch tonight?"),
                _buildSuggestionChip("Recommend something dark"),
                _buildSuggestionChip("Tell me about Kubrick"),
                _buildSuggestionChip("Best thrillers I haven't seen?"),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC),
          border: Border.all(color: const Color(0xFF111111), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))],
        ),
        child: Text(text,
          style: const TextStyle(color: Color(0xFF111111), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }
  
  // ─────────────── MESSAGE RENDERING ───────────────
  
  Widget _buildMessageItem(ChatMessage message) {
    final isUser = message.role == 'user';
    
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Text bubble
        _buildTextBubble(message.text, isUser),
        
        // Movie recommendation cards (only for assistant messages)
        if (!isUser && message.recommendations != null && message.recommendations!.isNotEmpty)
          _buildRecommendationCards(message.recommendations!),
      ],
    );
  }
  
  Widget _buildTextBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFF4F4EC) : const Color(0xFF111111),
          border: Border.all(color: const Color(0xFF111111), width: isUser ? 2 : 0),
          boxShadow: isUser 
            ? const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))]
            : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? const Color(0xFF111111) : const Color(0xFFF4F4EC),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
  
  // ─────────────── RECOMMENDATION CARDS ───────────────
  
  Widget _buildRecommendationCards(List<MovieRecommendation> recs) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recs.length,
        itemBuilder: (context, index) {
          final rec = recs[index];
          final enrichedMovie = _enrichedMovies[rec.title];
          return _buildMovieCard(rec, enrichedMovie);
        },
      ),
    );
  }
  
  Widget _buildMovieCard(MovieRecommendation rec, MovieModel? movie) {
    return GestureDetector(
      onTap: movie != null ? () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => MovieDetailsScreen(movie: movie),
        ));
      } : null,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC),
          border: Border.all(color: const Color(0xFF111111), width: 2),
          boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poster
            Expanded(
              flex: 3,
              child: movie != null && movie.posterPath.isNotEmpty
                  ? Image.network(
                      movie.posterPath,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => _buildPosterPlaceholder(rec.title),
                    )
                  : _buildPosterPlaceholder(rec.title),
            ),
            
            // Info section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: const BoxDecoration(
                color: Color(0xFF111111),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.title.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFF4F4EC),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rec.year.isNotEmpty ? rec.year : '',
                    style: const TextStyle(
                      color: Color(0xFFC62828),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Quick action: Add to Watchlist
                  GestureDetector(
                    onTap: movie != null ? () => _addToWatchlist(movie) : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC62828),
                        borderRadius: BorderRadius.circular(1),
                      ),
                      child: const Text(
                        "+ WATCHLIST",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFF4F4EC),
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPosterPlaceholder(String title) {
    return Container(
      color: const Color(0xFF222222),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF4F4EC),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
  
  // ─────────────── LOADING BUBBLE ───────────────
  
  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(color: Color(0xFF111111)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFC62828),
              ),
            ),
            const SizedBox(width: 12),
            Text(_loadingPhrase,
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
  
  // ─────────────── INPUT BAR ───────────────
  
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 8, top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4EC),
        border: Border(top: BorderSide(color: Color(0xFF111111), width: 1.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              style: const TextStyle(color: Color(0xFF111111), fontSize: 15),
              cursorColor: const Color(0xFFC62828),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                hintText: "Talk to ScreenU...",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Color(0xFF454545), fontSize: 13, letterSpacing: 1),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _sendMessage(),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _isLoading ? const Color(0xFF454545) : const Color(0xFFC62828),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Icon(Icons.send_rounded, color: Color(0xFFF4F4EC), size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

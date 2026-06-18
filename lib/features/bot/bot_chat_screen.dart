/// CineBot Chat Screen — Phase 2
/// Dark-theme chat UI with embedded movie cards and "why" explanations.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/bot_service.dart';
import '../../../models/movie_model.dart';
import '../../movie_details_screen.dart';

class BotChatScreen extends StatefulWidget {
  const BotChatScreen({super.key});

  @override
  State<BotChatScreen> createState() => _BotChatScreenState();
}

class _BotChatScreenState extends State<BotChatScreen>
    with TickerProviderStateMixin {
  final BotService _botService = BotService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_UiMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitializing = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _initBot();
  }

  Future<void> _initBot() async {
    await _botService.initSession();
    if (!mounted) return;
    setState(() => _isInitializing = false);

    // Welcome message
    _addBotMessage(
      'Hey there! I\'m Screenu, your personal cinematic sidekick. Whether you\'re hunting for the perfect movie recommendation or just have questions about your favorite series, I\'ve got you covered. What are we watching today? 🍿',
      [],
      suggestions: [
        'Recommend me a hidden gem 💎',
        'What\'s similar to DUNE? 🏜️',
        'Surprise me 🎲',
        'Best underrated thrillers? 🔪',
        'Something mind-bending 🌀',
        'Top arthouse picks 🎭',
      ],
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBotMessage(String text, List<MovieModel> movies, {List<String> suggestions = const []}) {
    setState(() {
      _messages.add(_UiMessage(
        role: 'assistant',
        text: text,
        movies: movies,
        suggestions: suggestions,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(_UiMessage(
        role: 'user',
        text: text,
        movies: [],
        suggestions: const [],
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    _textController.clear();
    HapticFeedback.lightImpact();

    _addUserMessage(text.trim());
    setState(() => _isLoading = true);

    final response = await _botService.sendMessage(text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);
    _addBotMessage(response.textContent, response.movies);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isInitializing
                ? _buildInitializingView()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                         return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF111111),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: Color(0xFFF4F4EC), size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFFD32F2F),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/bot_logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('SCREENU',
                  style: TextStyle(
                    color: Color(0xFFF4F4EC),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFamily: 'Impact',
                  )),
              Text('Your Archival Intelligence',
                  style: TextStyle(
                    color: Color(0xFF888882),
                    fontSize: 9,
                    letterSpacing: 1,
                  )),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: Color(0xFF888882), size: 20),
          onPressed: () {
            _botService.clearHistory();
            setState(() {
              _messages.clear();
              _isInitializing = true;
            });
            _initBot();
          },
          tooltip: 'New Session',
        ),
      ],
    );
  }

  Widget _buildInitializingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) => Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Color.lerp(
                    const Color(0xFFD32F2F), const Color(0xFF1A0000), _pulseController.value),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/bot_logo.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('CALIBRATING ARCHIVAL DNA...',
              style: TextStyle(
                  color: Color(0xFF888882),
                  fontSize: 10,
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_UiMessage message) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              isUser ? 'YOU' : 'SCREENU',
              style: TextStyle(
                color: isUser
                    ? const Color(0xFFD32F2F)
                    : const Color(0xFF888882),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          // Text bubble
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0xFFD32F2F).withValues(alpha: 0.1)
                  : const Color(0xFF1A1A1A),
              border: Border.all(
                color: isUser
                    ? const Color(0xFFD32F2F).withValues(alpha: 0.3)
                    : const Color(0xFF2A2A2A),
                width: 1,
              ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: isUser ? const Radius.circular(12) : const Radius.circular(2),
                bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(12),
              ),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                color: Color(0xFFF4F4EC),
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Render Inline Suggestions if any
          if (message.suggestions.isNotEmpty && _messages.length <= 1) ...[
            const SizedBox(height: 12),
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.suggestions.map((suggestion) {
                  return GestureDetector(
                    onTap: () => _sendMessage(suggestion),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.1),
                        border: Border.all(color: const Color(0xFFD32F2F).withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        suggestion,
                        style: const TextStyle(
                          color: Color(0xFFD32F2F),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          
          // Embedded movie cards
          if (message.movies.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: message.movies.length,
                itemBuilder: (context, idx) =>
                    _buildMovieCard(message.movies[idx]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMovieCard(MovieModel movie) {
    return GestureDetector(
      onTap: () {
        if (movie.id != 0) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: movie)));
        }
      },
      child: Container(
        width: 250, // Increased width to accommodate poster + text
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: const Color(0xFFD32F2F), width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x30D32F2F), blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            if (movie.posterPath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Image.network(
                  movie.posterPath,
                  width: 76,
                  height: 114,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderPoster(),
                ),
              )
            else
              _buildPlaceholderPoster(),
            const SizedBox(width: 10),
            
            // Movie Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF4F4EC),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (movie.releaseDate.isNotEmpty)
                    Text(
                      movie.releaseDate.length >= 4
                          ? movie.releaseDate.substring(0, 4)
                          : movie.releaseDate,
                      style: const TextStyle(
                          color: Color(0xFF888882), fontSize: 9, letterSpacing: 1),
                    ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      movie.overview.isNotEmpty
                          ? movie.overview
                          : 'Tap to explore this pick',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFF4F4EC).withValues(alpha: 0.65),
                        fontSize: 9,
                        height: 1.3,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'EXPLORE →',
                      style: TextStyle(
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.8),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
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

  Widget _buildPlaceholderPoster() {
    return Container(
      width: 76,
      height: 114,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Center(
        child: Icon(Icons.movie_filter_rounded, color: Color(0xFFD32F2F), size: 24),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i * 0.33;
                  final t = (_pulseController.value + delay) % 1.0;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xFF3A3A3A),
                        const Color(0xFFD32F2F),
                        (t * 2).clamp(0.0, 1.0),
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Suggestion chips removed in favor of inline message suggestions
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(
                    color: Color(0xFFF4F4EC), fontSize: 13, height: 1.4),
                cursorColor: const Color(0xFFD32F2F),
                decoration: const InputDecoration(
                  hintText: 'Ask CineBot anything...',
                  hintStyle: TextStyle(
                      color: Color(0xFF444444),
                      fontSize: 12,
                      letterSpacing: 0.5),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendMessage(_textController.text),
            child: Container(
              height: 48,
              width: 48,
              color: const Color(0xFFD32F2F),
              child: const Icon(Icons.send_rounded,
                  color: Color(0xFFF4F4EC), size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────── INTERNAL UI MODEL ───────────────
class _UiMessage {
  final String role;
  final String text;
  final List<MovieModel> movies;
  final List<String> suggestions;
  final DateTime timestamp;

  const _UiMessage({
    required this.role,
    required this.text,
    required this.movies,
    required this.suggestions,
    required this.timestamp,
  });
}

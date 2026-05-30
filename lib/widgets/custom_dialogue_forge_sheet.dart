import 'dart:async';
import 'package:flutter/material.dart';
import '../models/movie_model.dart';
import '../services/movie_service.dart';

class CustomDialogueForgeSheet extends StatefulWidget {
  final Function(
    String quote,
    String character,
    String movieTitle,
    String posterUrl,
    int? tmdbId,
  ) onForge;

  const CustomDialogueForgeSheet({super.key, required this.onForge});

  @override
  State<CustomDialogueForgeSheet> createState() => _CustomDialogueForgeSheetState();
}

class _CustomDialogueForgeSheetState extends State<CustomDialogueForgeSheet> {
  final MovieService _movieService = MovieService();
  
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quoteController = TextEditingController();
  final TextEditingController _characterController = TextEditingController();
  final TextEditingController _movieTitleController = TextEditingController();
  final TextEditingController _posterUrlController = TextEditingController();

  List<MovieModel> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  int? _selectedTmdbId;

  @override
  void dispose() {
    _searchController.dispose();
    _quoteController.dispose();
    _characterController.dispose();
    _movieTitleController.dispose();
    _posterUrlController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _movieService.searchAll(trimmed);
        if (mounted) {
          setState(() {
            // Filter to actual movies or TV shows (exclude person search results)
            _searchResults = results.where((item) => !item.isPerson).toList();
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  void _triggerSearchInstant(String query) async {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final results = await _movieService.searchAll(trimmed);
      if (mounted) {
        setState(() {
          _searchResults = results.where((item) => !item.isPerson).toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _selectMovie(MovieModel movie) {
    setState(() {
      _movieTitleController.text = movie.title;
      _posterUrlController.text = movie.posterPath;
      _selectedTmdbId = movie.id;
      _searchResults = [];
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        border: const Border(
          top: BorderSide(color: Color(0xFF111111), width: 3.0),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- DRAG INDICATOR ---
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 16),

              // --- TITLE ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "CUSTOM DIALOGUE FORGE",
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontFamily: 'Impact',
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        border: Border.all(color: const Color(0xFF111111), width: 1),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFFF4F4EC),
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- LIVE PREVIEW ---
              const Text(
                "LIVE CARD PREVIEW ///",
                style: TextStyle(
                  color: Color(0xFFD32F2F),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              _buildLivePreviewCard(),
              const SizedBox(height: 20),

              // --- SEARCH TMDB FIELD ---
              _buildSectionHeader("AUTO-FILL WITH TMDB SEARCH"),
              const SizedBox(height: 6),
              _buildSearchTextField(),
              
              // --- SEARCH RESULTS AREA ---
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Color(0xFFD32F2F),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final movie = _searchResults[index];
                      return GestureDetector(
                        onTap: () => _selectMovie(movie),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 10, bottom: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF111111), width: 1.5),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                movie.posterPath.replaceAll('/original/', '/w500/'),
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  color: const Color(0xFF111111),
                                  child: const Icon(Icons.movie, color: Color(0xFFF4F4EC)),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  color: const Color(0xFF111111).withOpacity(0.85),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    movie.title.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFF4F4EC),
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // --- FORM INPUTS ---
              _buildSectionHeader("DIALOGUE QUOTE"),
              const SizedBox(height: 6),
              _buildBrutalistTextField(
                controller: _quoteController,
                hintText: "E.G. I'LL BE BACK",
                maxLines: 3,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              _buildSectionHeader("CHARACTER NAME"),
              const SizedBox(height: 6),
              _buildBrutalistTextField(
                controller: _characterController,
                hintText: "E.G. THE TERMINATOR",
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("MOVIE TITLE"),
                        const SizedBox(height: 6),
                        _buildBrutalistTextField(
                          controller: _movieTitleController,
                          hintText: "E.G. THE TERMINATOR",
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("POSTER URL"),
                        const SizedBox(height: 6),
                        _buildBrutalistTextField(
                          controller: _posterUrlController,
                          hintText: "E.G. HTTPS://IMAGE.TMDB.ORG/...",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- FORGE ACTION BUTTON ---
              _buildForgeButton(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF111111),
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSearchTextField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        border: Border.all(color: const Color(0xFF111111), width: 2.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _triggerSearchInstant,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: "SEARCH TMDB TO AUTO-FILL...",
                hintStyle: TextStyle(
                  color: Color(0xFF888882),
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
                prefixIcon: Icon(Icons.movie_filter_rounded, color: Color(0xFF111111), size: 16),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF111111), size: 18),
            onPressed: () => _triggerSearchInstant(_searchController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildBrutalistTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        border: Border.all(color: const Color(0xFF111111), width: 2.0),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
        onChanged: (_) => setState(() {}), // Force rebuild to update live preview
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF888882),
            fontSize: 11,
            letterSpacing: 1.0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard() {
    final quoteText = _quoteController.text.trim().isEmpty 
        ? "YOUR BRUTALIST MOVIE QUOTE FORGED HERE" 
        : _quoteController.text.trim().toUpperCase();

    final characterText = _characterController.text.trim().isEmpty 
        ? "CHARACTER NAME" 
        : _characterController.text.trim().toUpperCase();

    final movieText = _movieTitleController.text.trim().isEmpty 
        ? "MOVIE TITLE" 
        : _movieTitleController.text.trim().toUpperCase();

    final posterPath = _posterUrlController.text.trim();

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        border: Border.all(color: const Color(0xFF111111), width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF111111),
            offset: Offset(4, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          // Poster bleeding to the right
          if (posterPath.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: 160,
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, Colors.black],
                      stops: [0.0, 0.6],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.grey,
                      BlendMode.saturation,
                    ),
                    child: Image.network(
                      posterPath.replaceAll('/original/', '/w500/'),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (c, e, s) => Container(color: Colors.transparent),
                    ),
                  ),
                ),
              ),
            ),

          // Red accent bar on extreme right
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              color: const Color(0xFFD32F2F),
            ),
          ),

          // Vertical title on right edge
          Positioned(
            right: 1,
            top: 0,
            bottom: 0,
            child: Center(
              child: RotatedBox(
                quarterTurns: 1,
                child: Text(
                  movieText,
                  style: const TextStyle(
                    color: Color(0xFFF4F4EC),
                    fontSize: 6,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFamily: 'Impact',
                  ),
                ),
              ),
            ),
          ),

          // Left main content: quote and character
          Positioned(
            top: 12,
            left: 12,
            right: 150, // Keep safe from poster bleeding
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "\u201C",
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 0.8,
                        fontFamily: 'serif',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(width: 12, height: 1.2, color: const Color(0xFFD32F2F)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  movieText,
                                  style: const TextStyle(
                                    color: Color(0xFFD32F2F),
                                    fontSize: 6,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      quoteText,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 0.95,
                        fontFamily: 'Impact',
                        letterSpacing: -0.2,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  characterText,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgeButton() {
    return GestureDetector(
      onTap: () {
        final quote = _quoteController.text.trim();
        final character = _characterController.text.trim();
        final movieTitle = _movieTitleController.text.trim();
        final posterUrl = _posterUrlController.text.trim();

        if (quote.isEmpty || character.isEmpty || movieTitle.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("QUOTE, CHARACTER, AND MOVIE TITLE ARE REQUIRED! 🎬"),
              backgroundColor: Color(0xFFD32F2F),
            ),
          );
          return;
        }

        widget.onForge(
          quote,
          character,
          movieTitle,
          posterUrl,
          _selectedTmdbId,
        );

        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F),
          border: Border.all(color: const Color(0xFF111111), width: 2.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF111111),
              offset: Offset(3, 3),
            )
          ],
        ),
        child: const Center(
          child: Text(
            "FORGE TRANSMISSION",
            style: TextStyle(
              color: Color(0xFFF4F4EC),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontFamily: 'Impact',
            ),
          ),
        ),
      ),
    );
  }
}

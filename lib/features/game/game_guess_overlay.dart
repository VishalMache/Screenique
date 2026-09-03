import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/movie_model.dart';
import '../../services/game_service.dart';

class GameGuessOverlay extends StatefulWidget {
  final void Function(MovieModel? movie) onGuess;
  final int attemptsRemaining;

  const GameGuessOverlay({
    super.key,
    required this.onGuess,
    required this.attemptsRemaining,
  });

  @override
  State<GameGuessOverlay> createState() => _GameGuessOverlayState();
}

class _GameGuessOverlayState extends State<GameGuessOverlay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GameService _gameService = GameService();

  List<MovieModel> _results = [];
  MovieModel? _selected;
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _selected = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await _gameService.searchMoviesForGuess(query);
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectMovie(MovieModel movie) {
    setState(() {
      _selected = movie;
      _controller.text = movie.title;
      _results = [];
    });
    _focusNode.unfocus();
  }

  void _submitGuess() {
    if (_selected != null) {
      widget.onGuess(_selected);
    } else if (_controller.text.trim().isNotEmpty) {
      // Pass a minimal movie with just the title for title-matching
      widget.onGuess(MovieModel(
        id: -1,
        title: _controller.text.trim(),
        overview: '',
        posterPath: '',
        voteAverage: 0,
        releaseDate: '',
        genreIds: [],
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const Text(
                      'WHAT MOVIE IS THIS?',
                      style: TextStyle(
                        color: Color(0xFFF4F4EC),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.attemptsRemaining} attempt${widget.attemptsRemaining == 1 ? '' : 's'} remaining',
                      style: const TextStyle(
                        color: Color(0xFF575757),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(
                      color: Color(0xFFF4F4EC),
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search movies...',
                      hintStyle: const TextStyle(color: Color(0xFF444444)),
                      prefixIcon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF575757)),
                                  ),
                                ),
                              ),
                            )
                          : const Icon(Icons.search_rounded,
                              color: Color(0xFF575757)),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFF575757), size: 18),
                              onPressed: () {
                                _controller.clear();
                                setState(() {
                                  _results = [];
                                  _selected = null;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
              ),
              // Selected indicator
              if (_selected != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFD32F2F).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: Color(0xFFD32F2F), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selected!.title,
                            style: const TextStyle(
                              color: Color(0xFFF4F4EC),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _selected!.releaseDate.split('-').first,
                          style: const TextStyle(
                            color: Color(0xFF575757),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Results list
              Expanded(
                child: _results.isEmpty
                    ? const SizedBox()
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final movie = _results[i];
                          return GestureDetector(
                            onTap: () => _selectMovie(movie),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF222222),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFF2A2A2A)),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: movie.posterPath.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: movie.posterPath,
                                            width: 36,
                                            height: 52,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 36,
                                            height: 52,
                                            color: const Color(0xFF333333),
                                            child: const Icon(
                                                Icons.movie_rounded,
                                                color: Color(0xFF444444),
                                                size: 18),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          movie.title,
                                          style: const TextStyle(
                                            color: Color(0xFFF4F4EC),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          movie.releaseDate.split('-').first,
                                          style: const TextStyle(
                                            color: Color(0xFF575757),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      color: Color(0xFF333333), size: 14),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Guess button
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20,
                    10,
                    20,
                    MediaQuery.of(context).viewInsets.bottom + 24),
                child: SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: _selected != null || _controller.text.isNotEmpty
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _controller.text.isNotEmpty ? _submitGuess : null,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'GUESS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFF4F4EC),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

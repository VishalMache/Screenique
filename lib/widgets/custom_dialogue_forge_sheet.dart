import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/dialogues_data.dart';
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

  // Custom dialogues list to display in "My Forged Dialogues" section
  final List<MovieDialogue> customDialogues;
  final Function(MovieDialogue)? onSetActive;
  final Function(MovieDialogue)? onDelete;

  const CustomDialogueForgeSheet({
    super.key,
    required this.onForge,
    this.customDialogues = const [],
    this.onSetActive,
    this.onDelete,
  });

  @override
  State<CustomDialogueForgeSheet> createState() => _CustomDialogueForgeSheetState();
}

class _CustomDialogueForgeSheetState extends State<CustomDialogueForgeSheet> {
  final MovieService _movieService = MovieService();

  // ── Form Controllers ──────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quoteController = TextEditingController();
  final TextEditingController _characterController = TextEditingController();
  final TextEditingController _movieTitleController = TextEditingController();
  final TextEditingController _posterUrlController = TextEditingController();

  List<MovieModel> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  int? _selectedTmdbId;
  bool _onlyCustomDialogues = false;

  // ── Tab state: 0 = FORGE, 1 = MY DIALOGUES ──────────────────────────
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadRotationSetting();
  }

  Future<void> _loadRotationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _onlyCustomDialogues = prefs.getBool('onlyCustomDialogues') ?? false;
      });
    }
  }

  Future<void> _toggleRotationSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onlyCustomDialogues', value);
    if (mounted) {
      setState(() {
        _onlyCustomDialogues = value;
      });
    }
  }

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
            _searchResults = results.where((item) => !item.isPerson).toList();
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isSearching = false);
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
      if (mounted) setState(() => _isSearching = false);
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

  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4EC),
        border: Border(
          top: BorderSide(color: Color(0xFF111111), width: 3.0),
        ),
      ),
      child: Column(
        children: [
          // ── Drag handle + Title ─────────────────────────────
          _buildHeader(),

          // ── Tab Toggle ──────────────────────────────────────
          _buildTabToggle(),
          const Divider(color: Color(0xFF111111), height: 1.5, thickness: 1.5),

          // ── Content ─────────────────────────────────────────
          Expanded(
            child: _selectedTab == 0
                ? _buildForgeTab(bottomPadding)
                : _buildMyDialoguesTab(),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          Center(
            child: Container(height: 4, width: 40, color: const Color(0xFF111111)),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 22,
                    color: const Color(0xFFD32F2F),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "DIALOGUE FORGE",
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontFamily: 'Impact',
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    border: Border.all(color: const Color(0xFF111111), width: 1),
                  ),
                  child: const Icon(Icons.close, color: Color(0xFFF4F4EC), size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ─── TAB TOGGLE ──────────────────────────────────────────────────────
  Widget _buildTabToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E0),
          border: Border.all(color: const Color(0xFF111111), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            _tabBtn('FORGE NEW', 0, Icons.edit_note_rounded),
            const SizedBox(width: 4),
            _tabBtn(
              'MY DIALOGUES${widget.customDialogues.isNotEmpty ? " (${widget.customDialogues.length})" : ""}',
              1,
              Icons.format_quote_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(String label, int index, IconData icon) {
    final bool isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF111111) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isActive ? const Color(0xFFD32F2F) : const Color(0xFF888882),
                  size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFFF4F4EC) : const Color(0xFF454545),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontFamily: 'Impact',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FORGE TAB ────────────────────────────────────────────────────────
  Widget _buildForgeTab(double bottomPadding) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Preview
          _buildSectionHeader("LIVE CARD PREVIEW ///", color: const Color(0xFFD32F2F)),
          const SizedBox(height: 8),
          _buildLivePreviewCard(),
          const SizedBox(height: 20),

          // TMDB Search
          _buildSectionHeader("AUTO-FILL WITH TMDB SEARCH"),
          const SizedBox(height: 6),
          _buildSearchTextField(),

          if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Color(0xFFD32F2F), strokeWidth: 2),
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

          // Form inputs
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
          const SizedBox(height: 20),

          // Rotation toggle
          _buildSectionHeader("DIALOGUE ROTATION MODE"),
          const SizedBox(height: 6),
          _buildRotationToggle(),
          const SizedBox(height: 24),

          // Forge button
          _buildForgeButton(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ─── MY DIALOGUES TAB ────────────────────────────────────────────────
  Widget _buildMyDialoguesTab() {
    if (widget.customDialogues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                border: Border.all(color: const Color(0xFFD32F2F), width: 2),
              ),
              child: const Icon(Icons.format_quote_rounded, color: Color(0xFFD32F2F), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              "NO FORGED DIALOGUES YET",
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                fontFamily: 'Impact',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Tap FORGE NEW to craft your first dialogue.",
              style: TextStyle(color: Color(0xFF888882), fontSize: 10),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  border: Border.all(color: const Color(0xFFD32F2F), width: 1.5),
                ),
                child: const Text(
                  "GO TO FORGE",
                  style: TextStyle(
                    color: Color(0xFFF4F4EC),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFamily: 'Impact',
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
      physics: const BouncingScrollPhysics(),
      itemCount: widget.customDialogues.length,
      itemBuilder: (context, index) {
        final d = widget.customDialogues[index];
        return _buildCustomDialogueCard(d, index);
      },
    );
  }

  Widget _buildCustomDialogueCard(MovieDialogue d, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC),
          border: Border.all(color: const Color(0xFF111111), width: 2),
          boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card mini-preview with poster
            SizedBox(
              height: 130,
              child: Stack(
                children: [
                  // Desaturated poster bleed right
                  Positioned(
                    right: 0, top: 0, bottom: 0,
                    child: SizedBox(
                      width: 140,
                      child: d.posterUrl.isNotEmpty
                          ? ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Colors.transparent, Colors.black],
                                stops: [0.0, 0.55],
                              ).createShader(bounds),
                              blendMode: BlendMode.dstIn,
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                                child: Image.network(
                                  d.posterUrl.replaceAll('/original/', '/w500/'),
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                  errorBuilder: (c, e, s) => Container(color: Colors.transparent),
                                ),
                              ),
                            )
                          : Container(color: const Color(0xFF222222)),
                    ),
                  ),
                  // Red strip
                  Positioned(
                    top: 0, right: 0, bottom: 0,
                    child: Container(width: 16, color: const Color(0xFFD32F2F)),
                  ),
                  // Vertical title
                  Positioned(
                    right: 1, top: 0, bottom: 0,
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Text(
                          d.movieTitle,
                          style: const TextStyle(
                            color: Color(0xFFF4F4EC),
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            fontFamily: 'Impact',
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Quote content
                  Positioned(
                    top: 12, left: 12, right: 145, bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(width: 12, height: 1.2, color: const Color(0xFFD32F2F)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                d.movieTitle,
                                style: const TextStyle(
                                  color: Color(0xFFD32F2F),
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            d.quote,
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              fontFamily: 'Impact',
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.character,
                          style: const TextStyle(
                            color: Color(0xFF454545),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action bar
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF111111), width: 1.5)),
              ),
              child: Row(
                children: [
                  // Set as Active
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onSetActive?.call(d);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: const Color(0xFF111111),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_fill_rounded, color: Color(0xFFD32F2F), size: 14),
                            SizedBox(width: 6),
                            Text(
                              "SET AS ACTIVE",
                              style: TextStyle(
                                color: Color(0xFFF4F4EC),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontFamily: 'Impact',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1.5, height: 38, color: const Color(0xFF333333)),
                  // Delete
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _confirmDelete(d);
                    },
                    child: Container(
                      width: 48,
                      height: 38,
                      color: const Color(0xFF111111),
                      child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252), size: 18),
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

  void _confirmDelete(MovieDialogue d) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF4F4EC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFF111111), width: 2),
        ),
        title: const Text(
          "DELETE DIALOGUE?",
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontFamily: 'Impact',
          ),
        ),
        content: Text(
          '"${d.quote.length > 50 ? "${d.quote.substring(0, 50)}..." : d.quote}" will be permanently removed.',
          style: const TextStyle(color: Color(0xFF454545), fontSize: 11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF888882), fontSize: 10)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete?.call(d);
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SHARED WIDGETS ───────────────────────────────────────────────────
  Widget _buildSectionHeader(String text, {Color color = const Color(0xFF111111)}) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildRotationToggle() {
    return GestureDetector(
      onTap: () => _toggleRotationSetting(!_onlyCustomDialogues),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC),
          border: Border.all(color: const Color(0xFF111111), width: 2.0),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _onlyCustomDialogues ? const Color(0xFFD32F2F) : Colors.transparent,
                border: Border.all(color: const Color(0xFF111111), width: 2.0),
              ),
              child: _onlyCustomDialogues
                  ? const Icon(Icons.check, color: Color(0xFFF4F4EC), size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "ONLY SHOW MY FORGED DIALOGUES",
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "TICK TO DISABLE CLASSIC SHUFFLING",
                    style: TextStyle(
                      color: Color(0xFF888882),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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
              style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: "SEARCH TMDB TO AUTO-FILL...",
                hintStyle: TextStyle(color: Color(0xFF888882), fontSize: 11, letterSpacing: 1.0),
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
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF888882), fontSize: 11, letterSpacing: 1.0),
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
        boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))],
      ),
      child: Stack(
        children: [
          if (posterPath.isNotEmpty)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: SizedBox(
                width: 160,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.black],
                    stops: [0.0, 0.6],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
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
          Positioned(top: 0, right: 0, bottom: 0, child: Container(width: 16, color: const Color(0xFFD32F2F))),
          Positioned(
            right: 1, top: 0, bottom: 0,
            child: Center(
              child: RotatedBox(
                quarterTurns: 1,
                child: Text(
                  movieText,
                  style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 6, fontWeight: FontWeight.w900, letterSpacing: 2, fontFamily: 'Impact'),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12, left: 12, right: 150, bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("\u201C", style: TextStyle(color: Color(0xFFD32F2F), fontSize: 32, fontWeight: FontWeight.w900, height: 0.8, fontFamily: 'serif')),
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
                              Flexible(child: Text(movieText, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 6, fontWeight: FontWeight.w900, letterSpacing: 1), overflow: TextOverflow.ellipsis)),
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
                    child: Builder(
                      builder: (context) {
                        double fs = 14.0;
                        if (quoteText.length > 120) fs = 8.5;
                        else if (quoteText.length > 80) fs = 10.0;
                        else if (quoteText.length > 50) fs = 11.5;
                        else if (quoteText.length > 30) fs = 12.8;
                        return Text(
                          quoteText,
                          style: TextStyle(color: const Color(0xFF111111), fontSize: fs, fontWeight: FontWeight.w900, height: 0.95, fontFamily: 'Impact', letterSpacing: -0.2),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(characterText, style: const TextStyle(color: Color(0xFF111111), fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1.5), maxLines: 1, overflow: TextOverflow.ellipsis),
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

        widget.onForge(quote, character, movieTitle, posterUrl, _selectedTmdbId);
        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F),
          border: Border.all(color: const Color(0xFF111111), width: 2.0),
          boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, color: Color(0xFFF4F4EC), size: 20),
            SizedBox(width: 8),
            Text(
              "FORGE TRANSMISSION",
              style: TextStyle(
                color: Color(0xFFF4F4EC),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontFamily: 'Impact',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

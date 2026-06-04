import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/movie_model.dart';
import '../../services/movie_service.dart';
import '../../services/watchlist_service.dart';
import '../../movie_details_screen.dart';
import 'directorprofilescreen.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'broadcast_wire_screen.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../features/movie_lists/watchlist_tab.dart';
import '../features/movie_lists/watched_tab.dart';
import '../features/experiences/add_experience_screen.dart';
import '../features/experiences/experiences_tab.dart';
import '../features/world_cinema/world_cinema_screen.dart';
import 'features/news/the_news_screen.dart';
import 'widgets/recommendation_carousel.dart';
import 'widgets/series_recommendation_carousel.dart';
import 'widgets/theatre_carousel.dart';
import 'widgets/dialogue_hero_widget.dart';
import '../data/dialogues_data.dart';
import '../profile_screen.dart';
import 'settings_screen.dart';
import 'widgets/custom_dialogue_forge_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final MovieService _movieService = MovieService();
  final WatchlistService _watchlistService = WatchlistService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _smartMovieData, _smartSeriesData;
  late MovieDialogue _currentDialogue;
  List<MovieDialogue> _activeDialogues = [];
  bool _onlyCustomDialogues = false;
  bool _isLoading = true, _isSearching = false, _isWaitingForApi = false, _isPopupOpen = false, _showReloadPrompt = false;
  List<MovieModel> _searchResults = [];
  final List<String> _searchHistory = [];
  Timer? _debounce, _retryTimer;
  int _retryCount = 0;
  int _searchRequestId = 0;
  String _lastRefreshTime = "Just now";
  StreamSubscription<AccelerometerEvent>? _shakeSub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  static const double _shakeThreshold = 15.5;
  static const Duration _shakeCooldown = Duration(seconds: 2);
  late AnimationController _flareController;
  late Animation<double> _flarePulse;
  
  // Quick Add Context to separate FAB flows
  String? _quickAddContext; 
  String? _experiencePromptTitle;

  @override
  void initState() {
    super.initState();
    _activeDialogues = List.from(MovieDialogue.dialogues);
    _currentDialogue = MovieDialogue.getRandom();
    _fetchCustomDialogues();
    _fetchInitialData();
    _startAutoRetryTimer();
    _initShakeListener();
    _flareController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _flarePulse = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _flareController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeSub?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _flareController.dispose();
    _debounce?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  void _initShakeListener() {
    _shakeSub = accelerometerEvents.listen((event) {
      final gForce = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      final now = DateTime.now();
      if (gForce > _shakeThreshold && now.difference(_lastShake) > _shakeCooldown && !_isSearching && !_isPopupOpen) {
        _lastShake = now;
        _onShakeTriggered();
      }
    });
  }

  Future<void> _onShakeTriggered() async {
    HapticFeedback.heavyImpact();
    final movie = await _watchlistService.getRandomWatchlistMovie();
    if (!mounted) return;
    if (movie == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Your watchlist is empty 🎬"), backgroundColor: Color(0xFF0F0F0F)));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: movie)));
  }

  void _startAutoRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final isMovieEmpty = _smartMovieData == null || (_smartMovieData!['movies'] as List).isEmpty;
      final isSeriesEmpty = _smartSeriesData == null || (_smartSeriesData!['movies'] as List).isEmpty;
      if ((isMovieEmpty && isSeriesEmpty) && !_isLoading && _retryCount < 5) {
        _retryCount++;
        _fetchInitialData(force: true);
      } else if (_retryCount >= 5 || !isMovieEmpty) {
        if (!isMovieEmpty) HapticFeedback.lightImpact();
        _retryTimer?.cancel();
      }
    });
  }

  Future<void> _fetchInitialData({bool force = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _showReloadPrompt = false;
    });
    try {
      final results = await Future.wait([_movieService.getSmartMovieData(forceRefresh: force), _movieService.getSmartSeriesData(forceRefresh: force)]);
      if (!mounted) return;
      setState(() {
        _smartMovieData = results[0];
        _smartSeriesData = results[1];
        _isLoading = false;
        _lastRefreshTime = DateFormat('hh:mm a').format(DateTime.now());
        if ((_smartMovieData?['movies'] as List).isEmpty && (_smartSeriesData?['movies'] as List).isEmpty) _showReloadPrompt = true;
      });

      // Check for Theatre Experience Prompt
      final prefs = await SharedPreferences.getInstance();
      final lastTappedTitle = prefs.getString('theatre_last_tapped_title');
      final lastTappedDateStr = prefs.getString('theatre_last_tapped_date');
      final dismissedDateStr = prefs.getString('theatre_prompt_dismissed_date');

      if (lastTappedTitle != null && lastTappedDateStr != null) {
        final lastTappedDate = DateTime.parse(lastTappedDateStr);
        final diff = DateTime.now().difference(lastTappedDate);
        
        // Between 12 and 48 hours ago
        if (diff.inHours >= 12 && diff.inHours <= 48) {
          bool shouldShow = true;
          if (dismissedDateStr != null) {
            final dismissedDate = DateTime.parse(dismissedDateStr);
            if (dismissedDate.isAfter(lastTappedDate)) {
              shouldShow = false;
            }
          }
          if (shouldShow && mounted) {
            setState(() {
              _experiencePromptTitle = lastTappedTitle;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() {_isLoading = false; _showReloadPrompt = true;});
    }
  }

  Future<void> _fetchCustomDialogues() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _onlyCustomDialogues = prefs.getBool('onlyCustomDialogues') ?? false;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('custom_dialogues')
          .orderBy('timestamp', descending: true)
          .get();
      
      final List<MovieDialogue> customList = snapshot.docs.map((doc) {
        final data = doc.data();
        return MovieDialogue(
          quote: data['quote']?.toString() ?? "",
          character: data['character']?.toString() ?? "",
          movieTitle: data['movieTitle']?.toString() ?? "",
          posterUrl: data['posterUrl']?.toString() ?? "",
          tmdbId: data['tmdbId'] as int? ?? 0,
        );
      }).toList();

      if (mounted) {
        setState(() {
          if (_onlyCustomDialogues && customList.isNotEmpty) {
            _activeDialogues = List.from(customList);
            _currentDialogue = _activeDialogues[0]; // Set active to first forged dialogue
          } else {
            _activeDialogues = List.from(MovieDialogue.dialogues)..addAll(customList);
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching custom dialogues: $e");
    }
  }

  Future<void> _saveCustomDialogue({
    required String quote,
    required String character,
    required String movieTitle,
    required String posterUrl,
    int? tmdbId,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      final newDialogue = MovieDialogue(
        quote: quote.toUpperCase(),
        character: character.toUpperCase(),
        movieTitle: movieTitle.toUpperCase(),
        posterUrl: posterUrl,
        tmdbId: tmdbId ?? 0,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('custom_dialogues')
          .add({
        'quote': quote.toUpperCase(),
        'character': character.toUpperCase(),
        'movieTitle': movieTitle.toUpperCase(),
        'posterUrl': posterUrl,
        'tmdbId': tmdbId ?? 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _activeDialogues.insert(0, newDialogue); // Prepend custom dialogue
          _currentDialogue = newDialogue; // Instantly show on hero!
        });
      }
    } catch (e) {
      debugPrint("Error saving custom dialogue: $e");
    }
  }

  void _showCustomDialogueForge() {
    setState(() => _isPopupOpen = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomDialogueForgeSheet(
        onForge: (quote, character, movieTitle, posterUrl, tmdbId) {
          _saveCustomDialogue(
            quote: quote,
            character: character,
            movieTitle: movieTitle,
            posterUrl: posterUrl,
            tmdbId: tmdbId,
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isPopupOpen = false);
        _fetchCustomDialogues();
      }
    });
  }

  Future<void> _toggleDialogueRotationMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _onlyCustomDialogues = !_onlyCustomDialogues;
      prefs.setBool('onlyCustomDialogues', _onlyCustomDialogues);
    });
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _onlyCustomDialogues 
              ? "DIALOGUE ROTATION: ONLY YOUR FORGED DIALOGUES" 
              : "DIALOGUE ROTATION: SHUFFLING CLASSICS AND FORGED DIALOGUES",
          style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        backgroundColor: const Color(0xFF111111),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    await _fetchCustomDialogues();
  }

  Future<void> _manualArchiveRefresh() async {
    HapticFeedback.mediumImpact();
    _retryCount = 0;
    await MovieService.clearCache();
    await _fetchInitialData(force: true);
  }



  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {_searchResults = []; _isWaitingForApi = false;});
      return;
    }
    // Require at least 2 characters to avoid noisy single-letter results
    if (trimmed.length < 2) {
      setState(() {_searchResults = []; _isWaitingForApi = false;});
      return;
    }
    // Show loading immediately so user gets visual feedback
    setState(() => _isWaitingForApi = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      // Capture a unique ID for this request to detect stale responses
      final requestId = ++_searchRequestId;
      try {
        final results = await _movieService.searchAll(trimmed);
        // Only apply results if this is still the latest request
        if (mounted && requestId == _searchRequestId) {
          setState(() {_searchResults = results; _isWaitingForApi = false;});
          // Add to search history if we got results
          if (results.isNotEmpty && !_searchHistory.contains(trimmed)) {
            _searchHistory.insert(0, trimmed);
            if (_searchHistory.length > 10) _searchHistory.removeLast();
          }
        }
      } catch (e) {
        if (mounted && requestId == _searchRequestId) {
          setState(() => _isWaitingForApi = false);
        }
      }
    });
  }

  void _onSearchSubmitted(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() => _isWaitingForApi = true);
    final requestId = ++_searchRequestId;
    _movieService.searchAll(trimmed).then((results) {
      if (mounted && requestId == _searchRequestId) {
        setState(() {
          _searchResults = results;
          _isWaitingForApi = false;
        });
        if (results.isNotEmpty && !_searchHistory.contains(trimmed)) {
          _searchHistory.insert(0, trimmed);
          if (_searchHistory.length > 10) _searchHistory.removeLast();
        }
      }
    }).catchError((_) {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isWaitingForApi = false);
      }
    });
  }

  void _closeSearch() => setState(() {_isSearching = false; _searchResults = []; _quickAddContext = null; _searchController.clear(); FocusScope.of(context).unfocus();});

  void _showCollectionOverlay(Widget content, String title) {
    setState(() => _isPopupOpen = true);
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => Container(height: MediaQuery.of(context).size.height * 0.90, decoration: BoxDecoration(color: const Color(0xFFF4F4EC), borderRadius: const BorderRadius.vertical(top: Radius.circular(0)), border: Border.all(color: const Color(0xFF111111), width: 2.0)), child: Column(children: [Container(height: 5, width: 40, margin: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(0))), Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 5)), Expanded(child: content)]))).then((_) => setState(() => _isPopupOpen = false));
  }

  // Brutalist direct Rate/Review dialog from quick watched search result
  void _showDirectLogWatchedDialog(MovieModel movie) {
    final TextEditingController reviewController = TextEditingController();
    double rating = 3.0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          scrollable: true,
          backgroundColor: const Color(0xFFF4F4EC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: const BorderSide(color: Color(0xFF111111), width: 2),
          ),
          title: Row(
            children: const [
              Icon(Icons.star_rounded, color: Color(0xFFD32F2F), size: 26),
              SizedBox(width: 10),
              Text(
                "RATE & REVIEW",
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "LOG AND REVIEW ${movie.title.toUpperCase()}.",
                style: const TextStyle(color: Color(0xFF454545), fontSize: 11, letterSpacing: 1),
              ),
              const SizedBox(height: 20),
              
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("YOUR RATING", style: TextStyle(color: Color(0xFF111111), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setST(() => rating = i + 1.0),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: i < rating ? const Color(0xFF111111) : const Color(0xFF454545),
                      size: 32,
                    ),
                  ),
                )),
              ),
              Center(
                child: Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("YOUR REVIEW", style: TextStyle(color: Color(0xFF111111), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reviewController,
                maxLines: 4,
                minLines: 2,
                style: const TextStyle(color: Color(0xFF111111), fontSize: 15, height: 1.5),
                decoration: const InputDecoration(
                  hintText: "WRITE YOUR REVIEW (OPTIONAL)...",
                  hintStyle: TextStyle(color: Color(0xFF454545), fontSize: 12),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF111111), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2),
                  ),
                  filled: true,
                  fillColor: Color(0xFFF4F4EC),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Color(0xFF111111), fontSize: 13, letterSpacing: 1)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111111)),
              onPressed: () async {
                final reviewText = reviewController.text.trim();
                
                final updatedMovie = MovieModel(
                  id: movie.id,
                  title: movie.title,
                  overview: movie.overview,
                  posterPath: movie.posterPath,
                  voteAverage: movie.voteAverage,
                  releaseDate: movie.releaseDate,
                  genreIds: movie.genreIds,
                  isTvShow: movie.isTvShow,
                  personalNote: reviewText,
                );
                
                await _watchlistService.toggleMovieStatus(updatedMovie, 'watched');
                await _watchlistService.updateMovieRating(movie.id, rating);
                
                if (mounted) {
                  Navigator.pop(context);
                  _closeSearch();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("WATCHED ${movie.title.toUpperCase()} RECORDED SUCCESSFULLY"),
                      backgroundColor: const Color(0xFF111111),
                    ),
                  );
                }
              },
              child: const Text("SAVE", style: TextStyle(color: Color(0xFFF4F4EC), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5)),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAddMenu() {
    setState(() => _isPopupOpen = true);
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, 
      builder: (context) => Container(
        padding: const EdgeInsets.all(24), 
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC), 
          border: Border.all(color: const Color(0xFF111111), width: 2.0),
        ), 
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Container(height: 4, width: 40, decoration: const BoxDecoration(color: Color(0xFF111111))), 
            const SizedBox(height: 35), 
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround, 
              children: [
                _quickAction(Icons.bookmark_add_outlined, "WATCHLIST", () {
                  Navigator.pop(context); 
                  setState(() {
                    _isSearching = true;
                    _quickAddContext = 'watchlist'; // Specific watchlist add flow
                  });
                }), 
                _quickAction(Icons.verified_outlined, "WATCHED", () {
                  Navigator.pop(context); 
                  setState(() {
                    _isSearching = true;
                    _quickAddContext = 'watched'; // Specific watched log flow
                  });
                }), 
                _quickAction(Icons.podcasts_rounded, "RECOMMEND?", () {
                  Navigator.pop(context); 
                  setState(() {
                    _isSearching = true;
                    _quickAddContext = null;
                  });
                }), 
                _quickAction(Icons.confirmation_num_outlined, "EXPERIENCE", () {
                  Navigator.pop(context); 
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AddExperienceScreen()));
                })
              ],
            ), 
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).then((_) => setState(() => _isPopupOpen = false));
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Column(children: [Icon(icon, color: const Color(0xFFC62828), size: 32), const SizedBox(height: 10), Text(label, style: const TextStyle(color: Color(0xFF111111), fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.bold))]));

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: !_isSearching, onPopInvokedWithResult: (didPop, result) {if (!didPop && _isSearching) _closeSearch();}, child: Scaffold(backgroundColor: const Color(0xFFF4F4EC), extendBody: true, body: Stack(children: [ _isSearching ? _buildSearchLogicUI() : _buildCinematicHome(), _buildSolidAppBar(), if (!_isSearching) _buildBottomNavBar()])));
  }

  Widget _buildCinematicHome() {
    return RefreshIndicator(
      color: const Color(0xFFD32F2F),
      onRefresh: () => _fetchInitialData(force: true),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(top: 110, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. DIALOGUE HERO
            DialogueHeroWidget(
              dialogue: _currentDialogue,
              onForgeTap: _showCustomDialogueForge,
            ),
            const SizedBox(height: 8),
            // 2. QUICK ACCESS
            _buildQuickAccess(),
            const SizedBox(height: 12),
            // 2.5 EXPERIENCE PROMPT
            if (_experiencePromptTitle != null) ...[
              _buildExperiencePrompt(),
              const SizedBox(height: 12),
            ],
            // 3. NOW PLAYING
            const TheatreCarousel(),
            const SizedBox(height: 24),
            // 4. RECOMMENDATION HUB
            _buildHubHeader("RECOMMENDATION HUB"),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _smartMovieData == null
                ? const CarouselPlaceholder(key: ValueKey('movie_ph'), title: "CURATED SELECTION")
                : RecommendationCarousel(key: const ValueKey('movie_smart'), data: _smartMovieData),
            ),
            const SizedBox(height: 30),
            // 4. SERIES FOR YOU
            _buildHubHeader("SERIES FOR YOU"),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _smartSeriesData == null
                ? const CarouselPlaceholder(key: ValueKey('series_ph'), title: "SERIES FOR YOU", isSeries: true)
                : SeriesRecommendationCarousel(key: const ValueKey('series_smart'), data: _smartSeriesData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHubHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          Text(text, style: const TextStyle(color: Color(0xFF111111), fontSize: 14, letterSpacing: 3, fontWeight: FontWeight.w900, fontFamily: 'Impact')),
          const Expanded(child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Divider(color: Color(0xFF111111), thickness: 2.5))),
          const Text("SEE ALL", style: TextStyle(color: Color(0xFFD32F2F), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward, color: Color(0xFFD32F2F), size: 14)
        ]
      ),
    );
  }

  Widget _buildSolidAppBar() => Positioned(top: 0, left: 0, right: 0, child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: _isSearching ? 120 : 100, padding: const EdgeInsets.only(top: 50, left: 24, right: 16), decoration: const BoxDecoration(color: Color(0xFFF4F4EC), border: Border(bottom: BorderSide(color: Color(0xFF111111), width: 1.5))), child: _isSearching ? _buildSearchField() : _buildLogoHeader()));

  Widget _buildLogoHeader() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Transform.translate(offset: const Offset(-12, 0), child: Image.asset('assets/logo12.png', width: 200, fit: BoxFit.fitWidth)), _buildSquareIcon(Icons.search_rounded, () => setState(() => _isSearching = true))]);

  Widget _buildSquareIcon(IconData icon, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFF111111)), child: Icon(icon, color: const Color(0xFFF4F4EC), size: 20)));



  Widget _buildReloadTooltip() => TweenAnimationBuilder<double>(tween: Tween(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 500), curve: Curves.elasticOut, builder: (context, value, child) => Transform.scale(scale: value, alignment: Alignment.topRight, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: _retryCount > 0 ? Colors.blueGrey.withOpacity(0.9) : const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_retryCount > 0 ? Icons.sync : Icons.bolt, color: Colors.white, size: 14), const SizedBox(width: 6), Text(_retryCount > 0 ? "AUTO-SYNCING..." : "TAP TO SYNC", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1))]))));

  Widget _buildExperiencePrompt() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(left: BorderSide(color: Color(0xFFD32F2F), width: 4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AddExperienceScreen()));
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "🎬 DID YOU CATCH ${_experiencePromptTitle?.toUpperCase()}?",
                        style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "LOG YOUR CINEMA EXPERIENCE →",
                        style: TextStyle(color: Color(0xFFD32F2F), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFFF4F4EC), size: 16),
                  onPressed: () async {
                    setState(() => _experiencePromptTitle = null);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('theatre_prompt_dismissed_date', DateTime.now().toIso8601String());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("QUICK ACCESS", style: TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3)),
              Expanded(child: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Divider(color: Color(0xFF111111), thickness: 1.5))),
              Text("///", style: TextStyle(color: Color(0xFF111111), fontSize: 18, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildCollectionCard(
                  title: "WATCHLIST",
                  subtitle: "YOUR WATCHLIST",
                  icon: Icons.bookmark_border_rounded,
                  isRed: true,
                  onTap: () => _showCollectionOverlay(const WatchlistTab(), "WATCHLIST"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCollectionCard(
                  title: "WATCHED",
                  subtitle: "WATCHED LIST",
                  icon: Icons.camera_roll_outlined,
                  isRed: false,
                  onTap: () => _showCollectionOverlay(const WatchedTab(), "WATCHED MOVIES"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCollectionCard(
                  title: "THE NEWS",
                  subtitle: "LIVE TRANSMISSIONS",
                  icon: Icons.newspaper_rounded,
                  isRed: false,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TheNewsScreen())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard({required String title, required String subtitle, required IconData icon, required bool isRed, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isRed ? const Color(0xFFC62828) : const Color(0xFFF4F4EC),
          border: Border.all(color: const Color(0xFF111111), width: 2.0),
          boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFF111111)),
              child: Icon(icon, color: const Color(0xFFF4F4EC), size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Impact',
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      style: TextStyle(
                        color: isRed ? const Color(0xFF111111) : const Color(0xFF454545),
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, color: Color(0xFF111111), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() => Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111111), size: 20),
            onPressed: _closeSearch,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmitted,
              style: const TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.bold),
              cursorColor: const Color(0xFFD32F2F),
              decoration: const InputDecoration(
                hintText: "SEARCH MOVIES & SERIES...",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Color(0xFF454545), fontSize: 13, letterSpacing: 2),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF111111), size: 22),
            onPressed: () => _onSearchSubmitted(_searchController.text),
          ),
        ],
      );

  Widget _buildSearchLogicUI() => Container(color: const Color(0xFFF4F4EC), width: double.infinity, height: double.infinity, child: _searchController.text.isEmpty ? _buildSearchHistoryUI() : _buildSearchResults());

  Widget _buildSearchHistoryUI() => SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Padding(padding: const EdgeInsets.only(top: 140, left: 24, right: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("RECENT INVESTIGATIONS", style: TextStyle(color: Color(0xFF454545), fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.bold)), const SizedBox(height: 20), if (_searchHistory.isEmpty) const Text("NO ARCHIVAL RECORDS YET", style: TextStyle(color: Color(0xFF454545), fontSize: 12, fontStyle: FontStyle.italic)), ..._searchHistory.map((query) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.history, color: Color(0xFF111111), size: 20), title: Text(query.toUpperCase(), style: const TextStyle(color: Color(0xFF111111), fontSize: 14, letterSpacing: 1, fontWeight: FontWeight.bold)), onTap: () {_searchController.text = query; _onSearchChanged(query);}))])));

  Widget _buildSearchResults() {
    if (_isWaitingForApi) return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
    if (_searchResults.isEmpty) return const Center(child: Text("NO RECORDS FOUND", style: TextStyle(color: Color(0xFF454545), letterSpacing: 4, fontWeight: FontWeight.bold)));
    return ListView.builder(padding: const EdgeInsets.only(top: 140, bottom: 40), itemCount: _searchResults.length, itemBuilder: (context, index) {
      final movie = _searchResults[index];
      final String displayName = movie.title.isNotEmpty ? movie.title : "UNKNOWN ENTITY";
      return Container(margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF4F4EC), borderRadius: BorderRadius.circular(2), border: Border.all(color: const Color(0xFF111111), width: 2), boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))]), child: ListTile(contentPadding: const EdgeInsets.all(12), onTap: () async {
        if (movie.isPerson) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => DirectorProfileScreen(personId: movie.id, name: displayName)));
        } else if (_quickAddContext == 'watchlist') {
          await _watchlistService.toggleMovieStatus(movie, 'watchlist');
          _closeSearch();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("ADDED ${movie.title.toUpperCase()} TO WATCHLIST 🎬", style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                backgroundColor: const Color(0xFF111111),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else if (_quickAddContext == 'watched') {
          _showDirectLogWatchedDialog(movie);
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)));
        }
      }, leading: ClipRRect(borderRadius: BorderRadius.circular(2), child: Image.network(movie.posterPath, width: 50, height: 75, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: const Color(0xFF111111), width: 50, child: Icon(movie.isPerson ? Icons.person : Icons.movie, color: const Color(0xFFF4F4EC))))), title: Text(displayName.toUpperCase(), style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis), subtitle: Text(movie.isPerson ? "ARCHIVAL PERSON" : (movie.releaseDate.contains('-') ? movie.releaseDate.split('-').first : movie.releaseDate), style: const TextStyle(color: Color(0xFF454545), fontSize: 10, fontWeight: FontWeight.bold)), trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF111111), size: 14)));
    });
  }


  Widget _buildNavIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF111111), size: 24),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF111111), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() => Align(
    alignment: Alignment.bottomCenter,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 65,
          width: double.infinity,
          decoration: const BoxDecoration(color: Color(0xFFF4F4EC), border: Border(top: BorderSide(color: Color(0xFF111111), width: 1.5))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavIcon(Icons.bookmark_border_rounded, "WATCHLIST", () => _showCollectionOverlay(const WatchlistTab(), "WATCHLIST")),
              _buildNavIcon(Icons.public_rounded, "EXPLORE", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WorldCinemaScreen()))),
              const SizedBox(width: 40),
              _buildNavIcon(Icons.sensors_rounded, "CINECAST", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BroadcastWireScreen()))),
              _buildNavIcon(Icons.confirmation_num_outlined, "HUB", () => _showCollectionOverlay(const ExperiencesTab(), "BEST EXPERIENCE HUB")),
            ],
          ),
        ),
        Positioned(
          top: -20,
          left: MediaQuery.of(context).size.width / 2 - 28,
          child: GestureDetector(
            onTap: _showQuickAddMenu,
            child: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF111111), width: 1.5),
                boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(2, 2))]
              ),
              child: const Icon(Icons.add, color: Color(0xFFF4F4EC), size: 28),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProjectorBeamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset source = Offset(size.width / 2, -40);
    final Path beamPath = Path()..moveTo(source.dx, source.dy)..lineTo(size.width * 0.06, size.height * 0.07)..lineTo(size.width * 0.94, size.height * 0.07)..close();
    final Paint beamPaint = Paint()..shader = RadialGradient(center: const Alignment(0, -1.2), radius: 1.5, colors: [const Color(0xFF111111).withOpacity(0.05), Colors.transparent]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(beamPath, beamPaint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class RollingCreditsBackground extends StatefulWidget {
  final bool isPaused;
  final ScrollController mainScrollController;
  const RollingCreditsBackground({super.key, required this.isPaused, required this.mainScrollController});
  @override
  State<RollingCreditsBackground> createState() => _RollingCreditsBackgroundState();
}

class _RollingCreditsBackgroundState extends State<RollingCreditsBackground> {
  late ScrollController _creditsScrollController;
  Timer? _creditsTimer;
  final List<Map<String, String>> movieSets = [{"role": "DIRECTED BY", "name": "CHRISTOPHER NOLAN"}, {"role": "PRODUCED BY", "name": "EMMA THOMAS"}, {"role": "WRITTEN BY", "name": "QUENTIN TARANTINO"}, {"role": "CINEMATOGRAPHY BY", "name": "ROGER DEAKINS"}, {"role": "MUSIC BY", "name": "HANS ZIMMER"}];

  @override
  void initState() {
    super.initState();
    _creditsScrollController = ScrollController();
    _startCreditsScroll();
  }

  void _startCreditsScroll() {
    _creditsTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!widget.isPaused && _creditsScrollController.hasClients) {
        // OPTIMIZATION: Pause scrolling if the main list is scrolled down (covered) to prevent rendering lag
        final bool isCovered = widget.mainScrollController.hasClients && widget.mainScrollController.offset > 150;
        if (isCovered) return;

        double maxScroll = _creditsScrollController.position.maxScrollExtent;
        double currentScroll = _creditsScrollController.offset;
        if (currentScroll >= maxScroll - 5) {
          _creditsScrollController.jumpTo(0);
        } else {
          _creditsScrollController.jumpTo(currentScroll + 0.8);
        }
      }
    });
  }

  @override
  void dispose() {
    _creditsTimer?.cancel();
    _creditsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('movies').where('status', isEqualTo: 'watched').snapshots(), builder: (context, snapshot) {
      List<String> watchedTitles = [];
      if (snapshot.hasData) watchedTitles = snapshot.data!.docs.map((doc) => (doc.data() as Map<String, dynamic>)['title']?.toString().toUpperCase() ?? "").toList();
      return Opacity(opacity: 0.35, child: ListView.builder(controller: _creditsScrollController, itemCount: 1000, itemBuilder: (context, index) {
        bool isPersonal = watchedTitles.isNotEmpty && (index % 4 == 3);
        String role, name;
        if (isPersonal) {role = "FROM YOUR ARCHIVE"; name = watchedTitles[(index ~/ 4) % watchedTitles.length];} else {final set = movieSets[index % movieSets.length]; role = set['role']!; name = set['name']!;}
        return Container(height: 150, alignment: Alignment.center, child: Column(mainAxisSize: MainAxisSize.min, children: [Text(role, style: TextStyle(color: isPersonal ? const Color(0xFFC62828) : const Color(0xFF454545), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 4, fontFamily: 'monospace')), const SizedBox(height: 10), Text(name, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF111111), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 8, fontFamily: 'serif'))]));
      }));
    });
  }
}

class CarouselPlaceholder extends StatefulWidget {
  final String title;
  final bool isSeries;
  const CarouselPlaceholder({super.key, required this.title, this.isSeries = false});
  @override
  State<CarouselPlaceholder> createState() => _CarouselPlaceholderState();
}

class _CarouselPlaceholderState extends State<CarouselPlaceholder> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color accent = widget.isSeries ? Colors.blueAccent : const Color(0xFFD32F2F);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: TextStyle(color: accent, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(widget.isSeries ? "Tailored to your streaming preferences" : "Based on your Archival DNA", style: const TextStyle(color: Color(0xFF454545), fontSize: 9)),
            ]
          )
        ), 
        const SizedBox(height: 10), 
        SizedBox(
          height: 220, 
          child: AnimatedBuilder(
            animation: _shimmerController, 
            builder: (context, child) => ListView.builder(
              scrollDirection: Axis.horizontal, 
              padding: const EdgeInsets.only(left: 12), 
              physics: const NeverScrollableScrollPhysics(), 
              itemCount: 3, 
              itemBuilder: (context, index) {
                return Container(
                  width: 270, 
                  height: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), 
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4EC), 
                    borderRadius: BorderRadius.circular(2), 
                    border: Border.all(color: const Color(0xFF111111), width: 2), 
                    boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))]
                  ), 
                  child: Stack(
                    children: [
                      Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: CustomPaint(painter: _ShimmerPainter(progress: _shimmerController.value)))), 
                      Center(child: Icon(Icons.movie_filter, color: accent.withOpacity(0.08), size: 40))
                    ]
                  )
                );
              }
            )
          )
        ),
        const SizedBox(height: 10),
      ]
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;
  _ShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final double width = size.width, height = size.height, offset = width * (progress * 2 - 1);
    paint.shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.transparent, Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.15), Colors.black.withOpacity(0.05), Colors.transparent], stops: const [0.1, 0.4, 0.5, 0.6, 0.9]).createShader(Rect.fromLTWH(offset, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) => oldDelegate.progress != progress;
}

class ArchiveRank {
  static Color getColor(int count) {
    if (count >= 100) return const Color(0xFFFFD700);
    if (count >= 50) return const Color(0xFFC0C0C0);
    if (count >= 20) return const Color(0xFFCD7F32);
    return const Color(0xFFD32F2F);
  }
}
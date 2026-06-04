import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/news_item.dart';
import '../../models/movie_model.dart';
import '../../services/news_service.dart';
import '../../services/watchlist_service.dart';
import '../../movie_details_screen.dart';

class TheNewsScreen extends StatefulWidget {
  const TheNewsScreen({super.key});

  @override
  State<TheNewsScreen> createState() => _TheNewsScreenState();
}

class _TheNewsScreenState extends State<TheNewsScreen> {
  final NewsService _newsService = NewsService();
  final WatchlistService _watchlistService = WatchlistService();
  
  List<NewsItem> _items = [];
  bool _isLoading = true;
  String? _error;
  String _selectedRegion = 'ALL';
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchNews({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _newsService.fetchAndMerge(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "FEED DISRUPTION: UNABLE TO SYNCHRONIZE TRANSMISSIONS";
          _isLoading = false;
        });
      }
    }
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }

  void _showBroadcastSheet(NewsItem item) {
    final reasonController = TextEditingController();
    bool isBroadcasting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F4EC),
              border: Border(top: BorderSide(color: Color(0xFF111111), width: 3.0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(height: 4, width: 40, color: const Color(0xFF111111))),
                const SizedBox(height: 16),
                const Text(
                  "BROADCAST NEWS",
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFamily: 'Impact',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    border: Border.all(color: const Color(0xFF111111), width: 2),
                  ),
                  child: Row(
                    children: [
                      if (item.imageUrl != null)
                        Image.network(item.imageUrl!, width: 50, height: 75, fit: BoxFit.cover)
                      else
                        Container(width: 50, height: 75, color: const Color(0xFF222222), child: const Icon(Icons.article, color: Color(0xFFF4F4EC))),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${item.sourceName.toUpperCase()} · ${_formatTimeAgo(item.publishedAt).toUpperCase()}",
                              style: TextStyle(color: const Color(0xFFF4F4EC).withOpacity(0.5), fontSize: 8, letterSpacing: 1),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.title.toUpperCase(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'Impact', letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "REASON FOR TRANSMISSION",
                  style: TextStyle(color: Color(0xFF111111), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4EC),
                    border: Border.all(color: const Color(0xFF111111), width: 2.0),
                  ),
                  child: TextField(
                    controller: reasonController,
                    maxLines: 4,
                    style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: "E.G. MASSIVE NEWS FOR CINEMA...",
                      hintStyle: TextStyle(color: Color(0xFF888882), fontSize: 11),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: isBroadcasting ? null : () async {
                    final reason = reasonController.text.trim();
                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PLEASE WRITE A REASON!"), backgroundColor: Color(0xFFD32F2F)));
                      return;
                    }
                    setSheetState(() => isBroadcasting = true);
                    try {
                      await _watchlistService.broadcastNews(item.title, item.sourceName, item.articleUrl, item.imageUrl, reason);
                      if (mounted) Navigator.pop(context);
                      HapticFeedback.heavyImpact();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("NEWS TRANSMITTED! 📡"), backgroundColor: Color(0xFF111111)));
                    } catch (_) {
                      setSheetState(() => isBroadcasting = false);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      border: Border.all(color: const Color(0xFF111111), width: 2.0),
                      boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
                    ),
                    child: Center(
                      child: isBroadcasting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xFFF4F4EC), strokeWidth: 2))
                          : const Text("TRANSMIT TO COMMUNITY", style: TextStyle(color: Color(0xFFF4F4EC), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, fontFamily: 'Impact')),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openArticle(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("COULD NOT OPEN ARTICLE"), 
            backgroundColor: Color(0xFFD32F2F)
          )
        );
      }
    }
  }

  void _openMovieDossier(NewsItem item) {
    if (item.tmdbMatchId == null) return;
    
    // Create a minimal MovieModel for navigation
    final movie = MovieModel(
      id: item.tmdbMatchId!,
      title: item.tmdbMatchTitle ?? 'Unknown',
      overview: '',
      posterPath: '', // Will be fetched inside Details screen if needed
      voteAverage: 0.0,
      releaseDate: '',
      genreIds: [],
      isTvShow: item.tmdbMatchIsTv ?? false,
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: movie)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4EC),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF111111)),
        title: const Text(
          "THE NEWS",
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            fontFamily: 'Impact',
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(color: const Color(0xFF111111), height: 1.5),
        ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search, color: Color(0xFF111111)),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF111111)),
            onPressed: () => _fetchNews(forceRefresh: true),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (context, index) => _buildSkeletonCard(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: const Color(0xFFF4F4EC),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                side: const BorderSide(color: Color(0xFF111111), width: 2),
              ),
              onPressed: () => _fetchNews(forceRefresh: true),
              child: const Text("RETRY SYNCHRONIZATION", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Column(
        children: [
          _buildFilterPills(),
          const Expanded(
            child: Center(
              child: Text("NO TRANSMISSIONS AVAILABLE", style: TextStyle(color: Color(0xFF888882), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    var filteredItems = _selectedRegion == 'ALL' 
        ? _items 
        : _items.where((item) => item.region == _selectedRegion).toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      final now = DateTime.now();
      filteredItems = filteredItems.where((item) {
        final matchesText = item.title.toLowerCase().contains(query) || 
            item.snippet.toLowerCase().contains(query) ||
            item.sourceName.toLowerCase().contains(query);
            
        bool within7Days = true;
        if (item.publishedAt != null) {
          within7Days = now.difference(item.publishedAt!).inDays <= 7;
        }
        
        return matchesText && within7Days;
      }).toList();
    }

    return Column(
      children: [
        if (_isSearching)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            margin: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Color(0xFF111111), fontFamily: 'Inter', fontSize: 14),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: "Search news...",
                hintStyle: const TextStyle(color: Color(0xFF888882)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF888882), size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF888882), size: 20),
                  onPressed: () {
                    setState(() {
                      if (_searchQuery.isEmpty) {
                        _isSearching = false;
                      } else {
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    });
                  },
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFE5E5E5), // Light subtle grey
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        _buildFilterPills(),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFD32F2F),
            onRefresh: () => _fetchNews(forceRefresh: true),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                if (index == 0) {
                  return _buildHeroNewsCard(item);
                }
                return _buildNewsCard(item);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPills() {
    final regions = ['ALL', 'HOLLYWOOD', 'INDIAN CINEMA', 'ANIME', 'MARVEL'];
    return Container(
      height: 36,
      margin: const EdgeInsets.only(top: 10, bottom: 20),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: regions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final region = regions[index];
          final isSelected = region == _selectedRegion;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedRegion = region);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF111111).withValues(alpha: 0.85) 
                        : const Color(0xFF111111).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected 
                          ? Colors.transparent 
                          : const Color(0xFF111111).withValues(alpha: 0.2), 
                      width: 1
                    ),
                  ),
                  child: Text(
                    region,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFF4F4EC) : const Color(0xFF111111),
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      fontFamily: 'Inter',
                      letterSpacing: 1.0,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFFEBEBE4),
        border: Border.all(color: const Color(0xFF111111), width: 2),
        boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
      ),
    );
  }

  Widget _buildNewsCard(NewsItem item) {
    return GestureDetector(
      onTap: () => _openArticle(item.articleUrl),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showBroadcastSheet(item);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC),
          border: Border.all(color: const Color(0xFF111111), width: 2),
          boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Container(
                  width: 100,
                  height: 120,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFF111111), width: 2)),
                  ),
                  child: item.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => _buildPlaceholderImage(),
                        )
                      : _buildPlaceholderImage(),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${item.sourceName.toUpperCase()} · ${_formatTimeAgo(item.publishedAt).toUpperCase()}",
                          style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title.toUpperCase(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Impact',
                            letterSpacing: 0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF454545),
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Action Chips
            _buildActionChips(item),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroNewsCard(NewsItem item) {
    return GestureDetector(
      onTap: () => _openArticle(item.articleUrl),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showBroadcastSheet(item);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big Thumbnail
            SizedBox(
              width: double.infinity,
              height: 250,
              child: item.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => _buildPlaceholderImage(),
                    )
                  : _buildPlaceholderImage(),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${item.sourceName.toUpperCase()} · ${_formatTimeAgo(item.publishedAt).toUpperCase()}",
                    style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title.toUpperCase(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Impact',
                      letterSpacing: 0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.snippet,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF454545),
                      fontSize: 13,
                      height: 1.4,
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

  Widget _buildActionChips(NewsItem item) {
    return Column(
              children: [
                if (item.tmdbMatchId != null)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openMovieDossier(item);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF111111),
                        border: Border(top: BorderSide(color: Color(0xFF111111), width: 2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.movie_creation_outlined, color: Color(0xFFF4F4EC), size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "VIEW FILM: ${item.tmdbMatchTitle?.toUpperCase()}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Color(0xFFF4F4EC), size: 10),
                        ],
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _openArticle(item.articleUrl);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4F4EC),
                      border: Border(top: BorderSide(color: Color(0xFF111111), width: 2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.article_outlined, color: Color(0xFF111111), size: 14),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "READ FULL ARTICLE",
                            style: TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                        Icon(Icons.open_in_new, color: Color(0xFF111111), size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: const Color(0xFF111111),
      child: const Center(
        child: Icon(Icons.newspaper, color: Color(0xFFF4F4EC), size: 32),
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/movie_model.dart';
import '../movie_details_screen.dart';
import '../../../services/movie_service.dart';
import '../../../services/watchlist_service.dart';

import '../data/dialogues_data.dart';

class SeriesRecommendationCarousel extends StatefulWidget {
  final Map<String, dynamic>? data;
  const SeriesRecommendationCarousel({super.key, this.data});

  @override
  State<SeriesRecommendationCarousel> createState() => _SeriesRecommendationCarouselState();
}

class _SeriesRecommendationCarouselState extends State<SeriesRecommendationCarousel> {
  late PageController _pageController;
  double _currentPage = 0.0;
  final WatchlistService _watchlistService = WatchlistService();
  final MovieService _movieService = MovieService();
  final Set<int> _dismissedSeriesIds = {};

  static const Color seriesBlue = Color(0xFF111111);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92, initialPage: 0);
    _pageController.addListener(() {
      if (mounted) setState(() => _currentPage = _pageController.page!);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showQuickActions(BuildContext context, MovieModel series) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierColor: const Color(0xFFF4F4EC).withOpacity(0.85),
      builder: (context) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4EC),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFF111111), width: 2),
                boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.network(series.posterPath, height: 160, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 20),
                  Text(series.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1, decoration: TextDecoration.none)),
                  const SizedBox(height: 25),
                  _buildActionButton(context, icon: Icons.bookmark_add_outlined, label: "ADD TO WATCHLIST", onTap: () {
                    _watchlistService.toggleMovieStatus(series, 'watchlist');
                    Navigator.pop(context);
                    _showToast(context, "ADDED TO WATCHLIST");
                  }),
                  const Divider(color: Color(0xFF111111), height: 1),
                  _buildActionButton(context, icon: Icons.check_circle_outline, label: "MARK AS FINISHED", onTap: () async {
                    await _watchlistService.toggleMovieStatus(series, 'watched');
                    Navigator.pop(context);
                    _showToast(context, "ADDED TO WATCHED SERIES");
                  }),
                  const Divider(color: Color(0xFF111111), height: 1),
                  _buildActionButton(context, icon: Icons.not_interested_rounded, label: "DISMISS PERMANENTLY", color: const Color(0xFF454545), onTap: () async {
                    await _movieService.permanentlyDismissMovie(series.id);
                    setState(() => _dismissedSeriesIds.add(series.id));
                    Navigator.pop(context);
                    _showToast(context, "DISMISSED PERMANENTLY");
                  }),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10), child: Row(children: [Icon(icon, color: color ?? seriesBlue, size: 20), const SizedBox(width: 15), Text(label, style: TextStyle(color: color ?? const Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2))])),
    );
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)), backgroundColor: const Color(0xFF111111), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2), side: const BorderSide(color: Color(0xFFC62828), width: 2)), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data == null || widget.data!['movies'] == null) return const SizedBox.shrink();
    final List<MovieModel> seriesList = (widget.data!['movies'] as List).map((m) => m is MovieModel ? m : MovieModel.fromJson(m)).where((m) => !_dismissedSeriesIds.contains(m.id)).toList();
    if (seriesList.isEmpty) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text("NO SERIES FOUND",
                  style: TextStyle(color: Color(0xFF454545), letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 12)),
              SizedBox(height: 6),
              Text("Rate more series to improve your Streaming DNA",
                  style: TextStyle(color: Color(0xFF454545), fontSize: 9)),
            ],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              itemCount: seriesList.length,
              itemBuilder: (context, index) => _buildEyeCatchyCard(seriesList[index], index),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: _SeriesIndicator(offset: _currentPage, itemCount: seriesList.length)),
        ],
      ),
    );
  }

  String _formatVoteCount(double rating) {
    final count = (rating * 133).round();
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildEyeCatchyCard(MovieModel series, int index) {
    double relativePosition = index - _currentPage;
    final String currentTitle = widget.data!['title']?.toString().toUpperCase() ?? "";
    bool isDirectorMatch = false;
    if (series.director != null && currentTitle.contains(series.director!.split(' ').last.toUpperCase())) {
      isDirectorMatch = true;
    }

    // Try to find a curated dialogue quote
    String displayQuote = "";
    String displayChar = "";
    for (var dial in MovieDialogue.dialogues) {
      if (dial.movieTitle.toUpperCase() == series.title.toUpperCase() || dial.tmdbId == series.id) {
        displayQuote = dial.quote;
        displayChar = dial.character;
        break;
      }
    }
    if (displayQuote.isEmpty) {
      displayQuote = series.overview.isNotEmpty ? series.overview : "A series that perfectly matches your viewing habits.";
      displayChar = series.director?.toUpperCase() ?? "ARCHIVAL SERIES";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        border: Border.all(color: const Color(0xFF111111), width: 2.0),
        boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(4, 4))]
      ),
      child: GestureDetector(
        onLongPress: () => _showQuickActions(context, series),
        onTap: () {
          if (relativePosition.abs() < 0.1) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: series)));
          } else {
            _pageController.animateToPage(index, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
          }
        },
        child: Row(
          children: [
            // LEFT SIDE: POSTER + TITLE OVERLAY
            Container(
              width: 130,
              decoration: BoxDecoration(
                border: const Border(right: BorderSide(color: Color(0xFF111111), width: 2.0)),
                image: DecorationImage(
                  image: NetworkImage(series.posterPath),
                  fit: BoxFit.cover,
                )
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xD9000000)],
                          stops: [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 12,
                    child: Text(
                      series.title.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFF4F4EC),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Impact',
                        letterSpacing: 0.2,
                        height: 1.0,
                        shadows: [
                          Shadow(color: Color(0xD9000000), offset: Offset(1, 1), blurRadius: 4),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // RIGHT SIDE: DETAILS (Quote, label, icons)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (series.broadcastReason?.startsWith('✨') == true)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              color: const Color(0xFF1A4A1A),
                              child: const Text('✨ EXPLORING',
                                  style: TextStyle(color: Color(0xFF66FF66), fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            color: const Color(0xFFD32F2F),
                            child: Text(
                              isDirectorMatch
                                  ? (series.director?.toUpperCase() ?? 'CURATED PICK')
                                  : 'CURATED PICK',
                              style: const TextStyle(color: Color(0xFFF4F4EC), fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Center(
                        child: Text(
                          "\"$displayQuote\"",
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 10,
                            height: 1.15,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'serif',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayChar.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF454545),
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailsScreen(movie: series))),
                      child: Text(
                        "READ MORE",
                        style: TextStyle(
                          color: const Color(0xFFD32F2F),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFFD32F2F).withOpacity(0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.favorite_border_rounded, color: Color(0xFF111111), size: 14),
                            const SizedBox(width: 4),
                            Text(_formatVoteCount(series.voteAverage), style: const TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const Icon(Icons.bookmark_border_rounded, color: Color(0xFF111111), size: 16),
                      ],
                    ),
                    if (series.broadcastReason != null && series.broadcastReason!.isNotEmpty) ...[  
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        color: const Color(0xFFEEEEE6),
                        child: Text(
                          series.broadcastReason!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF454545),
                            fontSize: 7.5,
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          ]
        ),
      ),
    );
  }


}

class _SeriesIndicator extends StatelessWidget {
  final double offset; final int itemCount;
  const _SeriesIndicator({required this.offset, required this.itemCount});
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 30, width: 200, child: CustomPaint(painter: _SeriesStripPainter(offset: offset, itemCount: itemCount)));
  }
}

class _SeriesStripPainter extends CustomPainter {
  final double offset; final int itemCount;
  _SeriesStripPainter({required this.offset, required this.itemCount});
  @override
  void paint(Canvas canvas, Size size) {
    final Rect shaderRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Shader fadeShader = const LinearGradient(colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent], stops: [0.0, 0.2, 0.8, 1.0]).createShader(shaderRect);
    final basePaint = Paint()..color = Colors.black.withOpacity(0.15)..shader = fadeShader;
    final activePaint = Paint()..color = const Color(0xFF111111);
    final centerFillPaint = Paint()..color = const Color(0xFF111111).withOpacity(0.1);
    for (int i = 0; i < 20; i++) {
      double x = (i * 15.0) - (offset * 40 % 15.0);
      canvas.drawRect(Rect.fromLTWH(x, 4, 4, 4), basePaint);
      canvas.drawRect(Rect.fromLTWH(x, size.height - 8, 4, 4), basePaint);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 28, height: 18), const Radius.circular(2)), centerFillPaint);
    canvas.drawRect(Rect.fromLTWH(size.width / 2 - 14, size.height / 2 - 9, 2, 18), activePaint);
    canvas.drawRect(Rect.fromLTWH(size.width / 2 + 12, size.height / 2 - 9, 2, 18), activePaint);
  }
  @override bool shouldRepaint(covariant _SeriesStripPainter oldDelegate) => oldDelegate.offset != offset;
}
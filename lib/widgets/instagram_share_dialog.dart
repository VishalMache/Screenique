import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie_model.dart';

enum ShareMode { detailed, minimal }

class InstagramShareDialog extends StatefulWidget {
  final MovieModel movie;
  final double rating;
  final String? watchedAt;

  const InstagramShareDialog({
    super.key,
    required this.movie,
    required this.rating,
    this.watchedAt,
  });

  static void show(BuildContext context, MovieModel movie, double rating, String? watchedAt) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "InstagramShareDialog",
      barrierColor: const Color(0xFFF4F4EC),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return InstagramShareDialog(
          movie: movie,
          rating: rating,
          watchedAt: watchedAt,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<InstagramShareDialog> createState() => _InstagramShareDialogState();
}

class _InstagramShareDialogState extends State<InstagramShareDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;
  ShareMode _shareMode = ShareMode.detailed;

  Future<void> _shareToInstagram() async {
    if (_isSharing) return;
    setState(() {
      _isSharing = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final image = await _screenshotController.capture(
        pixelRatio: 3.0, 
      );

      if (image != null) {
        final directory = await getTemporaryDirectory();
        final fileName = 'screenique_share_${widget.movie.id}_${DateTime.now().millisecondsSinceEpoch}.png';
        final imageFile = await File('${directory.path}/$fileName').create();
        await imageFile.writeAsBytes(image);

        await Share.shareXFiles(
          [XFile(imageFile.path)],
          text: 'Watched ${widget.movie.title} with a rating of ${widget.rating} on Screenique! 🎬🍿',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("SHARING PROTOCOL INITIATED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              backgroundColor: Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception("Failed to render story card image.");
      }
    } catch (e) {
      debugPrint("Instagram story share error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("SHARING FAILED: ${e.toString().toUpperCase()}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Widget _buildStarRating(double rating, Color color, {double size = 14}) {
    List<Widget> stars = [];
    int fullStars = rating.floor();
    bool hasHalf = (rating - fullStars) >= 0.25 && (rating - fullStars) < 0.75;
    if ((rating - fullStars) >= 0.75) {
      fullStars++;
    }
    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(Icon(Icons.star, color: color, size: size));
      } else if (i == fullStars && hasHalf) {
        stars.add(Icon(Icons.star_half, color: color, size: size));
      } else {
        stars.add(Icon(Icons.star_border, color: Colors.white.withOpacity(0.2), size: size));
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: stars,
    );
  }

  Widget _buildDetailedLayout(String userName, String year) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Spacing (Safe Area equivalent)
        const SizedBox(height: 50),
        
        // Top Section: Poster & Details
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Left: Poster
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.movie.posterPath,
                    width: 100,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 100,
                      height: 150,
                      color: const Color(0xFF111111),
                      child: const Icon(Icons.movie, color: Colors.white38),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              
              // Right side: Username, Title, Rating, Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username
                    Text(
                      userName.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Tiny red accent line below username
                    Container(
                      width: 20,
                      height: 1.5,
                      color: const Color(0xFFE53935),
                      margin: const EdgeInsets.only(top: 6, bottom: 12),
                    ),
                    
                    // Title
                    Text(
                      widget.movie.title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: 0.5,
                        height: 1.2,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Year
                    Text(
                      year,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Star Rating
                    _buildStarRating(widget.rating, const Color(0xFFE53935), size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Review Body
        if (widget.movie.personalNote != null && widget.movie.personalNote!.trim().isNotEmpty) ...[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.movie.personalNote!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.fade,
              ),
            ),
          ),
        ] else ...[
          const Spacer(),
        ],
        
        // Footer Logo Section
        _buildFooter(),
      ],
    );
  }

  Widget _buildMinimalLayout(String userName, String year) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40), // Safe area equivalent
        
        // Logo at top
        Center(
          child: Image.asset(
            'assets/logo12.png',
            width: 100,
            fit: BoxFit.contain,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        
        const Spacer(flex: 2),
        
        // Large Center Poster
        Center(
          child: Container(
            width: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: Image.network(
                  widget.movie.posterPath,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: const Color(0xFF111111),
                    child: const Icon(Icons.movie, color: Colors.white38, size: 50),
                  ),
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 30),
        
        // Movie Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            widget.movie.title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Huge Star Rating
        Center(
          child: _buildStarRating(widget.rating, const Color(0xFFE53935), size: 22),
        ),
        
        const SizedBox(height: 16),
        
        // User Name tag
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline, color: Colors.white.withOpacity(0.7), size: 12),
                const SizedBox(width: 6),
                Text(
                  userName.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const Spacer(flex: 3),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Image.asset(
          'assets/logo12.png',
          width: 100,
          fit: BoxFit.contain,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final year = widget.movie.releaseDate != 'N/A' && widget.movie.releaseDate.length >= 4
        ? widget.movie.releaseDate.substring(0, 4)
        : 'N/A';

    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? (user?.email != null ? user!.email!.split('@')[0] : 'CINEPHILE');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "STORY CARD PREVIEW",
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.black54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Toggle Switch
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF111111).withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _shareMode = ShareMode.detailed),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _shareMode == ShareMode.detailed ? const Color(0xFF111111) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text("Full Review", style: TextStyle(color: _shareMode == ShareMode.detailed ? Colors.white : const Color(0xFF454545), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _shareMode = ShareMode.minimal),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _shareMode == ShareMode.minimal ? const Color(0xFF111111) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text("Just Rating", style: TextStyle(color: _shareMode == ShareMode.minimal ? Colors.white : const Color(0xFF454545), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Flexible(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF111111).withOpacity(0.12), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF111111).withOpacity(0.08),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14.5),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Screenshot(
                        controller: _screenshotController,
                        child: Stack(
                          children: [
                            // 1. Full Screen Blurred Poster Background (Acts as the frosted container)
                            Positioned.fill(
                              child: Image.network(
                                widget.movie.posterPath,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(color: const Color(0xFF111111)),
                              ),
                            ),
                            // Dark heavy overlay
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.85),
                              ),
                            ),
                            // Blur filter for the entire screen
                            Positioned.fill(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                                child: Container(color: Colors.transparent),
                              ),
                            ),

                            // 2. Full Screen Content Layout
                            Positioned.fill(
                              child: _shareMode == ShareMode.detailed 
                                  ? _buildDetailedLayout(userName, year)
                                  : _buildMinimalLayout(userName, year),
                            ),
                          ],
                      ),
                    );
                },
              ),
              ),
            ),
          ),
          ),
          const SizedBox(height: 20),

          // Glassmorphic Share Action Button
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF833AB4), // Instagram Purple
                  Color(0xFFFD1D1D), // Instagram Red
                  Color(0xFFF56040), // Instagram Orange
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFD1D1D).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: _shareToInstagram,
              child: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Instagram_logo_2016.svg/132px-Instagram_logo_2016.svg.png',
                          width: 18,
                          height: 18,
                          color: Colors.white,
                          errorBuilder: (c, e, s) => const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "SHARE TO INSTAGRAM STORY",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

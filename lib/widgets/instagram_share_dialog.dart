import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie_model.dart';

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
      barrierColor: Colors.black87,
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

  Widget _buildStarRating(double rating, Color color) {
    List<Widget> stars = [];
    int fullStars = rating.floor();
    bool hasHalf = (rating - fullStars) >= 0.25 && (rating - fullStars) < 0.75;
    if ((rating - fullStars) >= 0.75) {
      fullStars++;
    }
    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(Icon(Icons.star, color: color, size: 14));
      } else if (i == fullStars && hasHalf) {
        stars.add(Icon(Icons.star_half, color: color, size: 14));
      } else {
        stars.add(Icon(Icons.star_border, color: color.withOpacity(0.2), size: 14));
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: stars,
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = widget.watchedAt != null
        ? DateFormat('MMMM d, yyyy').format(DateTime.parse(widget.watchedAt!))
        : DateFormat('MMMM d, yyyy').format(DateTime.now());

    final year = widget.movie.releaseDate != 'N/A' && widget.movie.releaseDate.length >= 4
        ? widget.movie.releaseDate.substring(0, 4)
        : 'N/A';

    // Resolve current user display name
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
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 9:16 Aspect Ratio Instagram Story Card
          Flexible(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white10, width: 1),
                  ),
                  child: Screenshot(
                    controller: _screenshotController,
                    child: Stack(
                      children: [
                        // Background Deep Charcoal to Midnight Red Gradient
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF08080C),
                                Color(0xFF140707),
                                Color(0xFF030305),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),

                        // Glowing Ambient Backlight behind the poster for a premium 3D neon look
                        Positioned(
                          top: 80,
                          left: 40,
                          right: 40,
                          child: Container(
                            height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD32F2F).withOpacity(0.18),
                                  blurRadius: 100,
                                  spreadRadius: 30,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Main Story Layout Elements
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top Brand Banner (Rebranded to WATCHED)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "SCREENIQUE",
                                        style: TextStyle(
                                          color: Colors.white30,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        "THE FILM ARCHIVE",
                                        style: TextStyle(
                                          color: Colors.white10,
                                          fontSize: 6,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD32F2F).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3), width: 0.5),
                                    ),
                                    child: const Text(
                                      "WATCHED ENTRY",
                                      style: TextStyle(
                                        color: Color(0xFFD32F2F),
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(flex: 2),

                              // Screenique brand name placed centered just above the poster
                              const Center(
                                child: Text(
                                  "SCREENIQUE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Movie Poster (Premium Outline & Glow Shadow)
                              Center(
                                child: Container(
                                  width: 170,
                                  height: 250,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.6),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      widget.movie.posterPath,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(
                                        color: const Color(0xFF15151A),
                                        child: const Icon(Icons.movie_outlined, color: Colors.white24, size: 40),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(flex: 3),

                              // Solid Dark Charcoal Details Card (No Glassmorphism)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111115), // Solid premium dark background
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Movie Title & Year
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                widget.movie.title.toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                  letterSpacing: 1,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "RELEASED: $year  |  ${widget.movie.isTvShow ? "SERIES" : "MOVIE"}",
                                                style: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Digital Rating Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD32F2F),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            widget.rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(color: Colors.white10, height: 16, thickness: 1),

                                    // Stars & Log Date (Rebranded to WATCHED)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildStarRating(widget.rating, const Color(0xFFFFB300)),
                                        Text(
                                          "WATCHED: $formattedDate",
                                          style: const TextStyle(
                                            color: Colors.white24,
                                            fontSize: 7,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // User Review Section (Custom styled, personalized)
                                    const SizedBox(height: 8),
                                    const Divider(color: Colors.white10, height: 16, thickness: 1),
                                    Text(
                                      "${userName.toUpperCase()}'S REVIEW:",
                                      style: const TextStyle(
                                        color: Color(0xFFD32F2F),
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      widget.movie.personalNote != null && widget.movie.personalNote!.trim().isNotEmpty
                                          ? '"${widget.movie.personalNote}"'
                                          : '"No review logged..."',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 9.5,
                                        fontStyle: FontStyle.italic,
                                        height: 1.4,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(flex: 3),
                            ],
                          ),
                        ),
                      ],
                    ),
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
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
        stars.add(Icon(Icons.star_border, color: color.withOpacity(0.2), size: size));
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: stars,
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.movie.isTvShow ? "SERIES" : "MOVIE";
    final genre = widget.movie.genreNames.split(',').first.trim().toUpperCase();
    final year = widget.movie.releaseDate != 'N/A' && widget.movie.releaseDate.length >= 4
        ? widget.movie.releaseDate.substring(0, 4)
        : 'N/A';
    final metadata = "$type • $genre • $year";

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
          const SizedBox(height: 10),

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
                            // Background Cream (Matches app's core UI!)
                            Container(
                              color: const Color(0xFFF4F4EC),
                            ),

                            // Film Roll Graphics Background
                            Positioned.fill(
                              child: CustomPaint(
                                painter: FilmRollPainter(),
                              ),
                            ),

                            // Main Story Layout Elements
                            Positioned.fill(
                              child: Padding(
                          padding: const EdgeInsets.only(left: 24, right: 24, top: 10, bottom: 16), // Moved logo upside
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo asset instead of text branding
                              Center(
                                child: Image.asset(
                                  'assets/logo12.png',
                                  width: 150, // Decreased logo size a bit
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 4), // Move content below it upside

                              // Movie Poster (Dynamically scales down for long paragraphs)
                              Flexible(
                                flex: 3,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 225),
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: 2 / 3,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFF111111), width: 2),
                                        ),
                                        child: Image.network(
                                          widget.movie.posterPath,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Container(
                                            color: const Color(0xFF111111),
                                            child: const Icon(Icons.movie_outlined, color: Color(0xFFF4F4EC), size: 40),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Movie Title (Clean and Simple)
                              Center(
                                child: Text(
                                  widget.movie.title.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF111111),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    fontFamily: 'Impact',
                                    letterSpacing: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Metadata (Type • Genre • Year) in low opacity
                              Center(
                                child: Text(
                                  metadata,
                                  style: TextStyle(
                                    color: const Color(0xFF111111).withOpacity(0.5),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Rating Row (Large size, NO digits, only stars)
                              Center(
                                child: _buildStarRating(widget.rating, const Color(0xFF111111), size: 24),
                              ),

                              // User Review Section (Only visible if not empty)
                              if (widget.movie.personalNote != null && widget.movie.personalNote!.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.topCenter,
                                            child: SizedBox(
                                              width: constraints.maxWidth - 48, // Total padding is 24 on each side
                                              child: Text(
                                                '"${widget.movie.personalNote}"',
                                                style: const TextStyle(
                                                  color: Color(0xFF111111),
                                                  fontSize: 14.0,
                                                  fontStyle: FontStyle.italic,
                                                  height: 1.4,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "— ${userName.toUpperCase()}",
                                          style: TextStyle(
                                            color: const Color(0xFF111111).withOpacity(0.6),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                            ],
                          ),
                        ),
                          ), // Closes Positioned.fill
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

class FilmRollPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111111).withOpacity(0.06)
      ..style = PaintingStyle.fill;

    double holeWidth = 14.0;
    double holeHeight = 22.0;
    double spacing = 12.0;
    double paddingX = 12.0;

    // Draw sprocket holes
    for (double y = 15; y < size.height; y += holeHeight + spacing) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(paddingX, y, holeWidth, holeHeight),
          const Radius.circular(4),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width - paddingX - holeWidth, y, holeWidth, holeHeight),
          const Radius.circular(4),
        ),
        paint,
      );
    }
    
    // Draw subtle vertical separator lines
    final linePaint = Paint()
      ..color = const Color(0xFF111111).withOpacity(0.04)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
      
    double leftLineX = paddingX * 2 + holeWidth;
    double rightLineX = size.width - (paddingX * 2 + holeWidth);
    
    canvas.drawLine(Offset(leftLineX, 0), Offset(leftLineX, size.height), linePaint);
    canvas.drawLine(Offset(rightLineX, 0), Offset(rightLineX, size.height), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

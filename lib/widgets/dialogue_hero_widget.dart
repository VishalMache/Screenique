import 'package:flutter/material.dart';
import '../data/dialogues_data.dart';

class DialogueHeroWidget extends StatelessWidget {
  final MovieDialogue dialogue;
  final VoidCallback onForgeTap;

  const DialogueHeroWidget({
    super.key,
    required this.dialogue,
    required this.onForgeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4EC),
          border: Border.all(color: const Color(0xFF111111), width: 2.5),
        ),
        child: Stack(
          children: [
            // --- BACKGROUND: Movie poster bleeding to right with native alpha bleed ---
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.55,
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, Colors.black], // Fade alpha channel directly
                      stops: [0.0, 0.55], // Smooth fade on the left half
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.grey,
                      BlendMode.saturation,
                    ),
                    child: Image.network(
                      dialogue.posterUrl
                          .replaceAll('image.tmdb.org', 'images.tmdb.org')
                          .replaceAll('/original/', '/w500/'), // w500 loads instantly, /original/ blocks rendering!
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (c, e, s) {
                        debugPrint("POSTER LOAD ERROR: $e");
                        return Container(color: Colors.transparent); // Transparent on error for seamless fallback
                      },
                    ),
                  ),
                ),
              ),
            ),

            // --- RED ACCENT BAR at top-right ---
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: Container(
                width: 24,
                color: const Color(0xFFD32F2F),
              ),
            ),

            // --- VERTICAL MOVIE TITLE on right edge ---
            Positioned(
              right: 2,
              top: 0,
              bottom: 0,
              child: Center(
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    dialogue.movieTitle,
                    style: const TextStyle(
                      color: Color(0xFFF4F4EC),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      fontFamily: 'Impact',
                    ),
                  ),
                ),
              ),
            ),

            // --- MAIN CONTENT: Quote + Character ---
            Positioned(
              top: 16,
              left: 16,
              right: MediaQuery.of(context).size.width * 0.44, // Keep quote safely on cream side!
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Red quote mark + movie label line
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "\u201C",
                        style: TextStyle(
                          color: Color(0xFFD32F2F),
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          height: 0.8,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(width: 16, height: 1.2, color: const Color(0xFFD32F2F)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    dialogue.movieTitle,
                                    style: const TextStyle(
                                      color: Color(0xFFD32F2F),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
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

                  // --- THE QUOTE ---
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Builder(
                        builder: (context) {
                          final String quoteText = dialogue.quote.toUpperCase();
                          double fontSize = 18.0;
                          if (quoteText.length > 120) {
                            fontSize = 11.0;
                          } else if (quoteText.length > 80) {
                            fontSize = 13.0;
                          } else if (quoteText.length > 50) {
                            fontSize = 15.0;
                          } else if (quoteText.length > 30) {
                            fontSize = 16.5;
                          }

                          return Text(
                            quoteText,
                            style: TextStyle(
                              color: const Color(0xFF111111),
                              fontSize: fontSize,
                              fontWeight: FontWeight.w900,
                              height: 0.95,
                              fontFamily: 'Impact',
                              letterSpacing: -0.3,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // --- CHARACTER NAME ---
                  Text(
                    dialogue.character.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
            ),

            // --- FORGE / EDIT BUTTON ---
            Positioned(
              top: 12,
              right: 36,
              child: GestureDetector(
                onTap: onForgeTap,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    border: Border.all(color: const Color(0xFF111111), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFD32F2F),
                        offset: Offset(2, 2),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFFF4F4EC),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

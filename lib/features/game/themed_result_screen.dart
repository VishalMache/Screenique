import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ThemedResultScreen extends StatelessWidget {
  final GameSession session;

  const ThemedResultScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final int totalScore = session.totalScore;
    final int maxScore = session.rounds.length *
        (100 * DifficultyConfig.fromEnum(session.difficulty).scoreMultiplier)
            .round();

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'CHALLENGE COMPLETE',
          style: TextStyle(
            color: Color(0xFFF4F4EC),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              '${session.themeEmoji} ${session.themeName.toUpperCase()}',
              style: const TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$totalScore / $maxScore',
              style: const TextStyle(
                color: Color(0xFFF4F4EC),
                fontSize: 48,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              'TOTAL SCORE',
              style: TextStyle(
                color: Color(0xFF888882),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MOVIES PLAYED',
                  style: TextStyle(
                    color: Color(0xFF575757),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: session.rounds.length,
                itemBuilder: (context, index) {
                  final round = session.rounds[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: round.isSolved
                            ? const Color(0xFF4CAF50).withOpacity(0.3)
                            : const Color(0xFF2A2A2A),
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: round.posterUrl,
                            width: 40,
                            height: 60,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 40,
                              height: 60,
                              color: const Color(0xFF222222),
                              child: const Icon(Icons.movie,
                                  color: Color(0xFF444444)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                round.movieTitle,
                                style: const TextStyle(
                                  color: Color(0xFFF4F4EC),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                round.isSolved
                                    ? 'Solved at clue #${round.solvedAtClue}'
                                    : 'Unsolved',
                                style: TextStyle(
                                  color: round.isSolved
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFF888882),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (round.isSolved)
                          const Icon(Icons.check_circle,
                              color: Color(0xFF4CAF50), size: 20)
                        else
                          const Icon(Icons.cancel,
                              color: Color(0xFF575757), size: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: Material(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'BACK TO HUB',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFF4F4EC),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
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

import 'dart:math';
import 'package:flutter/material.dart';

class FilmGrainOverlay extends StatefulWidget {
  final Widget child;
  const FilmGrainOverlay({super.key, required this.child});

  @override
  State<FilmGrainOverlay> createState() => _FilmGrainOverlayState();
}

class _FilmGrainOverlayState extends State<FilmGrainOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Rapid animation to simulate the "shimmer" of film grain
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer( // So the grain doesn't block taps
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: 0.04, // Very subtle, increase to 0.08 for "grainier" look
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: const NetworkImage(
                        'https://www.transparenttextures.com/patterns/stardust.png'
                      ),
                      repeat: ImageRepeat.repeat,
                      // Randomize the alignment slightly to create jitter
                      alignment: Alignment(
                        Random().nextDouble() * 2 - 1,
                        Random().nextDouble() * 2 - 1,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
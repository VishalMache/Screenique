import 'dart:math';
import 'package:flutter/material.dart';

Route noirShutterTransition(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 800),
    reverseTransitionDuration: const Duration(milliseconds: 800),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final shutterAnimation = TweenSequence([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInQuart)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOutQuart)),
          weight: 50,
        ),
      ]).animate(animation);

      return Stack(
        children: [
          FadeTransition(opacity: animation, child: child),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: shutterAnimation,
              builder: (context, _) => CustomPaint(
                painter: ShutterPainter(shutterAnimation.value),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class ShutterPainter extends CustomPainter {
  final double progress;
  ShutterPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    double w = size.width, h = size.height;
    
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(w, 0)..lineTo(w / 2, h / 2 * progress)..close(), paint);
    canvas.drawPath(Path()..moveTo(0, h)..lineTo(w, h)..lineTo(w / 2, h - (h / 2 * progress))..close(), paint);
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(0, h)..lineTo(w / 2 * progress, h / 2)..close(), paint);
    canvas.drawPath(Path()..moveTo(w, 0)..lineTo(w, h)..lineTo(w - (w / 2 * progress), h / 2)..close(), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
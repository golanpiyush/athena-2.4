import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TypingIndicator extends StatefulWidget {
  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _animControllers;
  late List<Animation<double>> _animations;

  final int _numDots = 3;
  final double _dotSize = 8.0;
  final double _jumpHeight = 6.0;

  @override
  void initState() {
    super.initState();

    _animControllers = List.generate(
      _numDots,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400),
      ),
    );

    _animations = _animControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));
    }).toList();

    // Start animations with delays
    _startAnimation();
  }

  Future<void> _startAnimation() async {
    for (var i = 0; i < _numDots; i++) {
      await Future.delayed(Duration(milliseconds: i * 150));
      if (mounted) {
        _animControllers[i].repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _animControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Thinking...',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(width: 12),
        ...List.generate(_numDots, (index) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedBuilder(
              animation: _animations[index],
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -_jumpHeight * _animations[index].value),
                  child: Container(
                    width: _dotSize,
                    height: _dotSize,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

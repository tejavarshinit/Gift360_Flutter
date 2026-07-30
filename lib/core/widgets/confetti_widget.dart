import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiWidget extends StatefulWidget {
  final bool isActive;
  final Duration duration;

  const ConfettiWidget({super.key, required this.isActive, this.duration = const Duration(milliseconds: 3500)});

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget> {
  List<_ConfettiPiece> _pieces = [];
  final _random = Random();

  static const _colors = [Color(0xFFDC2626), Color(0xFFEAB308), Colors.white, Color(0xFF1A1A1A), Color(0xFF71717A)];

  @override
  void didUpdateWidget(ConfettiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      setState(() {
        _pieces = List.generate(80, (i) {
          return _ConfettiPiece(
            left: _random.nextDouble() * 100,
            color: _colors[_random.nextInt(_colors.length)],
            delay: _random.nextDouble() * 0.5,
            size: 8 + _random.nextDouble() * 8,
            isRound: _random.nextBool(),
          );
        });
      });
      Future.delayed(widget.duration, () {
        if (mounted) setState(() => _pieces = []);
      });
    } else if (!widget.isActive) {
      setState(() => _pieces = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive || _pieces.isEmpty) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: _pieces.map((piece) {
            return _FallingPiece(piece: piece);
          }).toList(),
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  final double left;
  final Color color;
  final double delay;
  final double size;
  final bool isRound;

  const _ConfettiPiece({required this.left, required this.color, required this.delay, required this.size, required this.isRound});
}

class _FallingPiece extends StatefulWidget {
  final _ConfettiPiece piece;
  const _FallingPiece({required this.piece});

  @override
  State<_FallingPiece> createState() => _FallingPieceState();
}

class _FallingPieceState extends State<_FallingPiece> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fallAnim;
  late Animation<double> _spinAnim;
  late Animation<double> _driftAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));

    _fallAnim = Tween<double>(begin: -20, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _spinAnim = Tween<double>(begin: 0, end: _randomSpin()).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    _driftAnim = Tween<double>(begin: 0, end: _randomDrift()).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: (widget.piece.delay * 1000).round()), () {
      if (mounted) _controller.forward();
    });
  }

  double _randomSpin() => (Random().nextDouble() * 6 - 3) * pi;
  double _randomDrift() => Random().nextDouble() * 60 - 30;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: MediaQuery.of(context).size.width * widget.piece.left / 100 + _driftAnim.value,
          top: _fallAnim.value * MediaQuery.of(context).size.height,
          child: Transform.rotate(
            angle: _spinAnim.value,
            child: Container(
              width: widget.piece.size,
              height: widget.piece.size,
              decoration: BoxDecoration(
                color: widget.piece.color,
                shape: widget.piece.isRound ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: widget.piece.isRound ? null : BorderRadius.circular(1),
              ),
            ),
          ),
        );
      },
    );
  }
}

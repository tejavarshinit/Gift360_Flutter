import 'dart:math';
import 'package:flutter/material.dart';

class FloatingCoins extends StatefulWidget {
  final int count;

  const FloatingCoins({super.key, this.count = 14});

  @override
  State<FloatingCoins> createState() => _FloatingCoinsState();
}

class _FloatingCoinsState extends State<FloatingCoins> with TickerProviderStateMixin {
  late List<_CoinData> _coins;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _coins = List.generate(widget.count, (i) {
      final left = (i / widget.count) * 100 + (_random.nextDouble() * 8 - 4);
      final delay = _random.nextDouble() * 8;
      final size = 8.0 + _random.nextDouble() * 10;
      final isCoin = i % 3 != 0;
      return _CoinData(left: left, delay: delay, size: size, isCoin: isCoin, key: i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: Stack(
            children: _coins.map((coin) {
              return _FloatingCoin(coin: coin);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _CoinData {
  final double left;
  final double delay;
  final double size;
  final bool isCoin;
  final int key;

  const _CoinData({required this.left, required this.delay, required this.size, required this.isCoin, required this.key});
}

class _FloatingCoin extends StatefulWidget {
  final _CoinData coin;
  const _FloatingCoin({required this.coin});

  @override
  State<_FloatingCoin> createState() => _FloatingCoinState();
}

class _FloatingCoinState extends State<_FloatingCoin> with TickerProviderStateMixin {
  late AnimationController _riseController;
  late AnimationController _spinController;
  late Animation<double> _riseAnim;
  late Animation<double> _driftAnim;
  late Animation<double> _spinAnim;

  @override
  void initState() {
    super.initState();
    final random = Random();

    _riseController = AnimationController(vsync: this, duration: Duration(seconds: 6 + random.nextInt(4)));
    _spinController = AnimationController(vsync: this, duration: Duration(seconds: 3 + random.nextInt(3)));

    _riseAnim = Tween<double>(begin: 1.0, end: -0.2).animate(CurvedAnimation(parent: _riseController, curve: Curves.easeOut));
    _driftAnim = Tween<double>(begin: 0, end: (random.nextDouble() * 80 - 40)).animate(CurvedAnimation(parent: _riseController, curve: Curves.easeInOut));
    _spinAnim = Tween<double>(begin: 0, end: 2 * pi * (random.nextBool() ? 1 : -1)).animate(CurvedAnimation(parent: _spinController, curve: Curves.linear));

    Future.delayed(Duration(milliseconds: (widget.coin.delay * 1000).round()), () {
      if (mounted) {
        _riseController.repeat();
        _spinController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _riseController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: Listenable.merge([_riseController, _spinController]),
      builder: (context, child) {
        return Positioned(
          left: MediaQuery.of(context).size.width * widget.coin.left / 100 + _driftAnim.value,
          bottom: 0,
          top: screenHeight * (1 - _riseAnim.value),
          child: widget.coin.isCoin
              ? Transform.rotate(
                  angle: _spinAnim.value,
                  child: Container(
                    width: widget.coin.size,
                    height: widget.coin.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFEC8B), Color(0xFFDAA520), Color(0xFF8B6914)],
                        stops: [0.35, 0.6, 1.0],
                      ),
                      boxShadow: [BoxShadow(color: const Color(0x8CDAA520), blurRadius: 14)],
                    ),
                  ),
                )
              : Transform.rotate(
                  angle: pi / 4,
                  child: Container(
                    width: widget.coin.size * 0.9,
                    height: widget.coin.size * 0.9,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.white, Color(0xFFDAA520)]),
                      boxShadow: [BoxShadow(color: const Color(0xB3DAA520), blurRadius: 8)],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

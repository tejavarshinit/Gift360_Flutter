import 'dart:math';
import 'package:flutter/material.dart';

class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _spinsToday = 0;
  int _totalWinnings = 0;
  bool _canSpin = true;
  String? _result;
  int? _prizeValue;
  bool _showResult = false;
  final Random _random = Random();

  static const _segments = [
    {'label': '₹1', 'value': 1, 'color': Color(0xFFFF0080)},
    {'label': '₹2', 'value': 2, 'color': Color(0xFF9333EA)},
    {'label': '₹3', 'value': 3, 'color': Color(0xFF06B6D4)},
    {'label': '₹5', 'value': 5, 'color': Color(0xFF10B981)},
    {'label': '₹10', 'value': 10, 'color': Color(0xFFF59E0B)},
    {'label': '₹0', 'value': 0, 'color': Color(0xFFA855F7)},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.decelerate);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSpinComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() {
    if (!_canSpin || _controller.isAnimating) return;
    setState(() {
      _showResult = false;
      _result = null;
      _prizeValue = null;
    });

    // Random final angle
    final targetIndex = _random.nextInt(_segments.length);
    final segmentAngle = 2 * pi / _segments.length;
    final targetAngle = targetIndex * segmentAngle + segmentAngle / 2;
    final totalRotation = 2 * pi * 5 + (2 * pi - targetAngle);

    _animation = Tween<double>(begin: 0, end: totalRotation).animate(
      CurvedAnimation(parent: _controller, curve: Curves.decelerate),
    );
    _controller.forward(from: 0);
  }

  void _onSpinComplete() {
    final currentAngle = _animation.value % (2 * pi);
    final segmentAngle = 2 * pi / _segments.length;
    final normalizedAngle = (2 * pi - currentAngle) % (2 * pi);
    final hitIndex = (normalizedAngle / segmentAngle).floor() % _segments.length;
    final segment = _segments[hitIndex];

    setState(() {
      _spinsToday++;
      _canSpin = _spinsToday < 1;
      _result = segment['label'] as String;
      _prizeValue = segment['value'] as int;
      _totalWinnings += _prizeValue!;
      _showResult = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A2E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Spin & Win', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
              const SizedBox(height: 4),
              const Text('Try your luck and win exciting vouchers', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),

              // Stats
              Row(
                children: [
                  Expanded(child: _buildStatCard("Today's Spins", '$_spinsToday/1')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('Total Won', '₹$_totalWinnings')),
                ],
              ),
              const SizedBox(height: 12),

              // Daily spin info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎁 ', style: TextStyle(fontSize: 14)),
                    const Text('1 Free Spin Daily', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                    if (!_canSpin) ...[
                      const SizedBox(width: 8),
                      Text('Come back tomorrow', style: TextStyle(color: Colors.amber.shade300, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Wheel
              SizedBox(
                height: 280,
                width: 280,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: WheelPainter(
                        segments: _segments,
                        rotation: _animation.value,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: CircleAvatar(
                            backgroundColor: Colors.amber,
                            child: Icon(Icons.play_arrow, color: Colors.black, size: 30),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Pointer
              const SizedBox(height: 8),
              CustomPaint(
                size: const Size(20, 20),
                painter: _PointerPainter(),
              ),
              const SizedBox(height: 24),

              // Result
              if (_showResult && _result != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _prizeValue! > 0 ? 'You won $_result!' : 'Better luck next time!',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      if (_prizeValue! > 0)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() => _showResult = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$_result voucher added to your account!')),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                            child: const Text('Claim Voucher'),
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Spin button
              if (!_showResult)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canSpin ? _spin : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canSpin ? Colors.amber : Colors.grey,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_canSpin ? 'SPIN NOW' : 'No spins left today', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),

              const SizedBox(height: 20),

              // How it works
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    const Text('How It Works', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildHowItWorks('🛍️', 'Shop', 'Browse vouchers'),
                        _buildHowItWorks('🎯', 'Spin', 'Once daily'),
                        _buildHowItWorks('🎁', 'Win', '₹1 to ₹10'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Info bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _InfoItem('1', 'Free Spin Daily', Colors.amber),
                    _InfoItem('₹10', 'Max Prize', Colors.pinkAccent),
                    _InfoItem('10', 'Points to Spin', Colors.purpleAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber, fontFamily: 'serif')),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(String emoji, String title, String subtitle) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ],
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> segments;
  final double rotation;

  WheelPainter({required this.segments, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / segments.length;

    for (int i = 0; i < segments.length; i++) {
      final startAngle = rotation + i * segmentAngle;
      final paint = Paint()..color = segments[i]['color'] as Color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      // Draw text
      final textPainter = TextPainter(
        text: TextSpan(
          text: segments[i]['label'] as String,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final textAngle = startAngle + segmentAngle / 2;
      final textRadius = radius * 0.65;
      final textX = center.dx + cos(textAngle) * textRadius - textPainter.width / 2;
      final textY = center.dy + sin(textAngle) * textRadius - textPainter.height / 2;

      canvas.save();
      canvas.translate(textX + textPainter.width / 2, textY + textPainter.height / 2);
      canvas.rotate(textAngle + pi / 2);
      canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // Center circle
    final centerPaint = Paint()..color = const Color(0xFF1A0A2E);
    canvas.drawCircle(center, radius * 0.18, centerPaint);
  }

  @override
  bool shouldRepaint(covariant WheelPainter oldDelegate) => oldDelegate.rotation != rotation;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.amber..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _InfoItem(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }
}

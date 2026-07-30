import 'dart:ui';

import 'package:flutter/material.dart';

/// Port of `components/AddToCartSuccessModal.tsx` — a 4-stage choreographed
/// animation: cart icon races in from the left with a bounce, a voucher
/// icon drops onto it with an impact "squash", a success message fades in,
/// then the cart exits to the right. Purely presentational; the caller
/// (e.g. PaymentDetailsSheet) still owns the actual add-to-cart logic and
/// timing of when to close/navigate away.
class AddToCartSuccessModal extends StatefulWidget {
  final bool open;
  final VoidCallback? onClose;

  const AddToCartSuccessModal({super.key, required this.open, this.onClose});

  @override
  State<AddToCartSuccessModal> createState() => _AddToCartSuccessModalState();
}

class _AddToCartSuccessModalState extends State<AddToCartSuccessModal>
    with SingleTickerProviderStateMixin {
  static const int _totalMs = 2200;
  static const double _stage2At = 400 / _totalMs; // cart race-in begins
  static const double _stage3At = 1000 / _totalMs; // impact + voucher drop + message
  static const double _stage4At = 1800 / _totalMs; // cart exit + underline grow

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: _totalMs));
    if (widget.open) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant AddToCartSuccessModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      _controller.forward(from: 0);
    } else if (!widget.open && oldWidget.open) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static double _progress(double start, double end, double t) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        // ── Cart: race-in (stage2), hold (stage3), exit (stage4) ──
        double cartX = 0;
        double cartOpacity = 1;
        double impactScaleX = 1;
        double impactScaleY = 1;

        if (t < _stage2At) {
          cartOpacity = 0.3;
        } else if (t < _stage3At) {
          final raceEnd = _stage2At + 600 / _totalMs;
          final p = _progress(_stage2At, raceEnd, t).clamp(0.0, 1.0);
          final curved = Curves.easeOutBack.transform(p);
          cartX = -120 * (1 - curved);
          cartOpacity = p < 0.05 ? (p / 0.05) : 1;
        } else if (t < _stage4At) {
          final impactEnd = _stage3At + 320 / _totalMs;
          if (t < impactEnd) {
            final p = _progress(_stage3At, impactEnd, t);
            if (p < 0.4) {
              final pp = Curves.easeOut.transform(p / 0.4);
              impactScaleX = 1 + 0.1 * pp;
              impactScaleY = 1 - 0.05 * pp;
            } else {
              final pp = Curves.easeIn.transform((p - 0.4) / 0.6);
              impactScaleX = 1.1 - 0.1 * pp;
              impactScaleY = 0.95 + 0.05 * pp;
            }
          }
        } else {
          final p = _progress(_stage4At, _stage4At + 380 / _totalMs, t).clamp(0.0, 1.0);
          final curved = Curves.easeIn.transform(p);
          cartX = 110 * curved;
          cartOpacity = 1 - curved;
        }

        // ── Streaks: fade in then out during the race-in window ──
        double streakOpacity = 0;
        if (t >= _stage2At && t < _stage3At) {
          final streakEnd = _stage2At + 560 / _totalMs;
          final p = _progress(_stage2At, streakEnd, t).clamp(0.0, 1.0);
          streakOpacity = p < 0.2 ? (p / 0.2) : (1 - (p - 0.2) / 0.8);
        }

        // ── Voucher: drops in with a slight overshoot from stage3 ──
        double voucherY = -56;
        double voucherScale = 0.96;
        double voucherOpacity = 0;
        if (t >= _stage3At) {
          final dropEnd = _stage3At + 540 / _totalMs;
          final p = _progress(_stage3At, dropEnd, t).clamp(0.0, 1.0);
          voucherOpacity = 1;
          if (p < 0.75) {
            final pp = Curves.easeOut.transform(p / 0.75);
            voucherY = -56 + 94 * pp;
            voucherScale = 0.96 + 0.04 * pp;
          } else {
            final pp = (p - 0.75) / 0.25;
            voucherY = 38 - 4 * pp;
            voucherScale = 1;
          }
        }

        // ── Message + underline ──
        double messageOpacity = 0;
        double messageY = 8;
        if (t >= _stage3At) {
          final p = _progress(_stage3At, _stage3At + 340 / _totalMs, t).clamp(0.0, 1.0);
          final curved = Curves.easeOut.transform(p);
          messageOpacity = curved;
          messageY = 8 * (1 - curved);
        }

        double underlineWidth = 0;
        double underlineOpacity = 0;
        if (t >= _stage4At) {
          final p = _progress(_stage4At, _stage4At + 420 / _totalMs, t).clamp(0.0, 1.0);
          final curved = Curves.easeOut.transform(p);
          underlineWidth = 132 * curved;
          underlineOpacity = curved;
        }

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                    child: Container(color: Colors.black.withValues(alpha: 0.35)),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 300,
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 32),
                  height: 280,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x1F6C5CE7)),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF111827).withValues(alpha: 0.22), blurRadius: 60, offset: const Offset(0, 24)),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 120,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Streaks
                            Positioned(
                              left: 12,
                              top: 56,
                              child: Opacity(
                                opacity: streakOpacity,
                                child: const _StreakLines(),
                              ),
                            ),
                            // Cart
                            Positioned(
                              left: 70 - 39,
                              top: 42,
                              child: Transform.translate(
                                offset: Offset(cartX, 0),
                                child: Opacity(
                                  opacity: cartOpacity,
                                  child: Transform.scale(
                                    scaleX: impactScaleX,
                                    scaleY: impactScaleY,
                                    child: const SizedBox(
                                      width: 78,
                                      height: 78,
                                      child: CustomPaint(painter: _CartIconPainter()),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Voucher
                            Positioned(
                              left: 70 - 45,
                              top: 4,
                              child: Opacity(
                                opacity: voucherOpacity,
                                child: Transform.translate(
                                  offset: Offset(0, voucherY),
                                  child: Transform.scale(
                                    scale: voucherScale,
                                    child: const SizedBox(
                                      width: 90,
                                      height: 60,
                                      child: CustomPaint(painter: _VoucherIconPainter()),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Opacity(
                        opacity: messageOpacity,
                        child: Transform.translate(
                          offset: Offset(0, messageY),
                          child: Column(
                            children: [
                              const Text(
                                'Voucher added to cart successfully!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E), height: 1.35),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: underlineWidth,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD0C9FF).withValues(alpha: underlineOpacity),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StreakLines extends StatelessWidget {
  const _StreakLines();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double marginLeft, double marginBottom) => Padding(
          padding: EdgeInsets.only(left: marginLeft, bottom: marginBottom),
          child: Container(
            width: width,
            height: 6,
            decoration: BoxDecoration(color: const Color(0xFFD0C9FF), borderRadius: BorderRadius.circular(999)),
          ),
        );
    return SizedBox(
      width: 70,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(62, 0, 10),
          bar(48, 12, 10),
          bar(34, 24, 0),
        ],
      ),
    );
  }
}

/// Port of the `CartIcon` inline SVG (viewBox 0 0 64 64).
class _CartIconPainter extends CustomPainter {
  const _CartIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 64;
    final sy = size.height / 64;
    Offset s(double x, double y) => Offset(x * sx, y * sy);

    final stroke = Paint()
      ..color = const Color(0xFF6C5CE7)
      ..strokeWidth = 4.5 * ((sx + sy) / 2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(s(10, 15).dx, s(10, 15).dy)
      ..lineTo(s(17, 15).dx, s(17, 15).dy)
      ..lineTo(s(21.5, 36.5).dx, s(21.5, 36.5).dy)
      ..quadraticBezierTo(s(22.5, 39.5).dx, s(22.5, 39.5).dy, s(24.44, 38.89).dx, s(24.44, 38.89).dy)
      ..lineTo(s(47.22, 38.89).dx, s(47.22, 38.89).dy)
      ..quadraticBezierTo(s(50, 38).dx, s(50, 38).dy, s(50.14, 36.6).dx, s(50.14, 36.6).dy)
      ..lineTo(s(55, 22).dx, s(55, 22).dy)
      ..lineTo(s(21, 22).dx, s(21, 22).dy);
    canvas.drawPath(path, stroke);

    final wheelPaint = Paint()..color = const Color(0xFF6C5CE7);
    canvas.drawCircle(s(28, 49), 4.5 * ((sx + sy) / 2), wheelPaint);
    canvas.drawCircle(s(47, 49), 4.5 * ((sx + sy) / 2), wheelPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Port of the `VoucherIcon` inline SVG (viewBox 0 0 90 60).
class _VoucherIconPainter extends CustomPainter {
  const _VoucherIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 90;
    final sy = size.height / 60;
    Rect r(double x, double y, double w, double h) => Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy);

    canvas.drawRRect(
      RRect.fromRectAndRadius(r(4, 8, 82, 44), Radius.circular(12 * sx)),
      Paint()..color = const Color(0xFF6C5CE7),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r(14, 18, 24, 24), Radius.circular(6 * sx)),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    // Sparkle
    final sparkle = Path()
      ..moveTo(27 * sx, 22 * sy)
      ..lineTo(29.5 * sx, 27 * sy)
      ..lineTo(35 * sx, 27.8 * sy)
      ..lineTo(31 * sx, 31.8 * sy)
      ..lineTo(31.95 * sx, 37.5 * sy)
      ..lineTo(27 * sx, 34.85 * sy)
      ..lineTo(22.05 * sx, 37.5 * sy)
      ..lineTo(23 * sx, 31.8 * sy)
      ..lineTo(19 * sx, 27.8 * sy)
      ..lineTo(24.5 * sx, 27 * sy)
      ..close();
    canvas.drawPath(sparkle, Paint()..color = Colors.white);

    canvas.drawRRect(
      RRect.fromRectAndRadius(r(46, 20, 28, 4), Radius.circular(2 * sx)),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r(46, 29, 18, 4), Radius.circular(2 * sx)),
      Paint()..color = Colors.white.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InstantGiftingBanner extends StatelessWidget {
  final VoidCallback? onExplore;

  const InstantGiftingBanner({super.key, this.onExplore});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment(-1.0, 0),
              end: Alignment(1.0, 0),
              colors: [Color(0xFF78DEFF), Color(0xFFABC2F5), Color(0xFF2F4AB3)],
              stops: [0.0, 0.5355, 1.1138],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                offset: Offset(2, 4),
                blurRadius: 4,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Diagonal decorative line (top-left)
              Positioned(
                left: -38,
                top: -56,
                child: Transform.rotate(
                  angle: 29 * 3.14159265 / 180,
                  child: Container(
                    width: 10,
                    height: 131,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Title text
              Positioned(
                left: 16,
                top: 16,
                child: SizedBox(
                  width: 138,
                  child: Text(
                    'Instant Gifting\nin 3 Steps',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      height: 1.27,
                    ),
                  ),
                ),
              ),

              // Explore Now button
              Positioned(
                left: 16,
                top: 78,
                child: GestureDetector(
                  onTap: onExplore,
                  child: Container(
                    width: 100,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(
                        begin: Alignment(-0.95, 0),
                        end: Alignment(0.92, 0),
                        colors: [Color(0xFF01E3EC), Color(0xFF2E7DEA)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x402A85EA),
                          offset: Offset(0, 1),
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      'Explore Now',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              // Steps with curved arrows (right side)
              Positioned(
                left: 160,
                top: 13,
                width: 176,
                height: 100,
                child: _buildStepsWithArrows(),
              ),

              // Radial gradient overlay (right side)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 104,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.44, -0.52),
                      radius: 0.68,
                      colors: [
                        Colors.white.withValues(alpha: 0.3),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.28],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 104,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.76, 0.52),
                      radius: 0.85,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.34],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepsWithArrows() {
    return Stack(
      children: [
        // Curved arrows painted via CustomPainter
        Positioned.fill(
          child: CustomPaint(painter: _CurvedArrowsPainter()),
        ),

        // Step 1: Browse Brands
        Positioned(
          left: 8,
          top: 43,
          child: _buildStepItem(
            bgColor: const Color(0xFF8CCBF8),
            borderColor: null,
            icon: Icons.store_outlined,
            iconColor: Colors.white,
            iconSize: 22,
            borderRadius: 8,
            label: '1.Browse\nBrands',
          ),
        ),

        // Step 2: Set Value
        Positioned(
          left: 66,
          top: 4,
          child: _buildStepItem(
            bgColor: const Color(0xFFF1F5FF),
            borderColor: null,
            icon: Icons.gps_fixed,
            iconColor: const Color(0xFFD94231),
            iconSize: 24,
            borderRadius: 21,
            label: '2.Set\nvalue',
          ),
        ),

        // Step 3: Get Voucher
        const Positioned(
          right: 0,
          top: 40,
          child: _Step3Widget(),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required Color bgColor,
    Color? borderColor,
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required double borderRadius,
    required String label,
  }) {
    return SizedBox(
      width: 74,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: borderRadius > 20 ? 42 : 40,
            height: borderRadius > 20 ? 42 : 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: borderColor != null ? Border.all(color: borderColor) : null,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x28183A90),
                  offset: const Offset(0, 3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 3 widget extracted to avoid const context issues with LucideIcons
class _Step3Widget extends StatelessWidget {
  const _Step3Widget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0C9),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x28183A90),
                  offset: Offset(0, 3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.card_giftcard,
              size: 22,
              color: Color(0xFFD6422E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '3.Get\nVoucher',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter that draws 3 curved arrow paths matching the React SVG exactly.
/// ViewBox: 176 x 100
class _CurvedArrowsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD86B23)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = const Color(0xFFD86B23)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Scale factors to map 176x100 viewBox to actual size
    final sx = size.width / 176;
    final sy = size.height / 100;

    Offset s(double x, double y) => Offset(x * sx, y * sy);

    // --- Arrow 1 ---
    final path1 = Path()
      ..moveTo(s(24, 60).dx, s(24, 60).dy)
      ..cubicTo(
        s(41, 34).dx, s(41, 34).dy,
        s(52, 28).dx, s(52, 28).dy,
        s(71, 25).dx, s(71, 25).dy,
      );
    canvas.drawPath(path1, paint);

    final arrow1 = Path()
      ..moveTo(s(69, 24).dx, s(69, 24).dy)
      ..lineTo(s(59, 22).dx, s(59, 22).dy)
      ..moveTo(s(69, 24).dx, s(69, 24).dy)
      ..lineTo(s(61, 31).dx, s(61, 31).dy);
    canvas.drawPath(arrow1, arrowPaint);

    // --- Arrow 2 ---
    final path2 = Path()
      ..moveTo(s(68, 55).dx, s(68, 55).dy)
      ..cubicTo(
        s(82, 35).dx, s(82, 35).dy,
        s(96, 29).dx, s(96, 29).dy,
        s(114, 26).dx, s(114, 26).dy,
      );
    canvas.drawPath(path2, paint);

    final arrow2 = Path()
      ..moveTo(s(110, 25).dx, s(110, 25).dy)
      ..lineTo(s(100, 23).dx, s(100, 23).dy)
      ..moveTo(s(110, 25).dx, s(110, 25).dy)
      ..lineTo(s(102, 32).dx, s(102, 32).dy);
    canvas.drawPath(arrow2, arrowPaint);

    // --- Arrow 3 ---
    final path3 = Path()
      ..moveTo(s(126, 71).dx, s(126, 71).dy)
      ..cubicTo(
        s(141, 70).dx, s(141, 70).dy,
        s(151, 76).dx, s(151, 76).dy,
        s(161, 87).dx, s(161, 87).dy,
      );
    canvas.drawPath(path3, paint);

    final arrow3 = Path()
      ..moveTo(s(156, 84).dx, s(156, 84).dy)
      ..lineTo(s(166, 84).dx, s(166, 84).dy)
      ..moveTo(s(156, 84).dx, s(156, 84).dy)
      ..lineTo(s(162, 93).dx, s(162, 93).dy);
    canvas.drawPath(arrow3, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

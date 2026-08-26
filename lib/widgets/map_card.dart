import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MapCard extends StatelessWidget {
  final double? lat;
  final double? lng;
  const MapCard({super.key, this.lat, this.lng});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nearby Stores Map', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF2F5FF), Color(0xFFE8ECFF), Color(0xFFDFE8FF)]),
              boxShadow: const [BoxShadow(color: Color(0x1A2A3466), blurRadius: 28, offset: Offset(0, 12))],
            ),
            child: Stack(
              children: [
                CustomPaint(size: const Size(double.infinity, 140), painter: _MapGridPainter()),
                Container(decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(-0.4, -0.3), radius: 0.22, colors: [AppColors.mapGradientPurple, Colors.transparent]))),
                Container(decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0.44, 0.16), radius: 0.22, colors: [AppColors.mapGradientBlue, Colors.transparent]))),
                ...[const Alignment(-0.28, -0.2), const Alignment(0.04, 0.3), const Alignment(0.5, -0.1)].map((align) {
                  return Align(
                    alignment: align,
                    child: Transform.translate(
                      offset: const Offset(0, -14),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x526A53FF), blurRadius: 16, offset: Offset(0, 6))]),
                        child: const Icon(Icons.location_pin, color: Colors.white, size: 14),
                      ),
                    ),
                  );
                }),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(999)),
                    child: Text('Live location', style: AppTextStyles.mapLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.mapGridLine.withOpacity(0.65)..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.3), paint);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.7), paint);
    canvas.drawLine(Offset(size.width * 0.2, 0), Offset(size.width * 0.2, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.8, 0), Offset(size.width * 0.8, size.height), paint);
    final centerPaint = Paint()..color = AppColors.mapGridLineCenter..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

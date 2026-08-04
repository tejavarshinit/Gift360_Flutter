import 'package:flutter/material.dart';

class BrandMarqueeSection extends StatefulWidget {
  const BrandMarqueeSection({super.key});

  @override
  State<BrandMarqueeSection> createState() => _BrandMarqueeSectionState();
}

class _BrandMarqueeSectionState extends State<BrandMarqueeSection>
    with TickerProviderStateMixin {
  static const _brands = [
    'ajio',
    'amazon',
    'bata',
    'fastrack',
    'flipkart',
    'levis',
    'myntra',
    'nike',
    'puma',
    'raymond',
    'tatacliq',
    'tego',
    'woodland',
    'zomato',
  ];

  static const _cardWidth = 342.0;
  static const _cardHeight = 150.0;
  static const _cardGap = 14.0;
  static const _rowStride = _cardWidth + _cardGap;

  AnimationController? _row1Controller;
  AnimationController? _row2Controller;
  AnimationController? _row3Controller;

  late final List<List<String>> _rows;

  @override
  void initState() {
    super.initState();
    _rows = [
      _brands.sublist(0, 5),
      _brands.sublist(5, 10),
      _brands.sublist(10, 14),
    ];
  }

  @override
  void dispose() {
    _row1Controller?.dispose();
    _row2Controller?.dispose();
    _row3Controller?.dispose();
    super.dispose();
  }

  void _initAnimations() {
    if (_row1Controller != null) return;
    _row1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 200),
    )..repeat();
    _row2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 220),
    )..repeat();
    _row3Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 180),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    _initAnimations();
    return SizedBox(
      height: (_cardHeight * 3) + (_cardGap * 2),
      child: Column(
        children: [
          _buildMarqueeRow(
            controller: _row1Controller!,
            brands: _rows[0],
            isLTR: true,
          ),
          const SizedBox(height: _cardGap),
          _buildMarqueeRow(
            controller: _row2Controller!,
            brands: _rows[1],
            isLTR: false,
          ),
          const SizedBox(height: _cardGap),
          _buildMarqueeRow(
            controller: _row3Controller!,
            brands: _rows[2],
            isLTR: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMarqueeRow({
    required AnimationController controller,
    required List<String> brands,
    required bool isLTR,
  }) {
    final duplicated = [...brands, ...brands];
    final halfWidth = brands.length * _rowStride;

    return Listener(
      onPointerDown: (_) => controller.stop(),
      onPointerUp: (_) => controller.repeat(),
      onPointerCancel: (_) => controller.repeat(),
      child: SizedBox(
        height: _cardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final offset = isLTR
                    ? controller.drive(Tween(begin: -halfWidth, end: 0.0))
                    : controller.drive(Tween(begin: 0.0, end: -halfWidth));
                return Transform.translate(
                  offset: Offset(offset.value, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: duplicated
                    .map((brand) => Padding(
                          padding: const EdgeInsets.only(right: _cardGap),
                          child: _buildCard(brand),
                        ))
                    .toList(),
              ),
            ),
            // Left fade
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF3F5F9).withValues(alpha: 0.95),
                        const Color(0xFFF3F5F9).withValues(alpha: 0.0),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
            ),
            // Right fade
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF3F5F9).withValues(alpha: 0.0),
                        const Color(0xFFF3F5F9).withValues(alpha: 0.95),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
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

  Widget _buildCard(String brand) {
    return Container(
      width: _cardWidth,
      height: _cardHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDEDED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(4, 4),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/pp-brands/$brand.png',
          fit: BoxFit.contain,
          width: 362,
          height: 164,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              brand.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gift360/config/app_flavor.dart';
import 'package:gift360/core/navigation/app_navigator.dart';
import 'package:gift360/features/feedback/presentation/widgets/feedback_form.dart';
import 'package:gift360/features/festival/presentation/providers/festival_provider.dart';
import 'package:gift360/features/festival/presentation/widgets/festival_image.dart';

const _coachmarkKey = 'sc_header_coachmark_seen';

Future<bool> _hasSeenCoachmark() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_coachmarkKey) == true;
}

Future<void> _markCoachmarkSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_coachmarkKey, true);
}

/// Simple app-wide light/dark toggle. There is no dark palette designed
/// yet, so this falls back to Flutter's default dark [ThemeData] — but the
/// toggle itself is real (wired in `main.dart`), not just decorative.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

/// Top navbar — a port of the mobile-visible portion of `components/Header.tsx`:
/// logo + live "N online" indicator, a notification bell, a theme toggle,
/// and a hamburger menu (nav links, account links, "Partner With Us", sign in).
///
/// The desktop-only pieces of the React header (search bar, location picker,
/// inline Orders/Cart buttons, wallet odometer) are hidden on real mobile
/// widths in the reference app too (`hidden md:flex` / `hidden sm:flex`), so
/// they're intentionally left out here to match what a phone actually shows.
class GiftHeader extends ConsumerWidget implements PreferredSizeWidget {
  const GiftHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < 600;
    final compact = width < 400;
    final horizontal = width >= 1024 ? 28.0 : phone ? (compact ? 8.0 : 12.0) : 20.0;
    final logoHeight = compact ? 52.0 : phone ? 62.0 : 72.0;
    final showOnline = width >= 390;
    final festival = festivalConfigOf(ref);
    final logoMaxWidth = showOnline ? (phone ? 270.0 : 320.0) : width * 0.78;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0x669747FF), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, phone ? 6 : 8, horizontal, phone ? 6 : 8),
          child: Row(
          children: [
            Flexible(
              child: GestureDetector(
                onTap: () => context.go('/'),
                child: FestivalLogo(
                  source: festival.logoUrl,
                  maxHeight: logoHeight,
                  maxWidth: logoMaxWidth,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            if (showOnline) ...[
              SizedBox(width: compact ? 4 : 8),
              const _OnlineIndicator(),
            ],

            const Spacer(),

            if (!AppFlavorConfig.isProd) const _FlavorChip(),
          ],
        ),
        ),
      ),
    );
  }

}

void showGift360Menu(BuildContext context, {required bool isAuthenticated}) {
  hideGlobalSupportChat();
  showGeneralDialog(
    context: context,
    barrierLabel: 'Menu',
    barrierDismissible: true,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) => Material(
      type: MaterialType.transparency,
      child: const SizedBox.shrink(),
    ),
    transitionBuilder: (ctx, anim1, anim2, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic));
      return Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: offset,
          child: _MenuPanel(isAuthenticated: isAuthenticated),
        ),
      );
    },
  ).whenComplete(showGlobalSupportChat);
}

/// SuperCoin header icon with auto-expand/collapse animation and coachmark.
/// Matches React's SuperCoinHeaderIcon component exactly.
class SuperCoinHeaderIcon extends StatefulWidget {
  final VoidCallback onTap;
  const SuperCoinHeaderIcon({super.key, required this.onTap});

  @override
  State<SuperCoinHeaderIcon> createState() => SuperCoinHeaderIconState();
}

class SuperCoinHeaderIconState extends State<SuperCoinHeaderIcon>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _spinning = false;
  bool _showCoachmark = false;
  Timer? _expandTimer;
  Timer? _collapseTimer;
  Timer? _intervalTimer;
  Timer? _coachmarkShowTimer;
  Timer? _coachmarkDismissTimer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
    _tryShowCoachmark();
  }

  @override
  void dispose() {
    _expandTimer?.cancel();
    _collapseTimer?.cancel();
    _intervalTimer?.cancel();
    _coachmarkShowTimer?.cancel();
    _coachmarkDismissTimer?.cancel();
    super.dispose();
  }

  void _tryShowCoachmark() async {
    if (await _hasSeenCoachmark()) return;
    if (!mounted) return;
    _coachmarkShowTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _markCoachmarkSeen();
      setState(() => _showCoachmark = true);
      _coachmarkDismissTimer = Timer(const Duration(milliseconds: 4000), () {
        if (mounted) setState(() => _showCoachmark = false);
      });
    });
  }

  void _dismissCoachmark() {
    _coachmarkDismissTimer?.cancel();
    if (mounted) setState(() => _showCoachmark = false);
  }

  void _startAnimation() {
    _expandTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _doExpand();
      _intervalTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        _doExpand();
      });
    });
  }

  void _doExpand() {
    setState(() {
      _expanded = true;
      _spinning = true;
    });
    Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _spinning = false);
    });
    _collapseTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _dismissCoachmark();
        widget.onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            width: _expanded ? 110 : 28,
            height: 28,
            decoration: BoxDecoration(
              color: _expanded
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final iconSize = availableWidth < 18 ? availableWidth : 18.0;
                final showLabel = _expanded && availableWidth >= 90;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedRotation(
                      turns: _spinning ? 1 : 0,
                      duration: const Duration(milliseconds: 600),
                      child: Image.asset(
                        'assets/images/SuperCOin-removebg-preview.png',
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (showLabel) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Convert coins',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          if (_showCoachmark)
            Positioned(
              top: 37,
              right: -8,
              child: GestureDetector(
                onTap: _dismissCoachmark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CustomPaint(
                      size: const Size(14, 7),
                      painter: _CoachmarkArrowPainter(),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 180,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 20,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Convert SuperCoins to a gift voucher, right here.',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF374151),
                              height: 1.4,
                            ),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: _dismissCoachmark,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE5E7EB),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  '✕',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoachmarkArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MenuPanel extends StatelessWidget {
  final bool isAuthenticated;

  const _MenuPanel({required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: min(360, MediaQuery.sizeOf(context).width * 0.86),
        height: double.infinity,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF7B5CFF), Color(0xFF9747FF)],
                      ).createShader(bounds),
                      child: const Text(
                        'Gift360',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _navTile(context, 'Home', Icons.home_outlined, '/'),
                _navTile(
                  context,
                  'Brands',
                  Icons.storefront_outlined,
                  '/brands',
                ),
                if (isAuthenticated) ...[
                  const Divider(height: 24),
                  _navTile(
                    context,
                    'Orders',
                    Icons.receipt_long_outlined,
                    '/my-orders',
                  ),
                  _navTile(
                    context,
                    'Vouchers',
                    Icons.local_mall_outlined,
                    '/orders',
                  ),
                  _navTile(
                    context,
                    'Notifications',
                    Icons.notifications_none_rounded,
                    '/notifications',
                  ),
                  _navTile(
                    context,
                    'Profile',
                    Icons.person_outline,
                    '/profile',
                  ),
                ],
                const Divider(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'PARTNER WITH US',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Color(0xFF888888),
                    ),
                  ),
                ),
                _navTile(
                  context,
                  'Distributor',
                  Icons.local_shipping_outlined,
                  '/distributor',
                ),
                _navTile(context, 'Reseller', Icons.storefront, '/reseller'),
                _navTile(
                  context,
                  'Corporate',
                  Icons.apartment_outlined,
                  '/corporate',
                ),
                const Divider(height: 24),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).pop();
                    final root = navigatorKey.currentContext;
                    if (root == null) return;
                    showDialog(
                      context: root,
                      builder: (_) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        insetPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 40,
                        ),
                        child: const FeedbackForm(),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          size: 18,
                          color: Color(0xFF1A1A1A),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Feedback',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (!isAuthenticated)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B5CFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext context,
    String label,
    IconData icon,
    String route,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).pop();
        context.push(route);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1A1A1A)),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlavorChip extends StatelessWidget {
  const _FlavorChip();

  @override
  Widget build(BuildContext context) {
    final dev = AppFlavorConfig.isDev;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dev ? const Color(0xFFE36A00) : const Color(0xFF1D4ED8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            AppFlavorConfig.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Port of `components/OnlineIndicator.tsx` (compact mode) — a purely
/// cosmetic pulsing-dot + slowly drifting fake "online" count, matching
/// the same drift range/timing as the React version.
class _OnlineIndicator extends StatefulWidget {
  const _OnlineIndicator();

  @override
  State<_OnlineIndicator> createState() => _OnlineIndicatorState();
}

class _OnlineIndicatorState extends State<_OnlineIndicator>
    with SingleTickerProviderStateMixin {
  final _random = Random();
  late int _count;
  Timer? _timer;
  late final AnimationController _pulseController;

  int _randomBetween(int min, int max) => min + _random.nextInt(max - min + 1);

  @override
  void initState() {
    super.initState();
    _count = _randomBetween(150, 500);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _scheduleNext();
  }

  void _scheduleNext() {
    final delayMs = _randomBetween(8000, 15000);
    _timer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      setState(() {
        final delta = _randomBetween(-18, 22);
        _count = _count + delta;
        if (_count > 500) _count = 500;
        if (_count < 150) _count = 150;
      });
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xB3A7F3D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final scale = 1 + _pulseController.value * 0.8;
              final opacity = (1 - _pulseController.value).clamp(0.0, 1.0);
              return SizedBox(
                width: 8,
                height: 8,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFF34D399,
                          ).withValues(alpha: 0.75 * opacity),
                        ),
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          Text(
            '$_count online',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }
}

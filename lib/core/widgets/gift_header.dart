import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/feedback/presentation/providers/feedback_provider.dart';
import 'package:gift360/features/feedback/presentation/widgets/feedback_form.dart';
import 'package:gift360/features/supercoin/presentation/widgets/supercoin_buy_sheet.dart';

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
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0x669747FF), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // ── Logo + live online indicator ──
            GestureDetector(
              onTap: () => context.go('/'),
              child: Image.asset(
                'assets/images/gift360full.png',
                height: 65,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            const _OnlineIndicator(),

            const Spacer(),

            // ── Feedback icon (with red dot badge) ──
            _FeedbackIconButton(isAuthenticated: isAuthenticated),

            // ── SuperCoin header icon ──
            // ── Notifications ──
            _iconButton(
              icon: Icons.notifications_none_rounded,
              badge: isAuthenticated,
              onTap: () => context.push('/notifications'),
            ),

            // ── Theme toggle ──
            _iconButton(
              icon: themeMode == ThemeMode.light ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              onTap: () => ref.read(themeModeProvider.notifier).state =
                  themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
            ),

            // ── Hamburger menu ──
            _iconButton(
              icon: Icons.menu_rounded,
              onTap: () => _openMenu(context, isAuthenticated),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({required IconData icon, VoidCallback? onTap, bool badge = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF1A1A1A)),
            if (badge)
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openMenu(BuildContext context, bool isAuthenticated) {
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
        final offset = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic));
        return Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: offset,
            child: _MenuPanel(isAuthenticated: isAuthenticated),
          ),
        );
      },
    );
  }
}

/// Feedback icon button with red dot badge (matches React Header feedback icon).
/// Shows red dot if user hasn't submitted feedback and hasn't been prompted yet.
/// Opens FeedbackForm dialog on tap.
class _FeedbackIconButton extends ConsumerStatefulWidget {
  final bool isAuthenticated;
  const _FeedbackIconButton({required this.isAuthenticated});

  @override
  ConsumerState<_FeedbackIconButton> createState() => _FeedbackIconButtonState();
}

class _FeedbackIconButtonState extends ConsumerState<_FeedbackIconButton> {
  bool _showBadge = false;

  @override
  void initState() {
    super.initState();
    _checkBadge();
  }

  Future<void> _checkBadge() async {
    if (!widget.isAuthenticated) return;
    final hasSubmitted = await FeedbackNotifier.hasSubmittedFeedback();
    final hasBeenPrompted = await FeedbackNotifier.hasBeenPrompted();
    if (mounted) {
      setState(() => _showBadge = !hasSubmitted && !hasBeenPrompted);
    }
  }

  void _openFeedback() {
    setState(() => _showBadge = false);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: const FeedbackForm(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openFeedback,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.message_outlined, size: 20, color: Color(0xFF1A1A1A)),
            if (_showBadge)
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// SuperCoin header icon with auto-expand/collapse animation and coachmark.
/// Matches React's SuperCoinHeaderIcon component exactly.
class SuperCoinHeaderIcon extends StatefulWidget {
  final VoidCallback onTap;
  const SuperCoinHeaderIcon({required this.onTap});

  @override
  State<SuperCoinHeaderIcon> createState() => SuperCoinHeaderIconState();
}

class SuperCoinHeaderIconState extends State<SuperCoinHeaderIcon> with SingleTickerProviderStateMixin {
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
    setState(() { _expanded = true; _spinning = true; });
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
            padding: _expanded ? const EdgeInsets.symmetric(horizontal: 10) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: _expanded ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: _spinning ? 1 : 0,
                  duration: const Duration(milliseconds: 600),
                  child: Image.asset(
                    'assets/images/SuperCOin-removebg-preview.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(width: 4),
                  Text('Convert coins', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ],
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Color(0x26000000), blurRadius: 20, offset: Offset(0, 4)),
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
                                child: Text('✕', style: TextStyle(fontSize: 8, color: Color(0xFF6B7280))),
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
        width: 280,
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
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
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
                _navTile(context, 'Brands', Icons.storefront_outlined, '/brands'),
                if (isAuthenticated) ...[
                  const Divider(height: 24),
                  _navTile(context, 'Orders', Icons.receipt_long_outlined, '/orders'),
                  _navTile(context, 'Notifications', Icons.notifications_none_rounded, '/notifications'),
                  _navTile(context, 'Profile', Icons.person_outline, '/profile'),
                ],
                const Divider(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'PARTNER WITH US',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: Color(0xFF888888)),
                  ),
                ),
                _navTile(context, 'Distributor', Icons.local_shipping_outlined, '/distributor'),
                _navTile(context, 'Reseller', Icons.storefront, '/reseller'),
                _navTile(context, 'Corporate', Icons.apartment_outlined, '/corporate'),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navTile(BuildContext context, String label, IconData icon, String route) {
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
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
          ],
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

class _OnlineIndicatorState extends State<_OnlineIndicator> with SingleTickerProviderStateMixin {
  final _random = Random();
  late int _count;
  Timer? _timer;
  late final AnimationController _pulseController;

  int _randomBetween(int min, int max) => min + _random.nextInt(max - min + 1);

  @override
  void initState() {
    super.initState();
    _count = _randomBetween(150, 500);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
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
                          color: const Color(0xFF34D399).withValues(alpha: 0.75 * opacity),
                        ),
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          Text(
            '$_count online',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
          ),
        ],
      ),
    );
  }
}

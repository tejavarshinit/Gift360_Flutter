import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Port of React `src/components/SuperCoinGuideSheet.tsx`.
///
/// A drag-to-dismiss bottom sheet with 4 swipeable screens (3 steps + tip),
/// progress segments, and a footer with Back/Next — or Got it / Go to Profile
/// on the final tip screen.
class SuperCoinGuideSheet extends StatefulWidget {
  final bool open;
  final VoidCallback onClose;

  const SuperCoinGuideSheet({
    super.key,
    required this.open,
    required this.onClose,
  });

  @override
  State<SuperCoinGuideSheet> createState() => _SuperCoinGuideSheetState();
}

class _StepMeta {
  final String title;
  final String text;
  final String badge;
  const _StepMeta(this.title, this.text, this.badge);
}

class _SuperCoinGuideSheetState extends State<SuperCoinGuideSheet>
    with SingleTickerProviderStateMixin {
  static const String _coinImg = 'assets/images/SuperCOin-removebg-preview.png';
  static const int _totalScreens = 4;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final Animation<double> _slide;

  PageController? _pageController;
  int _screen = 0;
  double _dragOffset = 0;

  static const List<_StepMeta> _stepMeta = [
    _StepMeta(
      'Add a voucher to your cart',
      "Pick any brand voucher you like and tap 'Add to Cart'.",
      '',
    ),
    _StepMeta(
      'Switch to SuperCoins',
      'Toggle from Cashback to SuperCoins in your cart to see your coins and how many you can use.',
      '20% of voucher value',
    ),
    _StepMeta(
      'Tap "Apply SC" and save',
      "Tap 'Apply SC' and the coins are deducted from your total. Then tap 'Pay' to continue your voucher journey.",
      '',
    ),
    _StepMeta(
      'Check your balance anytime',
      'Want to know how many SuperCoins you have? Tap your profile icon at the top right.',
      '',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _slide = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _pageController = PageController();
    if (widget.open) _open();
  }

  void _open() {
    _screen = 0;
    _dragOffset = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController?.hasClients ?? false) _pageController!.jumpToPage(0);
      _anim.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(covariant SuperCoinGuideSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) _open();
    if (!widget.open && oldWidget.open) _anim.reverse();
  }

  @override
  void dispose() {
    _anim.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  bool get _isTip => _screen == _totalScreens - 1;

  void _goTo(int index) {
    final target = index.clamp(0, _totalScreens - 1);
    if (_pageController?.hasClients ?? false) {
      _pageController!.animateToPage(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      setState(() => _screen = target);
    }
  }

  void _goPrev() => _goTo(_screen - 1);
  void _goNext() => _goTo(_screen + 1);

  void _goToProfile() {
    widget.onClose();
    context.push('/profile');
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    final viewInsets = MediaQuery.of(context).viewInsets;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _slide.value;
        final sheetOffset = (1 - t) * maxHeight + _dragOffset;
        final backdropOpacity = (0.5 * t).clamp(0.0, 1.0);

        return Stack(
          children: [
            // Backdrop (z-110)
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  color: Colors.black.withValues(alpha: backdropOpacity),
                ),
              ),
            ),
            // Sheet (z-120)
            Positioned(
              left: 0,
              right: 0,
              bottom: viewInsets.bottom,
              child: Transform.translate(
                offset: Offset(0, sheetOffset),
                child: _buildSheet(context, maxHeight),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSheet(BuildContext context, double maxHeight) {
    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (d.primaryDelta! < 0 && _dragOffset < 0) return;
        setState(() => _dragOffset += d.primaryDelta!);
      },
      onVerticalDragEnd: (d) {
        final shouldClose =
            _dragOffset > 130 || (d.velocity.pixelsPerSecond.dy > 650);
        if (shouldClose) {
          widget.onClose();
        } else {
          setState(() => _dragOffset = 0);
        }
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4016162C),
                blurRadius: 36,
                offset: Offset(0, -16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              _buildHeader(),
              _buildProgress(),
              Flexible(child: _buildContent()),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Drag handle ──
  Widget _buildDragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
        child: Center(
          child: Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFC6CAD6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(_coinImg, width: 32, height: 32, fit: BoxFit.contain),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to use SuperCoins',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF11131D),
                    height: 1.2,
                  ),
                ),
                Text(
                  '3 quick steps to save on your next voucher',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[500],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A1F213B),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress: 3 segments + tip dot ──
  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                decoration: BoxDecoration(
                  color: _screen >= i
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _screen >= 3
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFE5E7EB),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  // ── Swipeable step content ──
  Widget _buildContent() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _totalScreens,
      onPageChanged: (i) => setState(() => _screen = i),
      itemBuilder: (context, i) => _buildStepPage(i),
    );
  }

  Widget _buildStepPage(int i) {
    final meta = _stepMeta[i];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEDE9FE)),
            ),
            child: Center(
              child: switch (i) {
                0 => const _StepCartIllustration(),
                1 => const _StepToggleIllustration(),
                2 => const _StepApplyIllustration(),
                _ => const _TipIllustration(),
              },
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 90,
                ),
                child: Text(
                  meta.title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF151722),
                    height: 1.3,
                  ),
                ),
              ),
              if (meta.badge.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F1FE),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x407C3AED)),
                  ),
                  child: Text(
                    meta.badge,
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            meta.text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer actions ──
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FA),
        border: const Border(top: BorderSide(color: Color(0xFFF3F4F6))),
        boxShadow: [
          BoxShadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 8),
        ],
      ),
      child: _isTip ? _buildTipFooter() : _buildStepFooter(),
    );
  }

  Widget _buildStepFooter() {
    final canBack = _screen > 0;
    return Row(
      children: [
        _footerButton(
          onTap: canBack ? _goPrev : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chevron_left,
                size: 16,
                color: Color(0xFF374151),
              ),
              const SizedBox(width: 2),
              Text(
                'Back',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
            ],
          ),
          enabled: canBack,
        ),
        Expanded(
          child: Center(
            child: Text(
              '${_screen + 1} of 3',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey[400],
              ),
            ),
          ),
        ),
        _footerButton(
          onTap: _goNext,
          primary: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Next',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.white),
            ],
          ),
          enabled: true,
        ),
      ],
    );
  }

  Widget _buildTipFooter() {
    return Row(
      children: [
        Expanded(
          child: _footerButton(
            onTap: widget.onClose,
            primary: false,
            bordered: true,
            expanded: true,
            child: Text(
              'Got it',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            enabled: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _footerButton(
            onTap: _goToProfile,
            primary: true,
            expanded: true,
            child: Text(
              'Go to Profile',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            enabled: true,
          ),
        ),
      ],
    );
  }

  Widget _footerButton({
    required VoidCallback? onTap,
    required Widget child,
    required bool enabled,
    bool primary = false,
    bool bordered = false,
    bool expanded = false,
  }) {
    final isEnabled = enabled && onTap != null;
    return Opacity(
      opacity: isEnabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: expanded
                ? const EdgeInsets.symmetric(vertical: 10)
                : const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary || bordered
                  ? (primary ? const Color(0xFF7C3AED) : Colors.white)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: bordered
                  ? Border.all(color: const Color(0xFFE5E7EB))
                  : null,
              boxShadow: primary
                  ? const [
                      BoxShadow(
                        color: Color(0x4D7C3AED),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Illustrations (port of the React step illustrations)
// ═══════════════════════════════════════════════════════════

/// Screen 0 — voucher card dropping into a cart.
class _StepCartIllustration extends StatefulWidget {
  const _StepCartIllustration();
  @override
  State<_StepCartIllustration> createState() => _StepCartIllustrationState();
}

class _StepCartIllustrationState extends State<_StepCartIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final voucherDrop = Curves.easeOutBack.transform(
          (t / 0.55).clamp(0, 1),
        );
        final badge = Curves.easeOutBack.transform(
          ((t - 0.55) / 0.35).clamp(0, 1),
        );

        return SizedBox(
          height: 112,
          width: 250,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, (1 - voucherDrop) * -54),
                child: Transform.rotate(
                  angle: (1 - voucherDrop) * -0.24,
                  child: Opacity(
                    opacity: voucherDrop.clamp(0.0, 1.0),
                    child: Container(
                      width: 104,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                          style: BorderStyle.solid,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2E7C3AED),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF7C3AED),
                                      Color(0xFF3B82F6),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Gift Voucher',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const DashedLine(),
                          const SizedBox(height: 6),
                          Text(
                            '₹1500',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEDE9FE)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x337C3AED),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shopping_cart,
                      size: 32,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Transform.scale(
                      scale: badge.clamp(0.0, 1.3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '+1',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class DashedLine extends StatelessWidget {
  const DashedLine({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1.5,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dashWidth = 4.0;
          final dashCount = (constraints.maxWidth / (dashWidth * 2)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              dashCount,
              (_) => Container(
                width: dashWidth,
                height: 1,
                color: const Color(0xFFE5E7EB),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Screen 1 — mock Cashback/SuperCoins toggle + balance stat rows (count-up).
class _StepToggleIllustration extends StatefulWidget {
  const _StepToggleIllustration();
  @override
  State<_StepToggleIllustration> createState() =>
      _StepToggleIllustrationState();
}

class _StepToggleIllustrationState extends State<_StepToggleIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();
  late final Animation<double> _toggle = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.2, 0.5, curve: Curves.easeOutBack),
  );
  late final Animation<double> _stats = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final scMode = _toggle.value > 0.5;
          final showStats = _stats.value > 0;
          final balance = (250 * _stats.value).round();
          final usable = (50 * _stats.value).round();

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEDE9FE)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F7C3AED),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Container(
                  height: 30,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F1FE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Stack(
                    children: [
                      // Sliding knob
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutBack,
                        left: scMode ? 100 : 0,
                        top: 4,
                        bottom: 4,
                        width: 96,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _toggleLabel('Cashback', !scMode),
                          _toggleLabel('SuperCoins', scMode),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                opacity: showStats ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    _statRow('Your balance', balance, const Color(0xFF6D28D9)),
                    const SizedBox(height: 8),
                    _statRow('You can use', usable, const Color(0xFF10B981)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toggleLabel(String label, bool active) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF6D28D9) : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, int value, Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F0FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A7C3AED),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/SuperCOin-removebg-preview.png',
            width: 14,
            height: 14,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F1FE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'example',
              style: GoogleFonts.poppins(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7C3AED),
              ),
            ),
          ),
          const Spacer(),
          Text(
            '$value SC',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen 2 — "Apply SC" pulse + price strike-through & coin burst.
class _StepApplyIllustration extends StatefulWidget {
  const _StepApplyIllustration();
  @override
  State<_StepApplyIllustration> createState() => _StepApplyIllustrationState();
}

class _StepApplyIllustrationState extends State<_StepApplyIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  static const List<Offset> _coins = [
    Offset(-26, -30),
    Offset(22, -34),
    Offset(-34, 8),
    Offset(30, 12),
    Offset(0, -40),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      width: 250,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          final buttonPulse = Curves.easeInOut.transform((t / 0.3).clamp(0, 1));
          final strike = Curves.easeOut.transform(
            ((t - 0.34) / 0.15).clamp(0, 1),
          );
          final saved = Curves.easeOutBack.transform(
            ((t - 0.47) / 0.15).clamp(0, 1),
          );
          final burst = ((t - 0.6) / 0.3).clamp(0.0, 1.0);
          final pulseScale =
              1 -
              0.1 *
                  (buttonPulse < 0.5 ? buttonPulse * 2 : (1 - buttonPulse) * 2);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: pulseScale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x597C3AED),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/SuperCOin-removebg-preview.png',
                        width: 14,
                        height: 14,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Apply SC',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEDE9FE)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F7C3AED),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Text(
                              '₹500',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[400],
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 9,
                              child: Container(
                                width: 40 * strike,
                                height: 2,
                                color: const Color(0xFFE11D48),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Opacity(
                          opacity: saved.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, (1 - saved.clamp(0.0, 1.0)) * 4),
                            child: Text(
                              '₹450',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Coin burst
                  for (var i = 0; i < _coins.length; i++)
                    if (burst > 0 && burst < 1)
                      Positioned.fill(
                        child: Center(
                          child: Transform.translate(
                            offset: Offset(
                              _coins[i].dx * burst,
                              _coins[i].dy * burst,
                            ),
                            child: Opacity(
                              opacity: burst < 0.5
                                  ? burst * 2
                                  : (1 - burst) * 2,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFFDE68A),
                                      Color(0xFFF59E0B),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Screen 3 — final tip: gradient header mock with avatar & waving hand.
class _TipIllustration extends StatefulWidget {
  const _TipIllustration();
  @override
  State<_TipIllustration> createState() => _TipIllustrationState();
}

class _TipIllustrationState extends State<_TipIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF523DA9), Color(0xFF4C42B8), Color(0xFF5365DF)],
          stops: [0.0, 0.48, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x47523DA9),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 112,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _ring,
                  builder: (context, _) {
                    final p = _ring.value;
                    final ringSpread = 9 * (p < 0.7 ? p / 0.7 : 1.0);
                    final ringOpacity = p < 0.7 ? 0.75 * (1 - p / 0.7) : 0.0;
                    return Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE99DA8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: ringOpacity),
                            blurRadius: 0,
                            spreadRadius: ringSpread,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                Positioned(
                  left: -16,
                  bottom: -12,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      final p = (_ctrl.value * 2) % 1.0;
                      final dy = -5 * (p < 0.5 ? p * 2 : (1 - p) * 2);
                      final rot = -0.14 * (p < 0.5 ? p * 2 : (1 - p) * 2);
                      return Transform.translate(
                        offset: Offset(0, dy),
                        child: Transform.rotate(
                          angle: rot,
                          child: const Icon(
                            Icons.back_hand,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';

/// Reusable bottom navigation bar shown across tabs and standalone screens
/// (Orders, Nearby) so the nav is consistent app-wide. Uses go_router's
/// [context.go] so it works both inside and outside the navigation shell.
class AppBottomNav extends ConsumerStatefulWidget {
  /// Index of the active tab (0=Home, 1=Categories, 2=Brand, 3=Cart).
  /// Pass -1 when no tab is active (e.g. Orders, Nearby).
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  @override
  ConsumerState<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends ConsumerState<AppBottomNav> with SingleTickerProviderStateMixin {
  late final AnimationController _cartPulseController;
  late final Animation<double> _cartOpacity;
  late final Animation<Offset> _cartOffset;
  late final Animation<double> _cartScale;
  ProviderSubscription<int>? _cartSubscription;
  int _lastCartCount = 0;

  @override
  void initState() {
    super.initState();
    _cartPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    final curve = CurvedAnimation(parent: _cartPulseController, curve: Curves.easeOut);
    _cartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 80),
    ]).animate(curve);
    _cartOffset = Tween(begin: const Offset(0, 0.35), end: const Offset(0, -1.2)).animate(curve);
    _cartScale = Tween(begin: 0.7, end: 1.05).animate(curve);
    _lastCartCount = ref.read(cartItemCountProvider);
    _cartSubscription = ref.listenManual<int>(cartItemCountProvider, (previous, next) {
      if (next > _lastCartCount && mounted) _cartPulseController.forward(from: 0);
      _lastCartCount = next;
    });
  }

  @override
  void dispose() {
    _cartPulseController.dispose();
    _cartSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOrdersRoute = GoRouterState.of(context).uri.path.startsWith('/orders');
    if (isOrdersRoute) return const SizedBox.shrink();
    final cartCount = ref.watch(cartItemCountProvider);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 63,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  isActive: widget.currentIndex == 0,
                  onTap: () => context.go('/'),
                ),
                _NavItem(
                  icon: Icons.grid_view_outlined,
                  label: 'Categories',
                  isActive: widget.currentIndex == 1,
                  onTap: () => context.go('/categories'),
                ),
                _NavItem(
                  icon: Icons.store_outlined,
                  label: 'Brands',
                  isActive: widget.currentIndex == 2,
                  onTap: () => context.go('/brands'),
                ),
                _NavItem(
                  icon: Icons.shopping_cart_outlined,
                  fillIcon: Icons.shopping_cart,
                  label: 'Cart',
                  isActive: widget.currentIndex == 3,
                  cartCount: cartCount,
                  cartOpacity: _cartOpacity,
                  cartOffset: _cartOffset,
                  cartScale: _cartScale,
                  onTap: () => context.go('/cart'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData? fillIcon;
  final String label;
  final bool isActive;
  final int cartCount;
  final Animation<double>? cartOpacity;
  final Animation<Offset>? cartOffset;
  final Animation<double>? cartScale;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    this.fillIcon,
    required this.label,
    required this.isActive,
    this.cartCount = 0,
    this.cartOpacity,
    this.cartOffset,
    this.cartScale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF10AEEc) : const Color(0xFF092F82);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(isActive ? (fillIcon ?? icon) : icon, size: 20, color: color),
                if (label == 'Cart' && cartCount > 0)
                  Positioned(
                    top: -5,
                    right: -10,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Color(0xFF10AEEc), shape: BoxShape.circle),
                      child: Text('$cartCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, height: 1)),
                    ),
                  ),
                if (label == 'Cart' && cartOpacity != null && cartOffset != null && cartScale != null)
                  Positioned(
                    top: -18,
                    left: 2,
                    child: FadeTransition(
                      opacity: cartOpacity!,
                      child: SlideTransition(
                        position: cartOffset!,
                        child: ScaleTransition(scale: cartScale!, child: const Text('+1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10AEEc))),),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w500,
                color: color,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

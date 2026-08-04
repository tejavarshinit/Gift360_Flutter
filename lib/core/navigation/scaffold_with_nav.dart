import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/core/widgets/gift_header.dart';
import 'package:gift360/core/widgets/notification_toast.dart';

class ScaffoldWithNav extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNav({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const GiftHeader(),
              Expanded(
                child: navigationShell,
              ),
            ],
          ),
          const NotificationToast(),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 63,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14282A44),
                  blurRadius: 18,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    fillIcon: Icons.home_rounded,
                    label: 'Home',
                    isActive: navigationShell.currentIndex == 0,
                    onTap: () => navigationShell.goBranch(0),
                  ),
                  _NavItem(
                    icon: Icons.grid_view_outlined,
                    fillIcon: Icons.grid_view_rounded,
                    label: 'Categories',
                    isActive: navigationShell.currentIndex == 1,
                    onTap: () => navigationShell.goBranch(1),
                  ),
                  _NavItem(
                    icon: Icons.store_outlined,
                    fillIcon: Icons.store_rounded,
                    label: 'Brand',
                    isActive: navigationShell.currentIndex == 2,
                    onTap: () => navigationShell.goBranch(2),
                  ),
                  _NavItem(
                    icon: Icons.shopping_cart_outlined,
                    fillIcon: Icons.shopping_cart_rounded,
                    label: 'Cart',
                    isActive: navigationShell.currentIndex == 3,
                    onTap: () => navigationShell.goBranch(3),
                  ),
                ],
              ),
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
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    this.fillIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.navActive : AppColors.navInactive;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? (fillIcon ?? icon) : icon,
              size: 20,
              color: color,
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

import 'package:flutter/material.dart';

/// Shared mobile backdrop used by the React reference pages: a flat #f3f5f9
/// base -- what React renders on Home/Cart/Brands/Categories/MyOrders/Orders
/// after the festival backdrop image was removed.
class ReactBackdropBackground extends StatelessWidget {
  const ReactBackdropBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(color: const Color(0xFFF3F5F9));
  }
}

class ReactBackdrop extends StatelessWidget {
  final Widget child;

  const ReactBackdrop({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ReactBackdropBackground(),
        child,
      ],
    );
  }
}

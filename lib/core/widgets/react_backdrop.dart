import 'package:flutter/material.dart';

/// Shared mobile backdrop used by the React reference pages: a flat #f3f5f9
/// base with the festival backdrop image (`dussehrabackdrop.png`) on top,
/// cover-fitted and centred -- exactly what React renders on Home/Cart/
/// Brands/Categories/MyOrders/Orders.
class ReactBackdropBackground extends StatelessWidget {
  final String asset;

  const ReactBackdropBackground({
    super.key,
    this.asset = ReactBackdrop.defaultAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFFF3F5F9)),
        Image.asset(asset, fit: BoxFit.cover, alignment: Alignment.center),
      ],
    );
  }
}

class ReactBackdrop extends StatelessWidget {
  static const String defaultAsset = 'assets/images/dussehrabackdrop.png';

  final Widget child;
  final String asset;

  const ReactBackdrop({
    super.key,
    required this.child,
    this.asset = defaultAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ReactBackdropBackground(asset: asset),
        child,
      ],
    );
  }
}

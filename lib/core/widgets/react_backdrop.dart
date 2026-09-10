import 'package:flutter/material.dart';

/// Shared mobile backdrop used by the React reference pages.
class ReactBackdrop extends StatelessWidget {
  final Widget child;
  final String asset;

  const ReactBackdrop({super.key, required this.child, this.asset = 'assets/images/ganeshbackdrop.png'});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.cover),
        Container(color: Colors.white.withValues(alpha: 0.16)),
        child,
      ],
    );
  }
}

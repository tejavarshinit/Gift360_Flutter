import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders an asset path or https URL with the same fit rules so festival
/// image swaps (logo / hero / background) stay visually stable.
class FestivalImage extends StatelessWidget {
  const FestivalImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.opacity,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Animation<double>? opacity;

  bool get _isNetwork =>
      source.startsWith('http://') || source.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) {
      return SizedBox(width: width, height: height);
    }

    if (_isNetwork) {
      return CachedNetworkImage(
        imageUrl: source,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) => SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, _, _) => SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      );
    }

    return Image.asset(
      source,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      opacity: opacity,
      errorBuilder: (_, _, _) => SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
      ),
    );
  }
}

/// Logo slot sized by max height — works for wide wordmarks and taller
/// festival logos without clipping awkwardly.
class FestivalLogo extends StatelessWidget {
  const FestivalLogo({
    super.key,
    required this.source,
    this.maxHeight = 64,
    this.maxWidth = 240,
    this.alignment = Alignment.center,
  });

  final String source;
  final double maxHeight;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        maxWidth: maxWidth,
      ),
      child: FestivalImage(
        source: source,
        height: maxHeight,
        fit: BoxFit.contain,
        alignment: alignment,
      ),
    );
  }
}

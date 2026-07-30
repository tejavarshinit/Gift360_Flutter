import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gift360/core/widgets/html_img/html_img.dart';

class BrandImage extends StatefulWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;

  const BrandImage({
    super.key,
    this.imageUrl,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<BrandImage> createState() => _BrandImageState();
}

int _htmlImgViewTypeCounter = 0;

class _BrandImageState extends State<BrandImage> {
  String? _viewType;
  String? _registeredUrl;
  ValueNotifier<HtmlImgStatus>? _status;

  @override
  void didUpdateWidget(BrandImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb && widget.imageUrl != _registeredUrl) {
      _registerWebImage();
    }
  }

  void _registerWebImage() {
    final url = widget.imageUrl!;
    _viewType = 'brand-img-${_htmlImgViewTypeCounter++}';
    _status = registerHtmlImage(_viewType!, url, widget.fit);
    _registeredUrl = url;
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return const SizedBox();

    if (kIsWeb) {
      if (_registeredUrl != url) _registerWebImage();
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ValueListenableBuilder<HtmlImgStatus>(
          valueListenable: _status!,
          builder: (context, status, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                buildHtmlImageView(_viewType!),
                if (status == HtmlImgStatus.loading)
                  widget.placeholder?.call(context, url) ?? const SizedBox(),
                if (status == HtmlImgStatus.error)
                  widget.errorWidget?.call(context, url, Exception('image failed to load')) ??
                      const SizedBox(),
              ],
            );
          },
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      placeholder: widget.placeholder ?? (_, __) => const SizedBox(),
      errorWidget: widget.errorWidget ?? (_, __, ___) => const SizedBox(),
    );
  }
}

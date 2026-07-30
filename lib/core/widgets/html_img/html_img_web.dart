import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

enum HtmlImgStatus { loading, loaded, error }

String cssObjectFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.cover:
      return 'cover';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.fitWidth:
    case BoxFit.fitHeight:
      return 'cover';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
    case BoxFit.contain:
      return 'contain';
  }
}

/// Registers a real browser `<img>` element as a platform view for [viewType].
///
/// A native `<img src>` load is never subject to CORS (only fetch/XHR/canvas
/// reads are) — this mirrors exactly how the React reference renders these
/// CDN images, instead of routing through Flutter's CachedNetworkImage,
/// which fetches bytes via XHR and gets CORS-blocked by these CDNs.
ValueNotifier<HtmlImgStatus> registerHtmlImage(String viewType, String url, BoxFit fit) {
  final status = ValueNotifier(HtmlImgStatus.loading);
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
    final img = web.HTMLImageElement()
      ..src = url
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = cssObjectFit(fit)
      ..style.display = 'block'
      ..style.border = 'none';
    img.onLoad.listen((_) => status.value = HtmlImgStatus.loaded);
    img.onError.listen((_) => status.value = HtmlImgStatus.error);
    return img;
  });
  return status;
}

Widget buildHtmlImageView(String viewType) => HtmlElementView(viewType: viewType);

import 'package:flutter/material.dart';

enum HtmlImgStatus { loading, loaded, error }

ValueNotifier<HtmlImgStatus> registerHtmlImage(String viewType, String url, BoxFit fit) =>
    ValueNotifier(HtmlImgStatus.loaded);

Widget buildHtmlImageView(String viewType) => const SizedBox();

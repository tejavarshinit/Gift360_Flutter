import 'package:flutter/material.dart';

/// Floating snackbar that clears the bottom nav + system gesture inset.
void showAppSnackBar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 3),
}) {
  final media = MediaQuery.of(context);
  final bottomInset = media.padding.bottom;
  // Bottom nav (~58–68) + gap so snackbars never sit under the bar.
  final marginBottom = bottomInset + 72;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, marginBottom),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: backgroundColor,
      duration: duration,
    ),
  );
}

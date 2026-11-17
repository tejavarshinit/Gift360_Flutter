import 'package:flutter/widgets.dart';

/// Window sizes used by the presentation layer.
///
/// Phone keeps the existing full-width layout. Tablet and desktop center
/// page content and switch the tab shell from a bottom bar to a side rail.
abstract final class AppBreakpoints {
  static const double phone = 600;
  static const double tablet = 1024;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isPhone(BuildContext context) => widthOf(context) < phone;

  static bool isTablet(BuildContext context) {
    final width = widthOf(context);
    return width >= phone && width < tablet;
  }

  static bool isDesktop(BuildContext context) => widthOf(context) >= tablet;

  /// Horizontal inset for chrome (header, menu, nav), scaled from the window.
  static double horizontalPadding(BuildContext context) {
    final width = widthOf(context);
    if (width >= tablet) return 28;
    if (width >= phone) return 20;
    return 12;
  }
}

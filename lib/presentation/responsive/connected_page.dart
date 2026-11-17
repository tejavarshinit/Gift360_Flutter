import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_breakpoints.dart';

/// Connects one page bloc to that page's widgets.
///
/// The bloc classes stay in `lib/bloc`. This frame only provides the bloc
/// and lays the existing screen out from [MediaQuery].
class ConnectedPage<B extends Bloc<E, S>, E, S> extends StatelessWidget {
  const ConnectedPage({
    super.key,
    required this.create,
    required this.started,
    required this.child,
    this.maxContentWidth,
  });

  final B Function() create;
  final E started;
  final Widget child;

  /// Centered content width once the window is wider than a phone.
  /// Null keeps the page full-bleed (onboarding, maps, payment webview).
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<B>(
      create: (_) => create()..add(started),
      child: ResponsiveFrame(maxContentWidth: maxContentWidth, child: child),
    );
  }
}

/// Centers page content on tablet and desktop and leaves phone layout alone.
class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({
    super.key,
    required this.child,
    this.maxContentWidth,
  });

  final Widget child;
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final maxWidth = maxContentWidth;
    final shouldFrame = maxWidth != null &&
        width >= AppBreakpoints.phone &&
        width > maxWidth;
    if (!shouldFrame) return child;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: MediaQuery(
            data: media.copyWith(size: Size(maxWidth, media.size.height)),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

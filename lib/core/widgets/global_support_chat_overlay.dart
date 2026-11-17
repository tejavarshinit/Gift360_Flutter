import 'package:flutter/material.dart';

import 'package:gift360/core/navigation/app_navigator.dart';
import 'package:gift360/core/navigation/location_tracker.dart';
import 'package:gift360/features/support/presentation/widgets/support_chat_widget.dart';

/// The single global support chat, matching React App.tsx's
/// `GlobalSupportChat` + `SupportChatWidget`.
class GlobalSupportChatOverlay extends StatelessWidget {
  const GlobalSupportChatOverlay({super.key});

  static const _blockedPrefixes = [
    '/admin',
    '/onboarding',
    '/login',
    '/register',
    '/forgot-password',
    '/reset-password',
    '/payment-result',
    '/payment-webview',
  ];

  static bool _isBlocked(String path) =>
      _blockedPrefixes.any((p) => path == p || path.startsWith('$p/'));

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLocation,
      builder: (context, location, _) {
        if (_isBlocked(location)) return const SizedBox.shrink();
        return ValueListenableBuilder<int>(
          valueListenable: supportChatHideCount,
          builder: (context, hideCount, _) {
            if (hideCount > 0) return const SizedBox.shrink();
            final media = MediaQuery.of(context);
            final wide = media.size.width >= 1024;
            final navHeight = wide
                ? 0.0
                : media.size.width >= 600
                ? 68.0
                : 58.0;
            return Positioned.fill(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: 16,
                    bottom: media.padding.bottom + navHeight + 12,
                  ),
                  child: const SupportChatWidget(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

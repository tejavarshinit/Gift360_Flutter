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
            return const Positioned.fill(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 16, bottom: 72),
                  child: SupportChatWidget(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

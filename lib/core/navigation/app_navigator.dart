import 'package:flutter/widgets.dart';

/// Global navigator key — used by the 401 handler and by app-level overlays
/// (e.g. the support chatbot) that live above the Navigator and therefore need
/// a Navigator/GoRouter-bearing context.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Reference-counted hide switch for the global support-chat FAB. Purchase
/// sheets and payment-result screens increment this while their foreground UI
/// should remain unobstructed.
final ValueNotifier<int> supportChatHideCount = ValueNotifier<int>(0);

void hideGlobalSupportChat() {
  supportChatHideCount.value++;
}

void showGlobalSupportChat() {
  if (supportChatHideCount.value > 0) {
    supportChatHideCount.value--;
  }
}

/// Context under the root Navigator (null until the first frame).
BuildContext? get appRootContext => navigatorKey.currentContext;

import 'package:flutter/material.dart';

import 'package:gift360/config/app_config.dart';
import 'package:gift360/core/navigation/app_navigator.dart';
import 'package:gift360/features/supercoin/presentation/widgets/supercoin_brand_modal.dart';

/// Opens the SuperCoin convert sheet as a dialog over the current page
/// (usually home) so that page stays visible behind the dim barrier.
Future<void> openSuperCoinVoucher(BuildContext context) async {
  hideGlobalSupportChat();
  await showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SuperCoinBrandModal(
        open: true,
        brandId: SuperCoinConversionConfig.featuredBrandId,
        onClose: () {
          final nav = Navigator.of(dialogContext, rootNavigator: true);
          if (nav.canPop()) nav.pop();
        },
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  ).whenComplete(showGlobalSupportChat);
}

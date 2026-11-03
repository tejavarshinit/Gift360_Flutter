import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/supercoin/presentation/widgets/supercoin_brand_modal.dart';

/// Standalone full-screen host for the SuperCoin brand modal, mirroring
/// React's `pages/SuperCoinVoucherPreview.tsx` (`/supercoin-voucher` route).
class SuperCoinVoucherScreen extends ConsumerStatefulWidget {
  const SuperCoinVoucherScreen({super.key});

  @override
  ConsumerState<SuperCoinVoucherScreen> createState() => _SuperCoinVoucherScreenState();
}

class _SuperCoinVoucherScreenState extends ConsumerState<SuperCoinVoucherScreen> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SuperCoinBrandModal(
        open: _open,
        brandId: SuperCoinConversionConfig.featuredBrandId,
        onClose: () {
          setState(() => _open = false);
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      ),
    );
  }
}

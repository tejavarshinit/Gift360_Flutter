import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gift360/core/navigation/app_navigator.dart';
import 'package:gift360/features/supercoin/presentation/widgets/open_supercoin_voucher.dart';

/// Deep-link / route host. Immediately hands off to a dialog over the
/// previous page (home) so the background is never a blank screen.
class SuperCoinVoucherScreen extends ConsumerStatefulWidget {
  const SuperCoinVoucherScreen({super.key});

  @override
  ConsumerState<SuperCoinVoucherScreen> createState() =>
      _SuperCoinVoucherScreenState();
}

class _SuperCoinVoucherScreenState
    extends ConsumerState<SuperCoinVoucherScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/');
      }
      await Future<void>.delayed(Duration.zero);
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await openSuperCoinVoucher(ctx);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.shrink(),
    );
  }
}

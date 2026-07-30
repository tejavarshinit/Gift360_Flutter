import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/wallet/data/models/wallet.dart';
import 'package:gift360/features/wallet/data/repositories/wallet_api.dart';
import 'package:gift360/features/wallet/data/repositories/wallet_repository.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';

final walletApiProvider = Provider<WalletApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return WalletApi(dio);
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final api = ref.watch(walletApiProvider);
  return WalletRepository(api);
});

final walletBalanceProvider = FutureProvider.autoDispose<WalletBalance?>((ref) async {
  final user = ref.watch(authProvider);
  if (user?.clientId == null) return null;
  final clientId = user!.clientId!;
  final repo = ref.watch(walletRepositoryProvider);
  return repo.getWalletBalance(clientId);
});

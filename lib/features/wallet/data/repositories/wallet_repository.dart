import 'package:gift360/features/wallet/data/models/wallet.dart';
import 'package:gift360/features/wallet/data/repositories/wallet_api.dart';

class WalletRepository {
  final WalletApi _api;

  WalletRepository(this._api);

  Future<WalletBalance> getWalletBalance(String clientId) async {
    return await _api.fetchWalletBalance(clientId);
  }
}

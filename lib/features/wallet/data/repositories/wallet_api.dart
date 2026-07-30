import 'package:dio/dio.dart';
import 'package:gift360/features/wallet/data/models/wallet.dart';

class WalletApi {
  final Dio _dio;

  WalletApi(this._dio);

  Future<WalletBalance> fetchWalletBalance(String clientId) async {
    final response = await _dio.post('/wallet/$clientId', data: {});
    return WalletBalance.fromJson(response.data as Map<String, dynamic>);
  }
}

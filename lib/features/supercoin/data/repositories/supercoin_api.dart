import 'package:dio/dio.dart';

class SuperCoinIdentity {
  final String identifier;
  final String type;

  const SuperCoinIdentity({required this.identifier, required this.type});

  Map<String, dynamic> toJson() => {'identifier': identifier, 'type': type};
}

class SuperCoinApi {
  final Dio _dio;

  SuperCoinApi(this._dio);

  Future<Map<String, dynamic>> searchUser(SuperCoinIdentity identity) =>
      _post('/v1/supercoin/searchUser', {'identity': identity.toJson()});

  Future<Map<String, dynamic>> enrolUser(SuperCoinIdentity identity) =>
      _post('/v1/supercoin/enrolUser', {'identity': identity.toJson()});

  Future<Map<String, dynamic>> fetchBalance(SuperCoinIdentity identity) =>
      _post('/v1/supercoin/balance', {'identity': identity.toJson()});

  Future<Map<String, dynamic>> initHold(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/initHold', payload);

  Future<Map<String, dynamic>> authorizeHold(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/authorizeHold', payload);

  Future<Map<String, dynamic>> createHold(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/hold', payload);

  Future<Map<String, dynamic>> redeemHold(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/redeemHold', payload);

  Future<Map<String, dynamic>> unhold(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/unhold', payload);

  Future<Map<String, dynamic>> refund(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/refund', payload);

  Future<Map<String, dynamic>> fetchTransactions(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/transactions', payload);

  Future<Map<String, dynamic>> fetchExpiring(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/expiring', payload);

  Future<Map<String, dynamic>> fetchTransactionStatus(
          String transactionId, Map<String, dynamic> payload) =>
      _post('/v1/supercoin/transaction/$transactionId/status', payload);

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> data) async {
    final response = await _dio.post(path, data: data);
    return response.data as Map<String, dynamic>;
  }
}

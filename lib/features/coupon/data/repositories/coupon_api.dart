import 'package:dio/dio.dart';
import 'package:gift360/features/payment/data/models/payment.dart';

class CouponApi {
  final Dio _dio;

  CouponApi(this._dio);

  Future<CouponValidateResponse> validateCoupon(
      CouponValidateRequest request) async {
    final response = await _dio.post('/coupon-codes/validate',
        data: request.toJson());
    final data = response.data as Map<String, dynamic>;
    return CouponValidateResponse.fromJson({
      ...data,
      'httpStatus': response.statusCode,
      'httpMessage': response.statusMessage,
    });
  }

  Future<Map<String, dynamic>> confirmCoupon(
      CouponConfirmRequest request) async {
    final response =
        await _dio.post('/coupon-codes/confirm', data: request.toJson());
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> releaseCoupon(
      CouponReleaseRequest request) async {
    final response =
        await _dio.post('/coupon-codes/release', data: request.toJson());
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchCoupons(Map<String, dynamic> request) async {
    final response = await _dio.post('/coupons/fetch', data: request);
    return response.data as Map<String, dynamic>;
  }
}

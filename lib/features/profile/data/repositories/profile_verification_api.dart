import 'package:dio/dio.dart';

import 'package:gift360/features/profile/data/models/profile_verification.dart';

class ProfileVerificationApi {
  final Dio _dio;

  const ProfileVerificationApi(this._dio);

  /// GET /api/v1/profile/verification (the Dio base already ends in `/api`).
  Future<ProfileVerification> fetch() async {
    final response = await _dio.get('/v1/profile/verification');
    return ProfileVerification.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }
}

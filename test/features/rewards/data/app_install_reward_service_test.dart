import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gift360/features/rewards/data/app_install_reward_service.dart';
import 'package:gift360/features/rewards/data/rewards_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureValues = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureValues.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          final key = arguments['key'] as String?;
          switch (call.method) {
            case 'read':
              return key == null ? null : secureValues[key];
            case 'write':
              secureValues[key!] = arguments['value'] as String;
              return null;
            case 'delete':
              secureValues.remove(key);
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test(
    'claims once with a stable random UUID and returns credited amount',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://backend.example/api'));
      dio.httpClientAdapter = _RewardAdapter((request) {
        requests.add(request);
        return {
          'success': true,
          'credited': true,
          'status': 'credited',
          'amount': 5,
        };
      });
      final service = AppInstallRewardService(
        RewardsApi(dio),
        secureStorage: const FlutterSecureStorage(),
      );

      expect(await service.claimIfEligible('client-1'), 5);
      expect(await service.claimIfEligible('client-1'), 0);

      expect(requests, hasLength(1));
      expect(requests.single.path, '/v1/supercoin/first-login-reward');
      final body = requests.single.data;
      final payload = body is String ? jsonDecode(body) : body;
      expect(payload, {'deviceId': secureValues['gift360_device_id']});
      expect(
        secureValues['gift360_device_id'],
        matches(RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$')),
      );
      dio.close();
    },
  );

  test('does not show a reward for an ineligible account', () async {
    var requestCount = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.example/api'));
    dio.httpClientAdapter = _RewardAdapter((_) {
      requestCount++;
      return {'success': true, 'credited': false, 'status': 'not_eligible'};
    });
    final service = AppInstallRewardService(
      RewardsApi(dio),
      secureStorage: const FlutterSecureStorage(),
    );

    expect(await service.claimIfEligible('client-2'), 0);
    expect(await service.claimIfEligible('client-2'), 0);
    expect(requestCount, 1);
    dio.close();
  });
}

class _RewardAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions) _respond;

  _RewardAdapter(this._respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(_respond(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

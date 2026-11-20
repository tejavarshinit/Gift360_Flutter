import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gift360/features/checkout/data/repositories/checkout_api.dart';

void main() {
  group('CheckoutApi', () {
    late _CheckoutAdapter adapter;
    late Dio dio;
    late CheckoutApi api;

    setUp(() {
      adapter = _CheckoutAdapter();
      dio = Dio(BaseOptions(baseUrl: 'https://value.test/api'))
        ..httpClientAdapter = adapter;
      api = CheckoutApi(dio);
    });

    tearDown(() => dio.close(force: true));

    test(
      'requirements uses the API base, query parameters and Bearer-ready Dio',
      () async {
        adapter.response = {
          'email': {
            'mode': 'SOFT',
            'verified': false,
            'required': false,
            'prompt': true,
            'maskedEmail': 'te***@mail.com',
          },
          'location': {
            'mode': 'COLLECT',
            'ask': true,
            'skipped': false,
            'required': false,
            'maxAgeSeconds': 300,
            'pinFallback': true,
            'notice': 'Share your location.',
          },
        };

        final result = await api.getRequirements(
          orderNumber: 'ORD123',
          paymentMethod: 'UPI',
        );

        expect(adapter.lastRequest?.path, '/v1/checkout/requirements');
        expect(adapter.lastRequest?.queryParameters, {
          'orderNumber': 'ORD123',
          'paymentMethod': 'UPI',
        });
        expect(
          adapter.lastRequest?.headers.containsKey('X-Device-Id'),
          isFalse,
        );
        expect(result.email?.prompt, isTrue);
        expect(result.location?.notice, 'Share your location.');
      },
    );

    test(
      'email send puts deviceId in JSON body, not a custom header',
      () async {
        adapter.response = {'status': 'SENT', 'maskedEmail': 'te***@mail.com'};
        final result = await api.sendEmailCode(deviceId: 'install-uuid');

        expect(adapter.lastRequest?.path, '/v1/email/verification/send');
        expect(adapter.lastBody, {'deviceId': 'install-uuid'});
        expect(
          adapter.lastRequest?.headers.containsKey('X-Device-Id'),
          isFalse,
        );
        expect(result['status'], 'SENT');
      },
    );

    test(
      'send and confirm preserve server statuses returned with 4xx',
      () async {
        adapter.statusCode = 429;
        adapter.response = {'status': 'LOCKED', 'retryAfterSeconds': 1800};
        final send = await api.sendEmailCode(deviceId: 'install-uuid');
        expect(send['status'], 'LOCKED');
        expect(send['retryAfterSeconds'], 1800);

        adapter.statusCode = 422;
        adapter.response = {'status': 'WRONG_CODE', 'attemptsLeft': 3};
        final confirm = await api.confirmEmailCode(code: '123456');
        expect(adapter.lastRequest?.path, '/v1/email/verification/confirm');
        expect(adapter.lastBody, {'code': '123456'});
        expect(confirm['status'], 'WRONG_CODE');
        expect(confirm['attemptsLeft'], 3);
      },
    );

    test('registration email check posts only the email', () async {
      adapter.response = {
        'valid': true,
        'reason': 'OK',
        'suggestion': null,
        'block': false,
      };

      final result = await api.checkEmail('teja@example.com');

      expect(adapter.lastRequest?.path, '/v1/email/check');
      expect(adapter.lastBody, {'email': 'teja@example.com'});
      expect(result.valid, isTrue);
    });
  });
}

class _CheckoutAdapter implements HttpClientAdapter {
  int statusCode = 200;
  Object? response = <String, Object?>{};
  RequestOptions? lastRequest;
  Map<String, dynamic>? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (requestStream != null) {
      final bytes = await requestStream.fold<List<int>>(
        <int>[],
        (all, chunk) => all..addAll(chunk),
      );
      final text = utf8.decode(bytes);
      if (text.isNotEmpty) {
        final decoded = jsonDecode(text);
        if (decoded is Map) lastBody = decoded.cast<String, dynamic>();
      }
    }
    final bytes = utf8.encode(jsonEncode(response));
    return ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

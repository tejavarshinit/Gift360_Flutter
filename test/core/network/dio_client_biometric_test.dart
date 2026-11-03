import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/core/network/dio_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const values = {'auth_token': 'stored-token'};
  late List<RequestOptions> requests;

  setUp(() {
    requests = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'read') {
            final arguments = Map<String, dynamic>.from(call.arguments as Map);
            return values[arguments['key']];
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'authenticated request uses real secure token without replacing explicit auth',
    () async {
      final client = _client(requests);

      await client.dio.get<void>('/normal');
      await client.dio.get<void>(
        '/explicit',
        options: Options(headers: {'Authorization': 'Bearer caller-token'}),
      );
      await client.dio.get<void>(
        '/public',
        options: Options(extra: {'skipGlobalAuth': true}),
      );

      expect(requests[0].headers['Authorization'], 'Bearer stored-token');
      expect(requests[1].headers['Authorization'], 'Bearer caller-token');
      expect(requests[2].headers.containsKey('Authorization'), isFalse);
    },
  );
}

DioClient _client(List<RequestOptions> requests) {
  final client = DioClient(
    baseUrl: 'https://gateway.example',
    secureStorage: const FlutterSecureStorage(),
  );
  client.dio.httpClientAdapter = _Adapter(requests);
  return client;
}

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests;

  _Adapter(this.requests);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

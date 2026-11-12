import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/supercoin/data/repositories/supercoin_api.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';

void main() {
  test('ignores a balance search that completes after disposal', () async {
    final responseReady = Completer<void>();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = _BlockingAdapter(responseReady.future);
    final notifier = SuperCoinNotifier(
      SuperCoinApi(dio),
      '9876543210',
    );

    notifier.dispose();
    responseReady.complete();
    await Future<void>.delayed(Duration.zero);

    dio.close(force: true);
  });
}

class _BlockingAdapter implements HttpClientAdapter {
  final Future<void> _responseReady;

  _BlockingAdapter(this._responseReady);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await _responseReady;
    return ResponseBody.fromString(
      jsonEncode({'userExists': false}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/features/profile/data/models/profile_verification.dart';
import 'package:gift360/features/profile/data/repositories/profile_verification_api.dart';
import 'package:gift360/features/profile/presentation/providers/profile_verification_provider.dart';
import 'package:gift360/features/profile/presentation/widgets/verification_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('ProfileVerification', () {
    test('parses the server values without recomputing verified', () {
      final all = ProfileVerification.fromJson({
        'emailVerified': true,
        'locationVerified': true,
        'verified': true,
      });
      expect(all.emailVerified, isTrue);
      expect(all.locationVerified, isTrue);
      expect(all.verified, isTrue);

      final partial = ProfileVerification.fromJson({
        'emailVerified': true,
        'locationVerified': false,
        'verified': false,
      });
      expect(partial.verified, isFalse);
    });

    test('neutral value is null on a failed fetch', () {
      final value = profileVerificationOrNull(
        AsyncValue.error(StateError('network'), StackTrace.empty),
      );
      expect(value, isNull);
    });
  });

  group('ProfileVerificationApi', () {
    test('reads /v1/profile/verification from the API base', () async {
      final adapter = _ProfileAdapter(200, {
        'emailVerified': true,
        'locationVerified': true,
        'verified': true,
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://value.test/api'))
        ..httpClientAdapter = adapter;
      final api = ProfileVerificationApi(dio);

      final result = await api.fetch();

      expect(adapter.lastRequest?.method, 'GET');
      expect(adapter.lastRequest?.path, '/v1/profile/verification');
      expect(adapter.lastRequest?.headers.containsKey('X-Device-Id'), isFalse);
      expect(result.verified, isTrue);
      dio.close(force: true);
    });

    test('a failing endpoint throws and leaves the UI neutral', () async {
      final adapter = _ProfileAdapter(500, {'message': 'boom'});
      final dio = Dio(BaseOptions(baseUrl: 'https://value.test/api'))
        ..httpClientAdapter = adapter;
      final api = ProfileVerificationApi(dio);

      await expectLater(api.fetch(), throwsA(isA<DioException>()));
      dio.close(force: true);
    });
  });

  group('verification UI', () {
    Widget preview(ProfileVerification? verification) {
      return MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              if (verification?.verified == true) const VerifiedBadge(),
              if (verification != null) ...[
                VerificationStatusRow(
                  label: 'Email',
                  verified: verification.emailVerified,
                ),
                VerificationStatusRow(
                  label: 'Location',
                  verified: verification.locationVerified,
                ),
              ],
            ],
          ),
        ),
      );
    }

    testWidgets('verified account shows the badge and both ticks', (
      tester,
    ) async {
      await tester.pumpWidget(
        preview(
          const ProfileVerification(
            emailVerified: true,
            locationVerified: true,
            verified: true,
          ),
        ),
      );

      expect(find.byType(VerifiedBadge), findsOneWidget);
      expect(find.text('Verified'), findsNWidgets(3));
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
      expect(find.text('Not verified'), findsNothing);
    });

    testWidgets('unverified account shows no badge and grey rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        preview(
          const ProfileVerification(
            emailVerified: false,
            locationVerified: false,
            verified: false,
          ),
        ),
      );

      expect(find.byType(VerifiedBadge), findsNothing);
      expect(find.text('Not verified'), findsNWidgets(2));
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));
    });

    testWidgets('API failure renders nothing extra and does not crash', (
      tester,
    ) async {
      final neutral = profileVerificationOrNull(
        AsyncValue.error(StateError('network'), StackTrace.empty),
      );
      await tester.pumpWidget(preview(neutral));

      expect(find.byType(VerifiedBadge), findsNothing);
      expect(find.text('Not verified'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

class _ProfileAdapter implements HttpClientAdapter {
  final int statusCode;
  final Object body;
  RequestOptions? lastRequest;

  _ProfileAdapter(this.statusCode, this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

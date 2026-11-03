import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/auth/data/models/biometric_models.dart';
import 'package:gift360/features/auth/data/repositories/biometric_api.dart';
import 'package:gift360/features/auth/data/repositories/biometric_key_store.dart';
import 'package:gift360/features/auth/data/repositories/biometric_service.dart';

void main() {
  const challengeText = 'signed exactly: café\nline 2';

  test(
    'registration persists enabled state only after gateway success',
    () async {
      final adapter = _GatewayAdapter((_) => {'success': true});
      final storage = _MemoryBiometricStorage();
      final keys = _FakeKeyStore()..keyExists = false;
      final service = _service(adapter, storage, keys);

      await service.enable(clientId: 'client-1', token: 'auth-token');

      expect(keys.createCount, 1);
      expect(storage.values['biometric_login_enabled'], 'true');
      expect(storage.values['biometric_login_client_id'], 'client-1');
      final register = adapter.requests.single;
      expect(register.path, '/api/v1/auth/biometric/register');
      expect(register.data['uniqueId'], 'client-1');
      expect(register.headers['Authorization'], 'Bearer auth-token');
    },
  );

  test(
    'failed registration deletes the unregistered key and metadata',
    () async {
      final adapter = _GatewayAdapter((_) => {'success': false});
      final storage = _MemoryBiometricStorage();
      final keys = _FakeKeyStore()..keyExists = false;
      final service = _service(adapter, storage, keys);

      await expectLater(
        service.enable(clientId: 'client-1', token: 'auth-token'),
        throwsA(isA<BiometricException>()),
      );

      expect(keys.deleteCount, 1);
      expect(storage.values, isEmpty);
      expect(adapter.requests.map((request) => request.path), [
        '/api/v1/auth/biometric/register',
      ]);
    },
  );

  test('signs the exact challenge string before submitting login', () async {
    final adapter = _GatewayAdapter((request) {
      if (request.path.endsWith('/challenge')) {
        return {
          'success': true,
          'challengeId': 'challenge-1',
          'challenge': challengeText,
          'expiresIn': 60,
        };
      }
      return {
        'success': true,
        'token': 'new-token',
        'userInfo': {'clientId': 'client-1', 'name': 'User'},
      };
    });
    final storage = _enrolledStorage();
    final keys = _FakeKeyStore();
    final result = await _service(adapter, storage, keys).login();

    expect(keys.signedChallenge, challengeText);
    expect(result.token, 'new-token');
    expect(result.clientId, 'client-1');
    final login = adapter.requests.last;
    expect(login.data, {
      'challengeId': 'challenge-1',
      'deviceId': 'device-1',
      'signature': 'signature-base64',
    });
    expect(login.extra['skipGlobalAuth'], isTrue);
  });

  test('expired challenge is rejected before prompting for signing', () async {
    final adapter = _GatewayAdapter(
      (_) => {
        'success': true,
        'challengeId': 'challenge-1',
        'challenge': challengeText,
        'expiresIn': 1,
      },
    );
    var clockCalls = 0;
    final start = DateTime.utc(2025);
    final service = _service(
      adapter,
      _enrolledStorage(),
      _FakeKeyStore(),
      now: () => start.add(Duration(seconds: clockCalls++ * 2)),
    );

    await expectLater(service.login(), throwsA(isA<BiometricException>()));
    expect(adapter.requests, hasLength(1));
  });

  test(
    'prompt cancellation prevents submission of the login request',
    () async {
      final adapter = _GatewayAdapter(
        (_) => {
          'success': true,
          'challengeId': 'challenge-1',
          'challenge': challengeText,
          'expiresIn': 60,
        },
      );
      final keys = _FakeKeyStore()
        ..signError = const BiometricException(
          'Biometric authentication was cancelled.',
        );
      final service = _service(adapter, _enrolledStorage(), keys);

      await expectLater(service.login(), throwsA(isA<BiometricException>()));
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, endsWith('/challenge'));
    },
  );

  test('biometric login rejects a different backend account', () async {
    final adapter = _GatewayAdapter((request) {
      if (request.path.endsWith('/challenge')) {
        return {
          'success': true,
          'challengeId': 'challenge-1',
          'challenge': challengeText,
          'expiresIn': 60,
        };
      }
      return {
        'success': true,
        'token': 'other-account-token',
        'userInfo': {'clientId': 'client-2'},
      };
    });

    await expectLater(
      _service(adapter, _enrolledStorage(), _FakeKeyStore()).login(),
      throwsA(isA<BiometricException>()),
    );
    expect(adapter.requests.last.path, endsWith('/login'));
  });

  test('unsupported biometric hardware blocks enrollment', () async {
    final adapter = _GatewayAdapter((_) => {'success': true});
    final keys = _FakeKeyStore()
      ..available = const BiometricAvailability(
        supported: false,
        enrolled: false,
        reason: 'Unsupported hardware',
      );
    final service = _service(adapter, _MemoryBiometricStorage(), keys);

    await expectLater(
      service.enable(clientId: 'client-1', token: 'auth-token'),
      throwsA(isA<BiometricException>()),
    );
    expect(keys.createCount, 0);
    expect(adapter.requests, isEmpty);
  });

  test('local enrollment remains if gateway revoke fails', () async {
    final adapter = _GatewayAdapter((_) => {'success': false});
    final storage = _enrolledStorage();
    final keys = _FakeKeyStore()..keyExists = false;
    final service = _service(adapter, storage, keys);

    await expectLater(
      service.disable(clientId: 'client-1', token: 'auth-token'),
      throwsA(isA<BiometricException>()),
    );

    expect(storage.values['biometric_login_enabled'], 'true');
    expect(keys.deleteCount, 0);
  });

  test('successful revoke removes local key and enrollment state', () async {
    final adapter = _GatewayAdapter((_) => {'success': true});
    final storage = _enrolledStorage();
    final keys = _FakeKeyStore();
    final service = _service(adapter, storage, keys);

    await service.disable(clientId: 'client-1', token: 'auth-token');

    expect(keys.deleteCount, 1);
    expect(storage.values, isEmpty);
  });

  test(
    'storage failure after register attempts backend revoke and key cleanup',
    () async {
      final adapter = _GatewayAdapter((_) => {'success': true});
      final storage = _MemoryBiometricStorage()..failEnabledWrite = true;
      final keys = _FakeKeyStore()..keyExists = false;
      final service = _service(adapter, storage, keys);

      await expectLater(
        service.enable(clientId: 'client-1', token: 'auth-token'),
        throwsA(isA<StateError>()),
      );

      expect(adapter.requests.map((request) => request.path), [
        '/api/v1/auth/biometric/register',
        '/api/v1/auth/biometric/revoke',
      ]);
      expect(keys.deleteCount, 1);
      expect(storage.values, isEmpty);
    },
  );
}

BiometricService _service(
  _GatewayAdapter adapter,
  _MemoryBiometricStorage storage,
  _FakeKeyStore keys, {
  DateTime Function()? now,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://gateway.example'));
  dio.httpClientAdapter = adapter;
  return BiometricService(
    api: BiometricApi(dio),
    keyStore: keys,
    storage: storage,
    now: now,
    newDeviceId: () => 'device-1',
  );
}

_MemoryBiometricStorage _enrolledStorage() =>
    _MemoryBiometricStorage()
      ..values.addAll({
        'biometric_login_enabled': 'true',
        'biometric_login_device_id': 'device-1',
        'biometric_login_client_id': 'client-1',
      });

class _MemoryBiometricStorage implements BiometricStorage {
  final Map<String, String> values = {};
  bool failEnabledWrite = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failEnabledWrite && key == 'biometric_login_enabled') {
      throw StateError('secure storage write failed');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _FakeKeyStore implements BiometricKeyStore {
  int createCount = 0;
  int deleteCount = 0;
  bool keyExists = true;
  String? signedChallenge;
  Object? signError;
  BiometricAvailability available = const BiometricAvailability(
    supported: true,
    enrolled: true,
  );

  @override
  Future<BiometricAvailability> availability() async => available;

  @override
  Future<bool> hasKey() async => keyExists;

  @override
  Future<String> createKeyPair() async {
    createCount++;
    keyExists = true;
    return 'public-key-base64';
  }

  @override
  Future<String> signChallenge(String challenge) async {
    signedChallenge = challenge;
    if (signError case final error?) throw error;
    return 'signature-base64';
  }

  @override
  Future<void> deleteKey() async {
    deleteCount++;
    keyExists = false;
  }
}

class _GatewayAdapter implements HttpClientAdapter {
  final Map<String, Object?> Function(RequestOptions) _respond;
  final List<RequestOptions> requests = [];

  _GatewayAdapter(this._respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

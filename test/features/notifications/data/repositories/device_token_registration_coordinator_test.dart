import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/notifications/data/repositories/device_token_api.dart';

void main() {
  group('DeviceTokenRegistrationCoordinator', () {
    test(
      'does not register until an authenticated client ID is available',
      () async {
        final registrations = <String>[];
        final coordinator = DeviceTokenRegistrationCoordinator((
          token,
          clientId,
        ) async {
          registrations.add('$clientId:$token');
        });

        await coordinator.register('token-1', 'client-A');
        expect(registrations, isEmpty);

        coordinator.setClientId('client-A');
        await coordinator.register('token-1', 'client-A');
        expect(registrations, ['client-A:token-1']);
      },
    );

    test(
      'deduplicates success but registers refreshed tokens and new accounts',
      () async {
        final registrations = <String>[];
        final coordinator = DeviceTokenRegistrationCoordinator((
          token,
          clientId,
        ) async {
          registrations.add('$clientId:$token');
        });
        coordinator.setClientId('client-A');

        await coordinator.register('token-1', 'client-A');
        await coordinator.register('token-1', 'client-A');
        await coordinator.register('token-2', 'client-A');
        coordinator.setClientId('client-B');
        await coordinator.register('token-2', 'client-B');

        expect(registrations, [
          'client-A:token-1',
          'client-A:token-2',
          'client-B:token-2',
        ]);
      },
    );

    test('permits retry after a failed backend registration', () async {
      var attempts = 0;
      final coordinator = DeviceTokenRegistrationCoordinator((_, _) async {
        attempts++;
        if (attempts == 1) throw StateError('temporary failure');
      })..setClientId('client-A');

      await expectLater(
        coordinator.register('token-1', 'client-A'),
        throwsA(isA<StateError>()),
      );
      await coordinator.register('token-1', 'client-A');

      expect(attempts, 2);
    });

    test(
      'serializes an account switch behind an in-flight registration',
      () async {
        final started = Completer<void>();
        final finishOldRequest = Completer<void>();
        final completed = <String>[];
        final coordinator = DeviceTokenRegistrationCoordinator((
          token,
          clientId,
        ) async {
          if (!started.isCompleted) started.complete();
          if (clientId == 'client-A') await finishOldRequest.future;
          completed.add('$clientId:$token');
        });

        coordinator.setClientId('client-A');
        final oldRegistration = coordinator.register('token', 'client-A');
        await started.future;

        coordinator.setClientId('client-B');
        final newRegistration = coordinator.register('token', 'client-B');
        finishOldRequest.complete();
        await Future.wait([oldRegistration, newRegistration]);

        expect(completed, ['client-A:token', 'client-B:token']);
      },
    );
  });
}

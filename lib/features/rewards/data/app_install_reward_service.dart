import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gift360/features/rewards/data/rewards_api.dart';

class AppInstallRewardService {
  static const _deviceIdKey = 'gift360_device_id';
  static const _donePrefix = 'app_install_reward_done_';
  static const _deviceChannel = MethodChannel('gift360/device_id');
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final RewardsApi _api;
  final FlutterSecureStorage _secureStorage;
  final Set<String> _inFlightClients = {};

  AppInstallRewardService(this._api, {FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Returns the awarded coin count, or zero when no reward was credited.
  Future<int> claimIfEligible(String clientId) async {
    if (kIsWeb) return 0;
    final id = clientId.trim();
    if (id.isEmpty || !_inFlightClients.add(id)) return 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('$_donePrefix$id') == true) return 0;

      final result = await _api.claimFirstLoginReward(
        deviceId: await _deviceId(),
      );
      final status = (result['status'] ?? '').toString().toLowerCase();
      final terminalStatuses = {
        'credited',
        'already_awarded',
        'not_eligible',
        'pending',
      };
      if (result['success'] == true && terminalStatuses.contains(status)) {
        try {
          await prefs.setBool('$_donePrefix$id', true);
        } catch (error) {
          debugPrint(
            '[AppInstallReward] Could not persist completion (${error.runtimeType}).',
          );
        }
      }

      if (result['success'] != true ||
          status != 'credited' ||
          result['credited'] != true) {
        return 0;
      }

      final amount = result['amount'];
      return amount is num && amount > 0 ? amount.round() : 5;
    } catch (error) {
      debugPrint('[AppInstallReward] Claim failed (${error.runtimeType}).');
      return 0;
    } finally {
      _inFlightClients.remove(id);
    }
  }

  Future<String> _deviceId() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final androidId = await _deviceChannel.invokeMethod<String>(
          'getAndroidId',
        );
        if (androidId != null && androidId.trim().isNotEmpty) {
          return _uuidFromHash(
            'gift360:android:${androidId.trim().toLowerCase()}',
          );
        }
      } catch (error) {
        debugPrint(
          '[AppInstallReward] Android ID unavailable (${error.runtimeType}).',
        );
      }
    }

    return _storedRandomId();
  }

  String _uuidFromHash(String name) {
    final bytes = sha1.convert(utf8.encode(name)).bytes.sublist(0, 16);
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return _formatUuid(bytes);
  }

  Future<String> _storedRandomId() async {
    final existing = await _secureStorage.read(key: _deviceIdKey);
    if (existing != null && _uuidPattern.hasMatch(existing)) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final deviceId =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _secureStorage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  String _formatUuid(List<int> bytes) {
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

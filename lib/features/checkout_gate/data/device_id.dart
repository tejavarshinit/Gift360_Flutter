import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const _deviceIdKey = 'gift360_checkout_device_id';

/// Random per-install ID (not a fingerprint). Sent as `X-Device-Id`.
Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_deviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final id = _randomId();
  await prefs.setString(_deviceIdKey, id);
  return id;
}

String _randomId() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

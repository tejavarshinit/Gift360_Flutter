import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';

/// SuperCoins the given lines will earn, from the backend
/// (POST /v1/supercoin/earn-estimate). Ported from React
/// `useSuperCoinEarnEstimate`: debounced ~350ms and null (hide the line) on
/// failure.
///
/// The family key encodes everything needed, so the provider stays pure and
/// works for both the cart and the quick-buy sheet:
///   `cash|brandId:lineTotal,brandId:lineTotal,...`
final superCoinEarnEstimateProvider =
    FutureProvider.autoDispose.family<double?, String>((ref, key) async {
  final parts = key.split('|');
  final cashPayable = double.tryParse(parts.isNotEmpty ? parts.first : '') ?? 0;

  final items = <Map<String, dynamic>>[];
  if (parts.length > 1) {
    for (final entry in parts.sublist(1).join('|').split(',')) {
      final bits = entry.split(':');
      if (bits.length < 2) continue;
      final lineTotal = double.tryParse(bits[1]) ?? 0;
      if (bits[0].isEmpty || lineTotal <= 0) continue;
      items.add({'brandId': bits[0], 'lineTotal': lineTotal});
    }
  }
  if (cashPayable <= 0 || items.isEmpty) return null;

  final api = ref.watch(supercoinApiProvider);
  var cancelled = false;
  ref.onDispose(() => cancelled = true);
  await Future<void>.delayed(const Duration(milliseconds: 350));
  if (cancelled) return null;

  try {
    final response = await api.earnEstimate(items, cashPayable);
    if (cancelled) return null;
    final coins = response['coins'];
    if (coins is num) return coins.toDouble();
    return double.tryParse((coins ?? '').toString());
  } catch (_) {
    return null;
  }
});

/// Build the stable cache key used by [superCoinEarnEstimateProvider].
String superCoinEarnKey(List<MapEntry<String, double>> lines, double cashPayable) {
  final signature = lines.map((e) => '${e.key}:${e.value}').join(',');
  return '${cashPayable.toStringAsFixed(2)}|$signature';
}

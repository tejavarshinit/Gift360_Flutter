import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/guard_rails/data/repositories/guard_rails_api.dart';

final guardRailsApiProvider = Provider<GuardRailsApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return GuardRailsApi(dio);
});

/// Guard rail status for a specific brand.
class GuardRailStatus {
  final bool hasGuardRail;
  final double monthlyLimit;
  final double currentUsage;
  final double remaining;

  const GuardRailStatus({
    this.hasGuardRail = false,
    this.monthlyLimit = 0,
    this.currentUsage = 0,
    this.remaining = 0,
  });
}

/// Fetches guard rail config and client usage for a specific brand.
/// Matches React's useBrandGuardRail hook logic.
final brandGuardRailProvider =
    FutureProvider.family<GuardRailStatus, String>((ref, brandId) async {
  final api = ref.watch(guardRailsApiProvider);
  final user = ref.watch(authProvider);
  if (user == null) return const GuardRailStatus();

  try {
    // Step 1: Get all guard rail configs
    final brands = await api.getBrands();

    // Step 2: Find matching brand by ID (case-insensitive, contains matching)
    final matched = brands.firstWhere(
      (b) {
        final railBrandId = (b['brandId'] ?? b['brand_id'] ?? '').toString();
        final railBrandCode = (b['brandCode'] ?? b['brand_code'] ?? '').toString();
        return railBrandId.toLowerCase() == brandId.toLowerCase() ||
            railBrandCode.toLowerCase() == brandId.toLowerCase();
      },
      orElse: () => {},
    );

    if (matched.isEmpty) return const GuardRailStatus();

    final monthlyLimit = (matched['monthlyLimit'] ?? matched['monthly_limit'] ?? 0).toDouble();

    // Step 3: Get current month's usage
    final usageResponse = await api.getClientUsage({
      'clientId': user.clientId,
      'brandId': brandId,
    });

    final currentUsage = (usageResponse['currentUsage'] ??
            usageResponse['current_usage'] ??
            usageResponse['totalUsage'] ??
            0)
        .toDouble();

    return GuardRailStatus(
      hasGuardRail: true,
      monthlyLimit: monthlyLimit,
      currentUsage: currentUsage,
      remaining: (monthlyLimit - currentUsage).clamp(0, monthlyLimit),
    );
  } catch (_) {
    return const GuardRailStatus();
  }
});

/// Check if adding an amount would exceed the guard rail limit.
bool wouldExceedGuardRail(GuardRailStatus status, double currentCartTotal, double addAmount) {
  if (!status.hasGuardRail) return false;
  return (status.currentUsage + currentCartTotal + addAmount) > status.monthlyLimit;
}

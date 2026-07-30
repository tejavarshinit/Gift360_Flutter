import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/home/data/repositories/recently_used_api.dart';

final recentlyUsedApiProvider = Provider<RecentlyUsedApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return RecentlyUsedApi(dio);
});

final recentlyUsedProvider = FutureProvider.autoDispose<List<RecentlyUsedBrand>?>((ref) async {
  final user = ref.watch(authProvider);
  final clientId = user?.clientId;
  if (clientId == null || clientId.isEmpty) return [];

  final api = ref.watch(recentlyUsedApiProvider);
  try {
    return await api.fetchRecentlyUsed(clientId: clientId, timeline: 12);
  } catch (_) {
    return [];
  }
});

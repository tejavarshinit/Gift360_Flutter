import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gift360/features/festival/data/festival_api.dart';
import 'package:gift360/features/festival/data/models/festival_config.dart';

final festivalApiProvider = Provider<FestivalApi>((ref) {
  return FestivalApi(Dio());
});

/// Active festival theme for the app. Uses remote config when the endpoint
/// responds; otherwise ships Diwali defaults so UI stays stable.
final festivalConfigProvider = FutureProvider<FestivalConfig>((ref) async {
  final remote = await ref.watch(festivalApiProvider).fetchActive();
  if (remote != null) return remote.effective;
  return FestivalConfig.defaults.effective;
});

/// Sync helper for widgets that need a non-async value during build.
FestivalConfig festivalConfigOf(WidgetRef ref) {
  return ref.watch(festivalConfigProvider).valueOrNull ??
      FestivalConfig.defaults.effective;
}

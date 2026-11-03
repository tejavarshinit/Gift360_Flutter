import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/rewards/data/rewards_api.dart';

final rewardsApiProvider = Provider<RewardsApi>((ref) {
  return RewardsApi(ref.watch(brandsDioProvider));
});

/// Latest quiz/reward status for the signed-in customer (null when logged out
/// or unavailable). Mirrors React `getRewardStatus`.
final rewardStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null || user.clientId.isEmpty) return null;
  try {
    return await ref.watch(rewardsApiProvider).getStatus(user.clientId);
  } catch (_) {
    return null;
  }
});

/// Live SuperCoin rules used to fill FAQ answers (null when unavailable).
final scFactsProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return ref.watch(rewardsApiProvider).scFacts();
});

class QuizQuestion {
  final int id;
  final String question;
  final List<String> options;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: (json['question'] ?? '').toString(),
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

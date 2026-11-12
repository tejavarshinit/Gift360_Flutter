import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/rewards/data/rewards_api.dart';

final rewardsApiProvider = Provider<RewardsApi>((ref) {
  return RewardsApi(ref.watch(brandsDioProvider));
});

/// Retained for the existing quiz UI, but status is now kept local because the
/// backend does not expose a rewards/status endpoint.
final rewardStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) async {
  return null;
});

/// Live SuperCoin rules used to fill FAQ answers (null when unavailable).
final scFactsProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) async {
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
      options:
          (json['options'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}

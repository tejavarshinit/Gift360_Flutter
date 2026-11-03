import 'package:dio/dio.dart';

/// Contextual micro-feedback (right-edge Yes/No questions).
/// Ported from React `api/microFeedbackApi.ts`.
class MicroFeedbackApi {
  final Dio _dio;

  MicroFeedbackApi(this._dio);

  /// Question definitions seeded in the feedback table.
  Future<List<Map<String, dynamic>>> getQuestions() async {
    final response = await _dio.get('/v1/micro-feedback/questions');
    final data = (response.data as Map).cast<String, dynamic>();
    final list = (data['questions'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  /// Question keys the client already answered.
  Future<List<String>> getAnsweredKeys(String clientId) async {
    final response = await _dio.get(
      '/v1/micro-feedback/answered',
      queryParameters: {'clientId': clientId},
    );
    final data = (response.data as Map).cast<String, dynamic>();
    final keys = (data['keys'] as List?) ?? const [];
    return keys.map((e) => e.toString()).toList();
  }

  /// Records a Yes/No micro-feedback answer (upsert on client+question).
  Future<void> submit({
    required String clientId,
    required String questionKey,
    required String page,
    required String answer,
    String? question,
  }) async {
    await _dio.post('/v1/micro-feedback', data: {
      'clientId': clientId,
      'questionKey': questionKey,
      'page': page,
      'answer': answer,
      if (question != null && question.isNotEmpty) 'question': question,
    });
  }
}

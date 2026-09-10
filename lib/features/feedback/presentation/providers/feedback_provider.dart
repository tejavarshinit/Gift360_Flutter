import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/feedback/data/repositories/feedback_api.dart';

final feedbackApiProvider = Provider<FeedbackApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return FeedbackApi(dio);
});

class FeedbackState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;

  const FeedbackState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
  });

  FeedbackState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    bool clearError = false,
  }) {
    return FeedbackState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class FeedbackNotifier extends StateNotifier<FeedbackState> {
  final FeedbackApi _api;

  FeedbackNotifier(this._api) : super(const FeedbackState());

  Future<bool> submitFeedback({
    int? speed,
    String? usability,
    String? payment,
    int? overall,
    int? nps,
    String? locationShare,
    String? userLocation,
    String? gender,
    String? occupation,
    String? brandBought,
    String? hasSuggestion,
    String? suggestion,
    String? clientId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.submitFeedback({
        if (speed != null) 'speed': speed,
        if (usability != null) 'usability': usability,
        if (payment != null) 'payment': payment,
        if (overall != null) 'overall': overall,
        if (nps != null) 'nps': nps,
        if (locationShare != null) 'locationShare': locationShare,
        if (userLocation != null) 'userLocation': userLocation,
        if (gender != null) 'gender': gender,
        if (occupation != null) 'occupation': occupation,
        if (brandBought != null) 'brandBought': brandBought,
        if (hasSuggestion != null) 'hasSuggestion': hasSuggestion,
        if (suggestion != null) 'suggestion': suggestion,
        if (clientId != null) 'clientId': clientId,
      });
      state = state.copyWith(isLoading: false, isSuccess: true);
      // Track feedback submission to prevent re-prompting (matches React localStorage)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('g360_feedback_submitted', true);
      } catch (_) {}
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void reset() {
    state = const FeedbackState();
  }

  /// Check if user has already submitted feedback (matches React localStorage check).
  static Future<bool> hasSubmittedFeedback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('g360_feedback_submitted') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check if user has been prompted for feedback (matches React localStorage check).
  static Future<bool> hasBeenPrompted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('g360_feedback_prompted') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mark user as prompted for feedback.
  static Future<void> markPrompted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('g360_feedback_prompted', true);
    } catch (_) {}
  }
}

final feedbackProvider = StateNotifierProvider<FeedbackNotifier, FeedbackState>((ref) {
  return FeedbackNotifier(ref.watch(feedbackApiProvider));
});

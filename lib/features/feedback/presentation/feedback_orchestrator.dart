import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/feedback/presentation/providers/feedback_provider.dart';
import 'package:gift360/features/feedback/presentation/widgets/feedback_form.dart';

/// Global owner of the automatic feedback form prompt (voucher-fetched and
/// payment-cancelled only). Ported from React `FeedbackOrchestrator.tsx`.
///
/// Whether the customer already submitted is decided by the backend
/// (`GET /v1/feedback/status`); the local flag is only a stale-cache fallback
/// when the status call fails.
class FeedbackOrchestrator {
  FeedbackOrchestrator._();

  static const _cooldownKey = 'gift360_fb_trigger_last';
  static const _cooldownMs = <String, int>{
    'voucher-fetched': 24 * 60 * 60 * 1000,
    'payment-cancelled': 2 * 60 * 60 * 1000,
  };

  /// Never pop the form on pages where a survey would be noise.
  static const _blockedPaths = [
    '/admin',
    '/onboarding',
    '/login',
    '/register',
    '/forgot-password',
    '/reset-password',
  ];

  static bool _open = false;
  static bool? _submitted;
  static String? _submittedClientId;

  static Future<void> prompt(
    BuildContext context,
    WidgetRef ref,
    String trigger,
  ) async {
    if (_open) return;
    if (!_cooldownMs.containsKey(trigger)) return;
    if (_isBlocked(context)) return;

    final clientId = ref.read(authProvider)?.clientId ?? '';
    if (clientId.isEmpty) return;

    // Only prompt once the backend has confirmed this customer never submitted.
    if (await _resolveSubmitted(ref, clientId)) return;
    if (await _inCooldown(trigger, clientId)) return;
    if (!context.mounted) return;

    await _stamp(trigger, clientId);
    if (!context.mounted) return;
    _open = true;
    try {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: const FeedbackForm(),
        ),
      );
    } finally {
      _open = false;
    }

    // The form may have been submitted; re-read status next time.
    _submitted = null;
  }

  static bool _isBlocked(BuildContext context) {
    String path = '/';
    try {
      path = GoRouterState.of(context).matchedLocation;
    } catch (_) {}
    return _blockedPaths.any((p) => path == p || path.startsWith('$p/'));
  }

  static Future<bool> _resolveSubmitted(WidgetRef ref, String clientId) async {
    if (_submittedClientId == clientId && _submitted != null) {
      return _submitted!;
    }
    bool submitted = await FeedbackNotifier.hasSubmittedFeedback();
    try {
      final res = await ref.read(feedbackApiProvider).getStatus(clientId);
      submitted = res['submitted'] == true;
    } catch (_) {
      // Keep the local fallback when the status call fails.
    }
    _submitted = submitted;
    _submittedClientId = clientId;
    return submitted;
  }

  static Future<Map<String, dynamic>> _readCooldowns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cooldownKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return {};
  }

  static String _key(String trigger, String clientId) => '$trigger:$clientId';

  static Future<bool> _inCooldown(String trigger, String clientId) async {
    final all = await _readCooldowns();
    final last = (all[_key(trigger, clientId)] as num?)?.toInt() ?? 0;
    return DateTime.now().millisecondsSinceEpoch - last <
        (_cooldownMs[trigger] ?? 0);
  }

  static Future<void> _stamp(String trigger, String clientId) async {
    try {
      final all = await _readCooldowns();
      all[_key(trigger, clientId)] =
          DateTime.now().millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cooldownKey, jsonEncode(all));
    } catch (_) {}
  }
}

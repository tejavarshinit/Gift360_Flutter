import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gift360/core/navigation/location_tracker.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/feedback/presentation/providers/feedback_provider.dart';

class _MicroQuestion {
  final String key;
  final String text;
  final List<String> pages;

  /// Yes navigates to this route.
  final String? href;

  /// Yes opens the Rewards (quiz) entry point.
  final bool reward;

  const _MicroQuestion({
    required this.key,
    required this.text,
    required this.pages,
    this.href,
    this.reward = false,
  });
}

/// Fallback list (used when the questions API is unreachable). The canonical
/// question definitions live in the `feedback` table and are fetched on mount.
const List<_MicroQuestion> _fallbackQuestions = [
  _MicroQuestion(key: 'home_nearby_offers', pages: ['home'], text: 'Are nearby offers useful to you?'),
  _MicroQuestion(key: 'home_more_cities', pages: ['home'], text: 'Want offers in more cities?'),
  _MicroQuestion(key: 'home_corporate', pages: ['home'], text: 'Interested in corporate bulk gifting?', href: '/distributor'),
  _MicroQuestion(key: 'brands_more', pages: ['brands'], text: 'Looking for more brands?'),
  _MicroQuestion(key: 'brands_office', pages: ['brands'], text: 'Are you looking for office-related vouchers?'),
  _MicroQuestion(key: 'cart_discount', pages: ['cart'], text: 'Looking for more discount?'),
  _MicroQuestion(key: 'purchase_supercoin', pages: ['cart', 'brands'], text: 'Want to make a purchase and get a chance to earn SuperCoins?', reward: true),
  _MicroQuestion(key: 'cart_supercoin_plan', pages: ['cart'], text: 'Planning to use SuperCoins soon?', reward: true),
  _MicroQuestion(key: 'orders_redeem', pages: ['orders'], text: 'Ready to redeem your voucher?'),
  _MicroQuestion(key: 'orders_help', pages: ['orders'], text: 'Need help with an order?'),
  _MicroQuestion(key: 'profile_happy', pages: ['profile'], text: 'Happy with your Gift360 experience so far?'),
];

/// Client-side routing behaviour per question key (targets don't live in the DB).
const Map<String, Map<String, dynamic>> _routeOverrides = {
  'home_corporate': {'href': '/distributor'},
  'purchase_supercoin': {'pages': ['cart', 'brands'], 'reward': true},
  'cart_supercoin_plan': {'reward': true},
};

const List<String> _blockedPaths = [
  '/admin',
  '/onboarding',
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
];

const int _showMs = 15000;
const int _hideMs = 20000;
const int _firstDelayMs = 4000;

String? _pageForPath(String path) {
  if (path == '/' || path == '/home') return 'home';
  if (path.startsWith('/brands') || path.startsWith('/categories')) {
    return 'brands';
  }
  if (path.startsWith('/cart')) return 'cart';
  if (path.startsWith('/orders') || path.startsWith('/my-orders')) {
    return 'orders';
  }
  if (path.startsWith('/profile')) return 'profile';
  return null;
}

bool _isBlocked(String path) =>
    _blockedPaths.any((p) => path == p || path.startsWith('$p/'));

/// Collapsible right-edge micro-feedback widget. Cycles small Yes/No questions
/// for the current page (15s shown, ~20s gap), stores answers in the backend,
/// and never blocks the user's journey. Ported from React
/// `MicroQuestionWidget.tsx`.
class MicroQuestionWidget extends ConsumerStatefulWidget {
  const MicroQuestionWidget({super.key});

  @override
  ConsumerState<MicroQuestionWidget> createState() =>
      _MicroQuestionWidgetState();
}

class _MicroQuestionWidgetState extends ConsumerState<MicroQuestionWidget> {
  List<_MicroQuestion> _source = _fallbackQuestions;
  final Set<String> _answered = {};
  String? _answeredFor;
  String _location = appLocation.value;

  _MicroQuestion? _question;
  bool _visible = false;
  bool _thanks = false;
  int _idx = 0;
  bool _busy = false;
  Timer? _timer;
  String? _startedFor;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    appLocation.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    appLocation.removeListener(_onLocationChanged);
    _timer?.cancel();
    super.dispose();
  }

  /// The shell rebuilds on tab switches; GoRouterState reflects the current
  /// branch location, while [appLocation] covers root navigator changes.
  void _syncLocation(BuildContext context) {
    var location = appLocation.value;
    try {
      final path = GoRouterState.of(context).uri.path;
      if (path.isNotEmpty) location = path;
    } catch (_) {}
    if (location != _location) {
      _location = location;
    }
  }

  void _onLocationChanged() {
    if (!mounted || appLocation.value == _location) return;
    setState(() => _location = appLocation.value);
  }

  Future<void> _loadQuestions() async {
    try {
      final rows = await ref.read(microFeedbackApiProvider).getQuestions();
      final qs = <_MicroQuestion>[];
      for (final q in rows) {
        final key = (q['key'] ?? '').toString();
        final text = (q['text'] ?? '').toString();
        if (key.isEmpty || text.isEmpty) continue;
        final override = _routeOverrides[key];
        final pages = (override?['pages'] as List?)?.cast<String>() ??
            (q['page'] != null ? [q['page'].toString()] : const <String>[]);
        qs.add(_MicroQuestion(
          key: key,
          text: text,
          pages: pages,
          href: override?['href'] as String?,
          reward: override?['reward'] as bool? ?? false,
        ));
      }
      if (mounted && qs.isNotEmpty) {
        setState(() => _source = qs);
      }
    } catch (_) {
      // Keep the fallback list.
    }
  }

  Future<void> _loadAnswered(String clientId) async {
    if (_answeredFor == clientId) return;
    _answeredFor = clientId;
    try {
      final keys = await ref.read(microFeedbackApiProvider).getAnsweredKeys(clientId);
      if (!mounted || _answeredFor != clientId) return;
      setState(() {
        _answered
          ..clear()
          ..addAll(keys);
      });
    } catch (_) {
      // Offline: cycle everything locally.
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncLocation(context);
    final clientId = ref.watch(authProvider)?.clientId ?? '';
    final page = _pageForPath(_location);
    final blocked = _isBlocked(_location);

    if (clientId.isNotEmpty) {
      _loadAnswered(clientId);
    }

    final pool = <_MicroQuestion>[];
    if (!blocked && page != null) {
      pool.addAll(_source.where(
        (q) => q.pages.contains(page) && !_answered.contains(q.key),
      ));
    }

    final poolKey = pool.map((q) => q.key).join(',');
    final signature = '$clientId|$page|$poolKey';

    if (clientId.isEmpty || blocked || pool.isEmpty) {
      _stop();
    } else if (_startedFor != signature) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final stillValid =
            _startedFor != signature && clientId.isNotEmpty && pool.isNotEmpty;
        if (stillValid) {
          _startedFor = signature;
          _startCycle(pool);
        }
      });
    }

    if (_visible && _question != null) {
      return _buildExpandedCard(context, pool);
    }
    if (clientId.isNotEmpty && !blocked && pool.isNotEmpty) {
      return _buildCollapsedPill(context, pool);
    }
    return const SizedBox.shrink();
  }

  void _stop() {
    if (_startedFor == null && _timer == null && !_visible) return;
    _timer?.cancel();
    _timer = null;
    _startedFor = null;
    if (_visible || _question != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _visible = false;
          _question = null;
          _thanks = false;
        });
      });
    }
  }

  void _startCycle(List<_MicroQuestion> pool) {
    _timer?.cancel();
    setState(() {
      _visible = false;
      _question = null;
      _thanks = false;
    });

    late void Function() show;

    void hide() {
      if (!mounted) return;
      setState(() {
        _visible = false;
        _question = null;
      });
      _timer = Timer(const Duration(milliseconds: _hideMs), show);
    }

    show = () {
      if (!mounted || pool.isEmpty) return;
      final q = pool[_idx % pool.length];
      _idx++;
      setState(() {
        _thanks = false;
        _question = q;
        _visible = true;
      });
      _timer = Timer(const Duration(milliseconds: _showMs), hide);
    };

    _timer = Timer(const Duration(milliseconds: _firstDelayMs), show);
  }

  void _collapse() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _visible = false;
      _question = null;
      _thanks = false;
    });
    _startedFor = null;
  }

  void _expand(List<_MicroQuestion> pool) {
    _timer?.cancel();
    if (pool.isEmpty) return;
    final q = pool[_idx % pool.length];
    _idx++;
    setState(() {
      _thanks = false;
      _question = q;
      _visible = true;
    });
    _timer = Timer(const Duration(milliseconds: _showMs), () {
      if (!mounted) return;
      setState(() {
        _visible = false;
        _question = null;
      });
      _startedFor = null;
    });
  }

  Future<void> _answer(String value) async {
    final q = _question;
    final clientId = ref.read(authProvider)?.clientId ?? '';
    if (q == null || clientId.isEmpty || _busy) return;
    _busy = true;

    setState(() {
      _answered.add(q.key);
      _thanks = true;
    });

    try {
      await ref.read(microFeedbackApiProvider).submit(
            clientId: clientId,
            questionKey: q.key,
            page: q.pages.isNotEmpty ? q.pages.first : (_pageForPath(_location) ?? ''),
            answer: value,
            question: q.text,
          );
    } catch (_) {
      // Non-blocking: the widget is best-effort.
    }

    if (q.reward && value == 'yes' && mounted) {
      context.push('/rewards');
    }
    if (q.href != null && value == 'yes') {
      final href = q.href!;
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) context.push(href);
      });
    }

    Future.delayed(const Duration(milliseconds: 900), () {
      _busy = false;
      if (mounted) _collapse();
    });
  }

  Widget _buildCollapsedPill(BuildContext context, List<_MicroQuestion> pool) {
    final top = MediaQuery.of(context).size.height * 0.32;
    return Positioned(
      right: 6,
      top: top,
      child: GestureDetector(
        onTap: () => _expand(pool),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9747FF), Color(0xFF7C3AED)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9747FF).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.forum_outlined, size: 15, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildExpandedCard(BuildContext context, List<_MicroQuestion> pool) {
    final q = _question!;
    return Positioned(
      right: 16,
      bottom: 132,
      child: Container(
        width: 172,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3E8FF)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF170F3C).withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _thanks ? 'Thanks!' : q.text,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  if (!_thanks)
                    GestureDetector(
                      onTap: _collapse,
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 13, color: Color(0xFFD1D5DB)),
                      ),
                    ),
                ],
              ),
            ),
            if (!_thanks)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _answer('yes'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9747FF), Color(0xFF7C3AED)],
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Yes',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _answer('no'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Center(
                            child: Text(
                              'No',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

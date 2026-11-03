import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/features/rewards/presentation/providers/rewards_provider.dart';

/// Compact SuperCoin quiz: start the session, answer each question
/// (server-graded), complete, then show win/lose. Ported from React's
/// `JanmashtamiQuizModal` flow.
class QuizModal extends ConsumerStatefulWidget {
  final String clientId;
  final String publicId;
  final VoidCallback onClose;

  /// Fired with the final reward status (PENDING = won).
  final void Function(Map<String, dynamic> reward)? onFinished;

  const QuizModal({
    super.key,
    required this.clientId,
    required this.publicId,
    required this.onClose,
    this.onFinished,
  });

  @override
  ConsumerState<QuizModal> createState() => _QuizModalState();
}

class _QuizModalState extends ConsumerState<QuizModal> {
  bool _loading = true;
  String? _error;
  List<QuizQuestion> _questions = const [];
  int _index = 0;
  int? _selectedIndex;
  int? _correctIndex;
  int _correctCount = 0;
  bool _busy = false;
  Map<String, dynamic>? _result;
  Timer? _timer;
  int _secondsLeft = 120;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown(String? expiresAt) {
    _timer?.cancel();
    DateTime? deadline;
    if (expiresAt != null) deadline = DateTime.tryParse(expiresAt);
    deadline ??= DateTime.now().add(const Duration(minutes: 2));
    void tick() {
      final left = deadline!.difference(DateTime.now()).inSeconds;
      if (!mounted) return;
      setState(() => _secondsLeft = left < 0 ? 0 : left);
      if (left <= 0) {
        _timer?.cancel();
        _finish();
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _load() async {
    try {
      final api = ref.read(rewardsApiProvider);
      final session = await api.startSession(widget.clientId, widget.publicId);
      final reward = (session['reward'] as Map?)?.cast<String, dynamic>() ?? const {};
      final questions = ((session['questions'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => QuizQuestion.fromJson(e.cast<String, dynamic>()))
          .toList();
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
        if (questions.isEmpty) _error = 'The quiz is not available right now.';
      });
      _startCountdown(reward['quizStartExpiresAt']?.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The quiz could not be started. Please try again.';
      });
    }
  }

  Future<void> _answer(int optionIndex) async {
    if (_busy || _selectedIndex != null || _index >= _questions.length) return;
    final q = _questions[_index];
    setState(() {
      _busy = true;
      _selectedIndex = optionIndex;
    });
    try {
      final res = await ref
          .read(rewardsApiProvider)
          .answer(widget.clientId, widget.publicId, q.id, optionIndex);
      if (!mounted) return;
      setState(() {
        _correctIndex = (res['correctIndex'] as num?)?.toInt();
        if (res['correct'] == true) _correctCount += 1;
        _busy = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      if (_index + 1 >= _questions.length) {
        await _finish();
      } else {
        setState(() {
          _index += 1;
          _selectedIndex = null;
          _correctIndex = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _selectedIndex = null;
        _correctIndex = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit that answer. Please try again.')),
      );
    }
  }

  Future<void> _finish() async {
    if (_result != null) return;
    _timer?.cancel();
    try {
      final reward = await ref.read(rewardsApiProvider).complete(widget.clientId, widget.publicId);
      if (!mounted) return;
      setState(() => _result = reward);
      widget.onFinished?.call(reward);
    } catch (_) {
      if (!mounted) return;
      setState(() => _result = const {'status': 'LOST'});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF9747FF))),
      );
    }
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Color(0xFFEF4444)),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: widget.onClose, child: const Text('Close')),
        ],
      );
    }
    if (_result != null) return _buildResult();

    final q = _questions[_index];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Question ${_index + 1}/${_questions.length}',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF7C3AED))),
            const Spacer(),
            const Icon(Icons.schedule, size: 14, color: Color(0xFF7C3AED)),
            const SizedBox(width: 4),
            Text(
              '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF7C3AED)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(q.question, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        for (var i = 0; i < q.options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _optionButton(i, q.options[i]),
        ],
        const SizedBox(height: 12),
        TextButton(onPressed: widget.onClose, child: const Text('Exit quiz')),
      ],
    );
  }

  Widget _optionButton(int index, String label) {
    Color border = const Color(0xFFE5E7EB);
    Color background = Colors.white;
    Color text = const Color(0xFF101010);
    if (_selectedIndex != null) {
      if (index == _correctIndex) {
        border = const Color(0xFF10B981);
        background = const Color(0xFFECFDF5);
        text = const Color(0xFF059669);
      } else if (index == _selectedIndex) {
        border = const Color(0xFFEF4444);
        background = const Color(0xFFFEF2F2);
        text = const Color(0xFFDC2626);
      }
    }
    return GestureDetector(
      onTap: _selectedIndex != null ? null : () => _answer(index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontSize: 13, color: text)),
      ),
    );
  }

  Widget _buildResult() {
    final won = (_result?['status'] ?? '').toString().toUpperCase() == 'PENDING';
    final coins = (_result?['coinReward'] as num?)?.toDouble() ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: won ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
            shape: BoxShape.circle,
          ),
          child: Icon(won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              size: 34, color: won ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
        ),
        const SizedBox(height: 12),
        Text(won ? 'You won ${coins.toStringAsFixed(0)} SuperCoins!' : 'Better luck next time',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          won
              ? 'Your bonus is reserved for 24 hours. Use it on your next voucher purchase.'
              : 'You got $_correctCount of ${_questions.length} correct. All answers must be correct to win.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: widget.onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9747FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Done', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

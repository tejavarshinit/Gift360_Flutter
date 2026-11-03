import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gift360/core/utils/analytics.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/rewards/presentation/providers/rewards_provider.dart';
import 'package:gift360/features/rewards/presentation/widgets/quiz_modal.dart';

/// `/rewards` is the destination of the home Rewards tile. Mirrors React
/// `RewardsPage` + `RewardsModal`: quiz banner, Instagram story/reel reward,
/// and the full backend-backed quiz/story journeys.
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  static const int _defaultQuizReward = 5;
  static const int _storyReward = 100;
  static const String _referencePostUrl =
      'https://www.instagram.com/p/De8rW3yTd6-/?cplk=MWg2OHh3OHlwendnZQ%3D%3D';
  static final RegExp _instagramUrl = RegExp(
    r'^https?://([\w-]+\.)*instagram\.com/.+',
    caseSensitive: false,
  );

  final TextEditingController _storyController = TextEditingController();
  bool _storySending = false;
  bool _storyDone = false;
  String? _storyError;
  bool _copiedReference = false;
  bool _quizBusy = false;
  String? _quizNote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(rewardStatusProvider);
    });
  }

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
  }

  bool get _storyUrlValid =>
      _instagramUrl.hasMatch(_storyController.text.trim());

  String _string(Map<String, dynamic>? data, String key) =>
      (data?[key] ?? '').toString();

  bool _quizWon(Map<String, dynamic>? reward) {
    if (_string(reward, 'status').toUpperCase() != 'PENDING') return false;
    final expiresAt = DateTime.tryParse(_string(reward, 'expiresAt'));
    return expiresAt != null && expiresAt.isAfter(DateTime.now());
  }

  bool _quizEarned(Map<String, dynamic>? reward) {
    final status = _string(reward, 'status').toUpperCase();
    return status == 'REDEEMED' || status == 'CLAIMED';
  }

  int _quizReward(Map<String, dynamic>? reward) =>
      (reward?['coinReward'] as num?)?.toInt() ?? _defaultQuizReward;

  Future<void> _playQuiz(Map<String, dynamic>? reward) async {
    final user = ref.read(authProvider);
    if (user == null) {
      context.go('/login');
      return;
    }
    setState(() => _quizNote = null);
    if (_quizWon(reward)) {
      context.push('/supercoin-voucher');
      return;
    }

    setState(() => _quizBusy = true);
    try {
      final result = await ref
          .read(rewardsApiProvider)
          .startFromBanner(user.clientId);
      final status = _string(result, 'status').toUpperCase();
      final publicId = _string(result, 'publicId');
      final startExpiresAt = _string(result, 'quizStartExpiresAt');
      if (!mounted) return;

      if ((status == 'AVAILABLE' || status == 'IN_PROGRESS') &&
          publicId.isNotEmpty &&
          startExpiresAt.isNotEmpty) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.transparent,
          builder: (_) => QuizModal(
            clientId: user.clientId,
            publicId: publicId,
            onClose: () => Navigator.of(context, rootNavigator: true).pop(),
            onFinished: (_) => ref.invalidate(rewardStatusProvider),
          ),
        );
        if (!mounted) return;
        final refreshed = await ref
            .read(rewardsApiProvider)
            .getStatus(user.clientId, publicId: publicId);
        ref.invalidate(rewardStatusProvider);
        if (!mounted) return;
        if (_string(refreshed, 'status').toUpperCase() == 'PENDING') {
          context.push('/supercoin-voucher');
        }
      } else if (status == 'PENDING') {
        context.push('/supercoin-voucher');
      } else {
        setState(
          () => _quizNote =
              'You have used your quiz attempts for today. Try again tomorrow.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _quizNote =
              'The quiz is not available right now. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _quizBusy = false);
    }
  }

  Future<void> _copyReference() async {
    try {
      await Clipboard.setData(const ClipboardData(text: _referencePostUrl));
      if (!mounted) return;
      setState(() => _copiedReference = true);
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _copiedReference = false);
      });
    } catch (_) {
      // Clipboard sharing is optional; opening the link still works.
    }
  }

  Future<void> _openReferencePost() async {
    final uri = Uri.tryParse(_referencePostUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submitStory() async {
    final user = ref.read(authProvider);
    if (user == null) {
      context.go('/login');
      return;
    }
    if (!_storyUrlValid || _storySending) return;

    setState(() {
      _storySending = true;
      _storyError = null;
    });
    try {
      final result = await ref
          .read(rewardsApiProvider)
          .submitInstagramStory(user.clientId, _storyController.text.trim());
      if (!mounted) return;
      if (result['success'] == true) {
        AnalyticsService.trackEvent('instagram_story_submitted');
        setState(() => _storyDone = true);
      } else {
        setState(
          () => _storyError =
              (result['message'] ??
                      'Could not submit your story link. Please try again.')
                  .toString(),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _storyError =
              'Could not submit your story link. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _storySending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reward = ref.watch(rewardStatusProvider).valueOrNull;
    final quizEarned = _quizEarned(reward);
    final quizWon = _quizWon(reward);
    final quizReward = _quizReward(reward);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => context.go('/'),
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Material(
                      color: Colors.white,
                      child: Column(
                        children: [
                          _buildHeader(context),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _buildQuizCard(
                                    reward: reward,
                                    earned: quizEarned,
                                    won: quizWon,
                                    coinReward: quizReward,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildStoryCard(),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0xFFF3F4F6)),
                              ),
                            ),
                            child: Text(
                              'SuperCoins are credited after we verify your reel or story is live.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9333EA), Color(0xFF4338CA)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, size: 21, color: Color(0xFFFCD34D)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rewards',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Play the quiz and share your story to win SuperCoins',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFE9D5FF),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.go('/'),
            tooltip: 'Close rewards',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 20, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCard({
    required Map<String, dynamic>? reward,
    required bool earned,
    required bool won,
    required int coinReward,
  }) {
    final title = earned
        ? 'Quiz reward earned'
        : won
        ? 'You won! Buy now to get $coinReward SuperCoins'
        : 'Answer 5 questions, win $coinReward SuperCoins';
    final description = earned
        ? 'Your $coinReward bonus SuperCoins have been credited. Thanks for playing.'
        : won
        ? 'Complete a purchase before the timer runs out and $coinReward bonus SuperCoins are credited after your voucher is issued.'
        : _quizNote ??
              'Get all 5 right, then buy before the timer runs out and we credit $coinReward bonus SuperCoins.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C3AED), Color(0xFF5B2B99)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7D46B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'QUIZ',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: const Color(0xFF5B2B99),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                if (!earned) ...[
                  const SizedBox(height: 9),
                  TextButton.icon(
                    onPressed: _quizBusy ? null : () => _playQuiz(reward),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF5B2B99),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: _quizBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF5B2B99),
                            ),
                          )
                        : const Icon(Icons.arrow_forward, size: 14),
                    label: Text(
                      _quizBusy ? 'Opening...' : (won ? 'Buy now' : 'Play now'),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monetization_on_outlined,
              size: 32,
              color: Color(0xFFF7D46B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4C1D95), Color(0xFF6D28D9), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -25,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF7D46B).withValues(alpha: 0.14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _goldPill('STORY & REEL'),
                          const SizedBox(height: 7),
                          Text(
                            'Share your Gift360 story, win $_storyReward SuperCoins',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                height: 1.4,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              children: const [
                                TextSpan(
                                  text:
                                      'Bought a voucher? Post your experience as an Instagram reel or story, tag ',
                                ),
                                TextSpan(
                                  text: '@gift360.io',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF7D46B),
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' in the post, then paste your link below - earn ',
                                ),
                                TextSpan(
                                  text: '100 SuperCoins',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF7D46B),
                                  ),
                                ),
                                TextSpan(text: ' once we verify it.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x66F7D46B),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 29,
                        color: Color(0xFFF7D46B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'HOW IT WORKS',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: const Color(0xFFF7D46B),
                  ),
                ),
                const SizedBox(height: 6),
                _storyStep(
                  '1',
                  'Buy any Gift360 voucher',
                  'Complete your purchase before you post.',
                ),
                _storyStep(
                  '2',
                  'Post a reel or story on Instagram',
                  'Share your genuine experience with the voucher.',
                ),
                _storyStep(
                  '3',
                  'Tag @gift360.io in the post',
                  'Mention us in the caption - this is how we find your entry.',
                  highlighted: true,
                ),
                _storyStep(
                  '4',
                  'Paste your link here and submit',
                  "We'll check it's live, then credit your SuperCoins.",
                ),
                const SizedBox(height: 8),
                _buildReferenceLink(),
                const SizedBox(height: 12),
                Text(
                  'YOUR INSTAGRAM LINK',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: const Color(0xFFF7D46B),
                  ),
                ),
                const SizedBox(height: 7),
                if (_storyDone)
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 17,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Thanks! Your story link is submitted. Your $_storyReward SuperCoins will be credited after verification.',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _storyController,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.url,
                          readOnly: _storyDone,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF111827),
                          ),
                          decoration: InputDecoration(
                            hintText: 'https://instagram.com/reel/...',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF9CA3AF),
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.96),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: (!_storyUrlValid || _storySending)
                              ? null
                              : _submitStory,
                          icon: _storySending
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF5B2B99),
                                  ),
                                )
                              : const Icon(Icons.card_giftcard, size: 14),
                          label: Text(
                            _storySending ? 'Submitting...' : 'Submit',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF7D46B),
                            foregroundColor: const Color(0xFF5B2B99),
                            disabledBackgroundColor: const Color(
                              0xFFF7D46B,
                            ).withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_storyError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _storyError!,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFFFECACA),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _goldPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF7D46B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: const Color(0xFF4C1D95),
        ),
      ),
    );
  }

  Widget _storyStep(
    String number,
    String title,
    String description, {
    bool highlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0x33F7D46B)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: highlighted ? Border.all(color: const Color(0x99F7D46B)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 17,
            height: 17,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF7D46B),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4C1D95),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceLink() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x99F7D46B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _openReferencePost,
            child: Row(
              children: [
                const Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: Color(0xFFF7D46B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Reference post - copy-paste this link and use it as your reference',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: _openReferencePost,
                  child: Text(
                    _referencePostUrl,
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      height: 1.3,
                      color: const Color(0xFFF7D46B),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: _copyReference,
                icon: Icon(
                  _copiedReference ? Icons.check : Icons.copy,
                  size: 12,
                ),
                label: Text(_copiedReference ? 'Copied' : 'Copy'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4C1D95),
                  backgroundColor: const Color(0xFFF7D46B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  visualDensity: VisualDensity.compact,
                  textStyle: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Match the same look and style when you post your own reel or story.',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

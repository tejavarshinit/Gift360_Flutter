import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/feedback/presentation/providers/feedback_provider.dart';

class FeedbackForm extends ConsumerStatefulWidget {
  const FeedbackForm({super.key});

  @override
  ConsumerState<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends ConsumerState<FeedbackForm> {
  String? _locationShare;
  String? _gender;
  String? _appSpeed;
  String? _findBuy;
  String? _paymentExp;
  int? _overall;
  final _suggestionController = TextEditingController();

  @override
  void dispose() {
    _suggestionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedbackState = ref.watch(feedbackProvider);

    if (feedbackState.isSuccess) {
      return Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8F5E9)),
              child: const Icon(Icons.check, size: 36, color: Color(0xFF4CAF50)),
            ),
            const SizedBox(height: 16),
            Text('Thank you!', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Your feedback has been submitted.',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Done', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 420,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Purple header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('We value your feedback',
                          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 3),
                      Text('Help us improve your Gift360 experience',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),

          // Scrollable questions
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Q1: Location share
                  _buildQuestion(
                    icon: Icons.location_on_outlined,
                    question: 'Would you like to share your location so we can recommend offers available near you?',
                  ),
                  const SizedBox(height: 8),
                  _buildButtonRow(['Yes', 'No'], _locationShare, (v) => setState(() => _locationShare = v)),
                  const SizedBox(height: 18),

                  // Q2: Gender
                  _buildQuestion(icon: Icons.person_outline, question: 'You are'),
                  const SizedBox(height: 8),
                  _buildButtonRow(['Male', 'Female', 'Other'], _gender, (v) => setState(() => _gender = v)),
                  const SizedBox(height: 18),

                  // Q3: App speed
                  _buildQuestion(icon: Icons.speed, question: 'How fast does the app feel?'),
                  const SizedBox(height: 8),
                  _buildButtonRow(['Slow', 'Okay', 'Good', 'Fast'], _appSpeed, (v) => setState(() => _appSpeed = v)),
                  const SizedBox(height: 18),

                  // Q4: Find & buy ease
                  _buildQuestion(icon: Icons.shopping_bag_outlined, question: 'How easy is it to find and buy a voucher?'),
                  const SizedBox(height: 8),
                  _buildButtonRow(['Hard', 'Neutral', 'Easy'], _findBuy, (v) => setState(() => _findBuy = v)),
                  const SizedBox(height: 18),

                  // Q5: Payment experience
                  _buildQuestion(icon: Icons.payment_outlined, question: 'How was the payment experience?'),
                  const SizedBox(height: 8),
                  _buildButtonRow(['Had issues', 'Okay', 'Smooth'], _paymentExp, (v) => setState(() => _paymentExp = v)),
                  const SizedBox(height: 18),

                  // Q6: Overall rating
                  _buildQuestion(icon: Icons.star_outline, question: 'Overall, how would you rate your experience?'),
                  const SizedBox(height: 8),
                  _buildStarRating(),
                  const SizedBox(height: 18),

                  // Suggestion
                  _buildQuestion(icon: Icons.chat_bubble_outline, question: 'Any suggestions for us? (optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _suggestionController,
                    maxLines: 3,
                    style: GoogleFonts.poppins(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Tell us what you think...',
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Submit button (fixed at bottom)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: feedbackState.isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: feedbackState.isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Submit', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion({required IconData icon, required String question}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(color: Color(0xFFEDE9FE), shape: BoxShape.circle),
          child: Icon(icon, size: 13, color: const Color(0xFF7C3AED)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(question, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1F2937))),
        ),
      ],
    );
  }

  Widget _buildButtonRow(List<String> options, String? selected, ValueChanged<String> onChanged) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected == opt;
        return GestureDetector(
          onTap: () => onChanged(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF7C3AED) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB)),
            ),
            child: Text(opt, style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF374151),
            )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStarRating() {
    return Row(
      children: List.generate(5, (i) {
        final index = i + 1;
        final isSelected = _overall != null && _overall! >= index;
        return GestureDetector(
          onTap: () => setState(() => _overall = index),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              isSelected ? Icons.star : Icons.star_border,
              size: 32,
              color: isSelected ? const Color(0xFF7C3AED) : Colors.grey.shade300,
            ),
          ),
        );
      }),
    );
  }

  Future<void> _handleSubmit() async {
    final user = ref.read(authProvider);
    final speedMap = {'Slow': 1, 'Okay': 3, 'Good': 4, 'Fast': 5};

    await ref.read(feedbackProvider.notifier).submitFeedback(
      speed: _appSpeed != null ? speedMap[_appSpeed] : null,
      usability: _findBuy,
      payment: _paymentExp,
      overall: _overall,
      locationShare: _locationShare,
      gender: _gender,
      suggestion: _suggestionController.text.isNotEmpty ? _suggestionController.text : null,
      clientId: user?.clientId,
    );
  }
}

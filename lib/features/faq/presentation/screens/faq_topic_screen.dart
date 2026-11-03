import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/features/faq/data/faq_topics.dart';
import 'package:gift360/features/rewards/presentation/providers/rewards_provider.dart';

/// `/faq/<id>` — linkable single-answer FAQ page used by the support chatbot
/// (matches React `FAQTopicPage.tsx`). SuperCoin numbers come from the live
/// /v1/support/facts/supercoin endpoint.
class FaqTopicScreen extends ConsumerWidget {
  final String topicId;

  const FaqTopicScreen({super.key, required this.topicId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topic = faqTopicById(topicId);
    final facts = ref.watch(scFactsProvider).valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/faq');
                      }
                    },
                    icon: const Icon(Icons.chevron_left, size: 26),
                  ),
                  Text('Help Center',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: topic == null
                    ? Text('This answer could not be found.',
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF6B7280)))
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(topic.title,
                                style: GoogleFonts.poppins(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            SelectableText(
                              fillFaqFacts(topic.answer, facts),
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  height: 1.55,
                                  color: const Color(0xFF374151)),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: OutlinedButton(
                                onPressed: () => context.push('/faq'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF7C3AED),
                                  side: const BorderSide(color: Color(0xFF7C3AED)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text('See all FAQs',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

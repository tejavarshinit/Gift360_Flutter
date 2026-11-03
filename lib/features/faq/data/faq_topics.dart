/// FAQ answers shared with the support chatbot; each has a stable id so the
/// chatbot can deep-link to `/faq/<id>` (ported from React `data/faqTopics.ts`).
class FaqTopic {
  final String id;
  final String title;
  final String answer;
  final String category;

  const FaqTopic({
    required this.id,
    required this.title,
    required this.answer,
    required this.category,
  });
}

const List<FaqTopic> faqTopics = [
  FaqTopic(
    id: 'supercoin-how-to-use',
    title: 'How do I use my Flipkart SuperCoins on Gift360?',
    answer:
        'You can use your Flipkart SuperCoins on Gift360 in two ways:\n1) Pick any voucher, add it to your cart and choose the SuperCoins option. It shows how many coins will be used.\n2) To turn SuperCoins into a SuperCoin E-Gift Voucher, use the \'Try Now\' section at the top of the home page.\nThe app will show you the exact coins needed before you pay.',
    category: 'supercoins',
  ),
  FaqTopic(
    id: 'supercoin-rate',
    title: 'How many SuperCoins does a voucher cost?',
    answer:
        'Every \u20b91 of a SuperCoin voucher costs {{coinsPerRupee}} SuperCoins.\nSo a \u20b9100 voucher uses {{coins100}} SuperCoins and a \u20b9500 voucher uses {{coins500}}.\nYou\'ll see the exact number at checkout before you confirm.',
    category: 'supercoins',
  ),
  FaqTopic(
    id: 'supercoin-voucher-range',
    title: 'Which SuperCoin voucher amounts are available?',
    answer:
        'The SuperCoin E-Gift Voucher is available from \u20b9{{minAmount}} up to \u20b9{{maxAmount}}.\nFind it under \'Try Now\' on the home page.',
    category: 'supercoins',
  ),
  FaqTopic(
    id: 'supercoin-voucher-redeem',
    title: 'How do I redeem my SuperCoin voucher?',
    answer:
        'Once your SuperCoin voucher is issued, open it from My Orders and tap \'Use Myself\' to see the code. Then redeem it on the Flipkart SuperCoin claim page: https://flipkartsupercoin.woohoo.in/claimReward and follow the steps there.',
    category: 'supercoins',
  ),
  FaqTopic(
    id: 'voucher-code-location',
    title: 'Where do I find my voucher code?',
    answer:
        'Open My Orders in your Gift360 account, choose the order and tap \'Use Myself\'. Your voucher code and PIN are shown there.',
    category: 'orders',
  ),
  FaqTopic(
    id: 'what-is-gift360',
    title: 'What is Gift360?',
    answer:
        'Gift360 is a digital gift voucher marketplace. Choose a brand and amount, pay, and your voucher is delivered instantly in My Orders. You can pay with SuperCoins at the cart, and earn SuperCoins on purchases. Use it at gift360.io or from the SuperCoin Partners page inside the Flipkart app.',
    category: 'general',
  ),
  FaqTopic(
    id: 'supercoin-how-many',
    title: 'How many SuperCoins do I need for a \u20b9500 voucher?',
    answer:
        'At the current rate of {{coinsPerRupee}} SuperCoins per \u20b91, a \u20b9500 voucher uses {{coins500}} SuperCoins and a \u20b9100 voucher uses {{coins100}}.\nThe exact number is always shown in your cart before you pay.',
    category: 'supercoins',
  ),
  FaqTopic(
    id: 'supercoin-see-before-pay',
    title: 'Will I see the SuperCoins needed before I pay?',
    answer:
        'Yes. Add the voucher to your cart and choose the SuperCoins option. The app shows exactly how many coins will be used before you confirm.',
    category: 'supercoins',
  ),
  FaqTopic(
    id: 'gift-a-voucher',
    title: 'Can I gift a voucher to someone?',
    answer:
        'Yes. Once your voucher is issued, open it in My Orders and choose Gift to send it to someone by WhatsApp or email. If the person hasn\'t received it, share the order number and we\'ll check.',
    category: 'vouchers',
  ),
  FaqTopic(
    id: 'supercoin-flipkart-app',
    title: 'How do I open Gift360 from the Flipkart app?',
    answer:
        'In the Flipkart app, open the SuperCoin Partners page and choose Gift360. You can also go straight to gift360.io.',
    category: 'supercoins',
  ),
];

FaqTopic? faqTopicById(String id) {
  for (final topic in faqTopics) {
    if (topic.id == id) return topic;
  }
  return null;
}

/// Replaces {{tokens}} with live values. Any line that still needs a missing
/// value is dropped, so a stale number is never shown (matches React
/// `fillFacts`).
String fillFaqFacts(String text, Map<String, dynamic>? facts) {
  final vals = <String, String>{};
  if (facts != null) {
    final perRupee = facts['coinsPerRupee']?.toString();
    if (perRupee != null && perRupee.isNotEmpty) {
      vals['coinsPerRupee'] = perRupee;
      final rate = double.tryParse(perRupee) ?? 0;
      vals['coins100'] = (100 * rate).ceil().toString();
      vals['coins500'] = (500 * rate).ceil().toString();
    }
    final minAmount = facts['minAmount'];
    if (minAmount != null) vals['minAmount'] = minAmount.toString();
    final maxAmount = facts['maxAmount'];
    if (maxAmount != null) vals['maxAmount'] = maxAmount.toString();
  }
  final kept = <String>[];
  for (final line in text.split('\n')) {
    var missing = false;
    final out = line.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (m) {
      final value = vals[m.group(1)];
      if (value == null) missing = true;
      return value ?? '';
    });
    if (!missing) kept.add(out);
  }
  return kept.join('\n').replaceAll(RegExp(r'\s+(?=\.)'), '');
}
